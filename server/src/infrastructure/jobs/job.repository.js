const { decryptPayload, encryptPayload } = require("./payload-crypto");

function createJobRepository({ secret }) {
  function mapJob(row) {
    if (!row) return null;
    return {
      ...row,
      payload: decryptPayload(secret, row.payload_json)
    };
  }

  async function findPendingByDedupeKey(db, dedupeKey) {
    if (!dedupeKey) return null;
    const row = await db.get(
      `SELECT *
       FROM background_jobs
       WHERE dedupe_key = ?
         AND status IN ('queued', 'processing')
       ORDER BY id DESC
       LIMIT 1`,
      [dedupeKey]
    );
    return mapJob(row);
  }

  async function createJob(db, payload) {
    const result = await db.run(
      `INSERT INTO background_jobs (
        type,
        status,
        payload_json,
        dedupe_key,
        attempts,
        max_attempts,
        created_at,
        available_at,
        request_id,
        created_by_user_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        payload.type,
        payload.status || "queued",
        encryptPayload(secret, payload.payload),
        payload.dedupe_key || null,
        Number(payload.attempts || 0),
        Number(payload.max_attempts || 5),
        payload.created_at,
        payload.available_at,
        payload.request_id || null,
        payload.created_by_user_id || null
      ]
    );

    return db.get("SELECT * FROM background_jobs WHERE id = ?", [result.lastID]);
  }

  async function listDueJobs(db, nowIso, limit) {
    const rows = await db.all(
      `SELECT *
       FROM background_jobs
       WHERE status = ?
         AND available_at <= ?
       ORDER BY available_at ASC, id ASC
       LIMIT ${Number(limit) || 10}`,
      ["queued", nowIso]
    );
    return rows.map(mapJob).filter(Boolean);
  }

  async function claimJob(db, jobId, startedAt) {
    const result = await db.run(
      `UPDATE background_jobs
       SET status = ?, started_at = ?
       WHERE id = ? AND status = ?`,
      ["processing", startedAt, jobId, "queued"]
    );
    if (!result.changes) return null;
    const row = await db.get("SELECT * FROM background_jobs WHERE id = ?", [jobId]);
    return mapJob(row);
  }

  async function markCompleted(db, jobId, completedAt) {
    await db.run(
      `UPDATE background_jobs
       SET status = ?, completed_at = ?, started_at = COALESCE(started_at, ?), last_error = NULL
       WHERE id = ?`,
      ["completed", completedAt, completedAt, jobId]
    );
  }

  async function markFailed(db, job, payload) {
    await db.run(
      `UPDATE background_jobs
       SET status = ?,
           attempts = ?,
           available_at = ?,
           last_error = ?,
           started_at = COALESCE(started_at, ?),
           completed_at = ?
       WHERE id = ?`,
      [
        payload.status,
        payload.attempts,
        payload.available_at,
        payload.last_error || null,
        payload.started_at || null,
        payload.completed_at || null,
        job.id
      ]
    );
  }

  return {
    findPendingByDedupeKey,
    createJob,
    listDueJobs,
    claimJob,
    markCompleted,
    markFailed
  };
}

module.exports = { createJobRepository };
