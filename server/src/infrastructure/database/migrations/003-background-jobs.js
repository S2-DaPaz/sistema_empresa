module.exports = {
  id: "003_background_jobs",
  description: "Cria a fila persistente de jobs assíncronos.",
  sql: {
    sqlite: `
      CREATE TABLE IF NOT EXISTS background_jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        dedupe_key TEXT,
        attempts INTEGER DEFAULT 0,
        max_attempts INTEGER DEFAULT 5,
        created_at TEXT NOT NULL,
        available_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        last_error TEXT,
        request_id TEXT,
        created_by_user_id INTEGER,
        FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
      );

      CREATE INDEX IF NOT EXISTS idx_background_jobs_status_available
        ON background_jobs (status, available_at, id);
      CREATE INDEX IF NOT EXISTS idx_background_jobs_type
        ON background_jobs (type, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_background_jobs_dedupe_key
        ON background_jobs (dedupe_key);
    `,
    postgres: `
      CREATE TABLE IF NOT EXISTS background_jobs (
        id SERIAL PRIMARY KEY,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        dedupe_key TEXT,
        attempts INTEGER DEFAULT 0,
        max_attempts INTEGER DEFAULT 5,
        created_at TEXT NOT NULL,
        available_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        last_error TEXT,
        request_id TEXT,
        created_by_user_id INTEGER,
        FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
      );

      CREATE INDEX IF NOT EXISTS idx_background_jobs_status_available
        ON background_jobs (status, available_at, id);
      CREATE INDEX IF NOT EXISTS idx_background_jobs_type
        ON background_jobs (type, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_background_jobs_dedupe_key
        ON background_jobs (dedupe_key);
    `
  }
};
