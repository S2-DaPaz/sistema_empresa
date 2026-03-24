const now = () => new Date().toISOString();

async function createBackupRun(db, data) {
  const ts = now();
  const result = await db.run(
    `INSERT INTO backup_runs
      (status, trigger_source, storage_provider, started_at, created_at, updated_at, triggered_by_user_id, metadata_json)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      data.status || "running",
      data.trigger_source,
      data.storage_provider || null,
      data.started_at || ts,
      ts,
      ts,
      data.triggered_by_user_id || null,
      data.metadata_json || null
    ]
  );
  return result.lastID;
}

async function updateBackupRun(db, id, data) {
  const fields = [];
  const values = [];

  for (const key of [
    "status",
    "storage_provider",
    "file_name",
    "encrypted_file_name",
    "sha256",
    "file_size_bytes",
    "finished_at",
    "error_message",
    "metadata_json"
  ]) {
    if (data[key] !== undefined) {
      fields.push(`${key} = ?`);
      values.push(data[key]);
    }
  }

  if (fields.length === 0) return;

  fields.push("updated_at = ?");
  values.push(now());
  values.push(id);

  await db.run(`UPDATE backup_runs SET ${fields.join(", ")} WHERE id = ?`, values);
}

async function getBackupRun(db, id) {
  return db.get("SELECT * FROM backup_runs WHERE id = ?", [id]);
}

async function listBackupRuns(db, { page = 1, pageSize = 20 } = {}) {
  const offset = (page - 1) * pageSize;
  const countRow = await db.get("SELECT COUNT(*) AS total FROM backup_runs");
  const total = Number(countRow?.total || 0);
  const items = await db.all(
    "SELECT * FROM backup_runs ORDER BY created_at DESC LIMIT ? OFFSET ?",
    [pageSize, offset]
  );
  return { items, total, page, pageSize };
}

module.exports = {
  createBackupRun,
  updateBackupRun,
  getBackupRun,
  listBackupRuns
};
