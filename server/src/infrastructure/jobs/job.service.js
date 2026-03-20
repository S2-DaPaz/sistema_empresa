const { createJobRepository } = require("./job.repository");

function createJobService({ db, env, logger, monitoringService, handlers = {} }) {
  const repository = createJobRepository({ secret: env.jobs.encryptionSecret });
  let timer = null;
  let processing = false;

  function buildRetryDate(attempts) {
    const baseDelay = Math.max(1, env.jobs.retryDelaySeconds);
    const delaySeconds = baseDelay * Math.max(1, attempts);
    return new Date(Date.now() + delaySeconds * 1000).toISOString();
  }

  async function enqueue({
    type,
    payload,
    dedupeKey = null,
    maxAttempts = env.jobs.maxAttempts,
    requestId = null,
    createdByUserId = null
  }) {
    if (dedupeKey) {
      const existing = await repository.findPendingByDedupeKey(db, dedupeKey);
      if (existing) {
        return existing;
      }
    }

    return repository.createJob(db, {
      type,
      payload,
      dedupe_key: dedupeKey,
      max_attempts: maxAttempts,
      created_at: new Date().toISOString(),
      available_at: new Date().toISOString(),
      request_id: requestId,
      created_by_user_id: createdByUserId
    });
  }

  async function handleFailure(job, error) {
    const attempts = Number(job.attempts || 0) + 1;
    const shouldRetry = attempts < Number(job.max_attempts || env.jobs.maxAttempts);
    await repository.markFailed(db, job, {
      status: shouldRetry ? "queued" : "failed",
      attempts,
      available_at: shouldRetry ? buildRetryDate(attempts) : new Date().toISOString(),
      last_error: error.message,
      started_at: job.started_at || new Date().toISOString(),
      completed_at: shouldRetry ? null : new Date().toISOString()
    });

    logger.error("background_job_failed", {
      jobId: job.id,
      type: job.type,
      attempts,
      retrying: shouldRetry,
      message: error.message
    });

    if (monitoringService) {
      await monitoringService.recordEvent(db, {
        action: "JOB_FAILED",
        description: `Falha ao processar job ${job.type}.`,
        module: "jobs",
        outcome: shouldRetry ? "retrying" : "failure",
        requestId: job.request_id || null,
        metadata: {
          jobId: job.id,
          type: job.type,
          attempts,
          maxAttempts: job.max_attempts,
          retrying: shouldRetry,
          error: error.message
        }
      });
    }
  }

  async function processJob(job) {
    const handler = handlers[job.type];
    if (typeof handler !== "function") {
      await handleFailure(job, new Error(`No handler registered for ${job.type}.`));
      return;
    }

    try {
      await handler({ job, payload: job.payload });
      await repository.markCompleted(db, job.id, new Date().toISOString());

      if (monitoringService) {
        await monitoringService.recordEvent(db, {
          action: "JOB_COMPLETED",
          description: `Job ${job.type} concluído.`,
          module: "jobs",
          outcome: "success",
          requestId: job.request_id || null,
          metadata: {
            jobId: job.id,
            type: job.type
          }
        });
      }
    } catch (error) {
      await handleFailure(job, error);
    }
  }

  async function processDueJobs() {
    if (processing) return;
    processing = true;
    try {
      const dueJobs = await repository.listDueJobs(
        db,
        new Date().toISOString(),
        env.jobs.batchSize
      );

      for (const queuedJob of dueJobs) {
        const claimed = await repository.claimJob(db, queuedJob.id, new Date().toISOString());
        if (!claimed) continue;
        await processJob(claimed);
      }
    } finally {
      processing = false;
    }
  }

  function start() {
    if (!env.jobs.enabled || timer) return;
    timer = setInterval(() => {
      processDueJobs().catch((error) => {
        logger.error("background_job_tick_failed", { message: error.message });
      });
    }, env.jobs.pollMs);

    processDueJobs().catch((error) => {
      logger.error("background_job_bootstrap_failed", { message: error.message });
    });
  }

  function stop() {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
  }

  return {
    enqueue,
    processDueJobs,
    start,
    stop
  };
}

module.exports = { createJobService };
