const { createApp } = require("./app/create-app");
const { ensureAdminUser, ensureDefaultRoles } = require("./app/bootstrap-data");
const { getEnv } = require("./config/env");
const { initDb } = require("./infrastructure/database");
const { createEmailService } = require("./infrastructure/email/email.service");
const { createJobService } = require("./infrastructure/jobs/job.service");
const { createQueuedEmailService } = require("./infrastructure/jobs/queued-email.service");
const { createMonitoringService } = require("./modules/monitoring/monitoring.service");
const { createPublicService } = require("./modules/public/public.service");
const { logger } = require("./core/utils/logger");

async function main() {
  const env = getEnv();
  const db = await initDb();
  await ensureDefaultRoles(db);
  await ensureAdminUser(db, env);

  const monitoringService = createMonitoringService({ env, logger });
  const directEmailService = createEmailService({ env, logger });
  const publicService = createPublicService({ env, logger });
  const jobService = createJobService({
    db,
    env,
    logger,
    monitoringService,
    handlers: {
      "email.sendVerificationCode": async ({ payload }) => {
        await directEmailService.sendVerificationCode(payload);
      },
      "email.sendPasswordResetCode": async ({ payload }) => {
        await directEmailService.sendPasswordResetCode(payload);
      },
      "pdf.warmTask": async ({ payload }) => {
        await publicService.warmTaskPdf(db, Number(payload.id), Boolean(payload.forceRefresh));
      },
      "pdf.warmBudget": async ({ payload }) => {
        await publicService.warmBudgetPdf(db, Number(payload.id), Boolean(payload.forceRefresh));
      }
    }
  });
  publicService.setJobService(jobService);
  const emailService = createQueuedEmailService({
    env,
    jobService,
    directEmailService
  });
  const app = createApp({
    db,
    env,
    logger,
    publicService,
    monitoringService,
    emailService
  });

  return new Promise((resolve, reject) => {
    const server = app.listen(env.port, () => {
      jobService.start();
      logger.info("server_started", { port: env.port });
      resolve(server);
    });
    server.on("close", () => jobService.stop());
    server.on("error", reject);
  });
}

module.exports = { main };
