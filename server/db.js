const path = require("path");
const { Pool } = require("pg");

const SQLITE_FILE = path.join(__dirname, "data.db");
const DB_TYPES = {
  SQLITE: "sqlite",
  POSTGRES: "postgres"
};

let db;
let sqlite3;
let open;

const SQLITE_SCHEMA = `
  PRAGMA foreign_keys = ON;

  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT,
    role TEXT,
    password_hash TEXT,
    permissions TEXT,
    email_verified INTEGER DEFAULT 0,
    email_verified_at TEXT,
    status TEXT DEFAULT 'pending_verification',
    last_login_at TEXT,
    password_changed_at TEXT
  );

  CREATE TABLE IF NOT EXISTS roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    permissions TEXT,
    is_admin INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    cnpj TEXT,
    address TEXT,
    contact TEXT
  );

  CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    sku TEXT,
    price REAL DEFAULT 0,
    unit TEXT
  );

  CREATE TABLE IF NOT EXISTS report_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    structure TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS task_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    report_template_id INTEGER,
    FOREIGN KEY (report_template_id) REFERENCES report_templates (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS equipments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    model TEXT,
    serial TEXT,
    description TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    client_id INTEGER,
    user_id INTEGER,
    task_type_id INTEGER,
    status TEXT,
    priority TEXT,
    start_date TEXT,
    due_date TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_client_name TEXT,
    signature_client_document TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (task_type_id) REFERENCES task_types (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    task_id INTEGER,
    client_id INTEGER,
    template_id INTEGER,
    equipment_id INTEGER,
    content TEXT,
    status TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (template_id) REFERENCES report_templates (id) ON DELETE SET NULL,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_equipments (
    task_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (task_id, equipment_id),
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER,
    task_id INTEGER,
    report_id INTEGER,
    notes TEXT,
    internal_note TEXT,
    proposal_validity TEXT,
    payment_terms TEXT,
    service_deadline TEXT,
    product_validity TEXT,
    status TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_client_name TEXT,
    signature_client_document TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    subtotal REAL DEFAULT 0,
    discount REAL DEFAULT 0,
    tax REAL DEFAULT 0,
    total REAL DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (report_id) REFERENCES reports (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS budget_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    budget_id INTEGER NOT NULL,
    product_id INTEGER,
    description TEXT NOT NULL,
    qty REAL DEFAULT 1,
    unit_price REAL DEFAULT 0,
    total REAL DEFAULT 0,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_public_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_task_public_links_task_id
    ON task_public_links (task_id);

  CREATE TABLE IF NOT EXISTS budget_public_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    budget_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_budget_public_links_budget_id
    ON budget_public_links (budget_id);

  CREATE TABLE IF NOT EXISTS auth_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    purpose TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    consumed_at TEXT,
    created_at TEXT NOT NULL,
    last_sent_at TEXT NOT NULL,
    resend_count INTEGER DEFAULT 0,
    attempt_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_auth_codes_user_purpose
    ON auth_codes (user_id, purpose, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    last_used_at TEXT,
    device_info TEXT,
    ip_address TEXT,
    platform TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_sessions_token_hash
    ON auth_sessions (token_hash);
  CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id
    ON auth_sessions (user_id, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action_key TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    attempts INTEGER DEFAULT 0,
    window_started_at TEXT NOT NULL,
    blocked_until TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_rate_limits_scope
    ON auth_rate_limits (action_key, scope_key);

  CREATE TABLE IF NOT EXISTS error_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    severity TEXT NOT NULL,
    category TEXT,
    error_code TEXT,
    friendly_message TEXT NOT NULL,
    technical_message TEXT,
    stack_trace TEXT,
    http_status INTEGER,
    http_method TEXT,
    endpoint TEXT,
    module TEXT,
    platform TEXT,
    screen_route TEXT,
    operation TEXT,
    request_id TEXT,
    environment TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    context_json TEXT,
    payload_json TEXT,
    resolved_at TEXT,
    resolved_by_user_id INTEGER,
    resolution_note TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_error_logs_created_at
    ON error_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_error_logs_severity
    ON error_logs (severity);
  CREATE INDEX IF NOT EXISTS idx_error_logs_module
    ON error_logs (module);
  CREATE INDEX IF NOT EXISTS idx_error_logs_platform
    ON error_logs (platform);

  CREATE TABLE IF NOT EXISTS event_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    action TEXT NOT NULL,
    description TEXT NOT NULL,
    module TEXT,
    entity_type TEXT,
    entity_id TEXT,
    outcome TEXT NOT NULL,
    platform TEXT,
    ip_address TEXT,
    route_path TEXT,
    http_method TEXT,
    request_id TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    user_role TEXT,
    metadata_json TEXT,
    before_json TEXT,
    after_json TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_event_logs_created_at
    ON event_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_event_logs_action
    ON event_logs (action);
  CREATE INDEX IF NOT EXISTS idx_event_logs_module
    ON event_logs (module);
  CREATE INDEX IF NOT EXISTS idx_event_logs_platform
    ON event_logs (platform);
`;

const POSTGRES_SCHEMA = `
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT,
    role TEXT,
    password_hash TEXT,
    permissions TEXT,
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TEXT,
    status TEXT DEFAULT 'pending_verification',
    last_login_at TEXT,
    password_changed_at TEXT
  );

  CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    permissions TEXT,
    is_admin BOOLEAN DEFAULT FALSE
  );

  CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    cnpj TEXT,
    address TEXT,
    contact TEXT
  );

  CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    sku TEXT,
    price DOUBLE PRECISION DEFAULT 0,
    unit TEXT
  );

  CREATE TABLE IF NOT EXISTS report_templates (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    structure TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS task_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    report_template_id INTEGER,
    FOREIGN KEY (report_template_id) REFERENCES report_templates (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS equipments (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    model TEXT,
    serial TEXT,
    description TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    client_id INTEGER,
    user_id INTEGER,
    task_type_id INTEGER,
    status TEXT,
    priority TEXT,
    start_date TEXT,
    due_date TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (task_type_id) REFERENCES task_types (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS reports (
    id SERIAL PRIMARY KEY,
    title TEXT,
    task_id INTEGER,
    client_id INTEGER,
    template_id INTEGER,
    equipment_id INTEGER,
    content TEXT,
    status TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (template_id) REFERENCES report_templates (id) ON DELETE SET NULL,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_equipments (
    task_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (task_id, equipment_id),
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS budgets (
    id SERIAL PRIMARY KEY,
    client_id INTEGER,
    task_id INTEGER,
    report_id INTEGER,
    notes TEXT,
    internal_note TEXT,
    proposal_validity TEXT,
    payment_terms TEXT,
    service_deadline TEXT,
    product_validity TEXT,
    status TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    subtotal DOUBLE PRECISION DEFAULT 0,
    discount DOUBLE PRECISION DEFAULT 0,
    tax DOUBLE PRECISION DEFAULT 0,
    total DOUBLE PRECISION DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (report_id) REFERENCES reports (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS budget_items (
    id SERIAL PRIMARY KEY,
    budget_id INTEGER NOT NULL,
    product_id INTEGER,
    description TEXT NOT NULL,
    qty DOUBLE PRECISION DEFAULT 1,
    unit_price DOUBLE PRECISION DEFAULT 0,
    total DOUBLE PRECISION DEFAULT 0,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_public_links (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_task_public_links_task_id
    ON task_public_links (task_id);

  CREATE TABLE IF NOT EXISTS budget_public_links (
    id SERIAL PRIMARY KEY,
    budget_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_budget_public_links_budget_id
    ON budget_public_links (budget_id);

  CREATE TABLE IF NOT EXISTS auth_codes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    purpose TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    consumed_at TEXT,
    created_at TEXT NOT NULL,
    last_sent_at TEXT NOT NULL,
    resend_count INTEGER DEFAULT 0,
    attempt_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_auth_codes_user_purpose
    ON auth_codes (user_id, purpose, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    last_used_at TEXT,
    device_info TEXT,
    ip_address TEXT,
    platform TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_sessions_token_hash
    ON auth_sessions (token_hash);
  CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id
    ON auth_sessions (user_id, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id SERIAL PRIMARY KEY,
    action_key TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    attempts INTEGER DEFAULT 0,
    window_started_at TEXT NOT NULL,
    blocked_until TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_rate_limits_scope
    ON auth_rate_limits (action_key, scope_key);

  CREATE TABLE IF NOT EXISTS error_logs (
    id SERIAL PRIMARY KEY,
    created_at TEXT NOT NULL,
    severity TEXT NOT NULL,
    category TEXT,
    error_code TEXT,
    friendly_message TEXT NOT NULL,
    technical_message TEXT,
    stack_trace TEXT,
    http_status INTEGER,
    http_method TEXT,
    endpoint TEXT,
    module TEXT,
    platform TEXT,
    screen_route TEXT,
    operation TEXT,
    request_id TEXT,
    environment TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    context_json TEXT,
    payload_json TEXT,
    resolved_at TEXT,
    resolved_by_user_id INTEGER,
    resolution_note TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_error_logs_created_at
    ON error_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_error_logs_severity
    ON error_logs (severity);
  CREATE INDEX IF NOT EXISTS idx_error_logs_module
    ON error_logs (module);
  CREATE INDEX IF NOT EXISTS idx_error_logs_platform
    ON error_logs (platform);

  CREATE TABLE IF NOT EXISTS event_logs (
    id SERIAL PRIMARY KEY,
    created_at TEXT NOT NULL,
    action TEXT NOT NULL,
    description TEXT NOT NULL,
    module TEXT,
    entity_type TEXT,
    entity_id TEXT,
    outcome TEXT NOT NULL,
    platform TEXT,
    ip_address TEXT,
    route_path TEXT,
    http_method TEXT,
    request_id TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    user_role TEXT,
    metadata_json TEXT,
    before_json TEXT,
    after_json TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_event_logs_created_at
    ON event_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_event_logs_action
    ON event_logs (action);
  CREATE INDEX IF NOT EXISTS idx_event_logs_module
    ON event_logs (module);
  CREATE INDEX IF NOT EXISTS idx_event_logs_platform
    ON event_logs (platform);
`;

function shouldUsePostgres() {
  return Boolean(process.env.DATABASE_URL);
}

function shouldUseSsl(databaseUrl) {
  if (process.env.DATABASE_SSL === "true") return true;
  if (!databaseUrl) return false;
  try {
    const parsed = new URL(databaseUrl);
    const sslMode = parsed.searchParams.get("sslmode");
    const ssl = parsed.searchParams.get("ssl");
    return sslMode === "require" || ssl === "true";
  } catch (error) {
    return false;
  }
}

async function initDb() {
  if (db) return db;

  if (shouldUsePostgres()) {
    db = await initPostgres();
  } else {
    db = await initSqlite();
  }

  return db;
}

async function initSqlite() {
  if (!sqlite3) {
    sqlite3 = require("sqlite3");
    ({ open } = require("sqlite"));
  }
  const database = await open({
    filename: SQLITE_FILE,
    driver: sqlite3.Database
  });

  await database.exec(SQLITE_SCHEMA);
  await ensureColumn(database, DB_TYPES.SQLITE, "task_types", "report_template_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.SQLITE, "users", "password_hash", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "users", "permissions", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "users", "email_verified", "INTEGER DEFAULT 0");
  await ensureColumn(database, DB_TYPES.SQLITE, "users", "email_verified_at", "TEXT");
  await ensureColumn(
    database,
    DB_TYPES.SQLITE,
    "users",
    "status",
    "TEXT DEFAULT 'pending_verification'"
  );
  await ensureColumn(database, DB_TYPES.SQLITE, "users", "last_login_at", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "users", "password_changed_at", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_mode", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_scope", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_client", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_client_name", "TEXT");
  await ensureColumn(
    database,
    DB_TYPES.SQLITE,
    "tasks",
    "signature_client_document",
    "TEXT"
  );
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_tech", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_pages", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "reports", "equipment_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "task_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "proposal_validity", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "payment_terms", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "service_deadline", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "product_validity", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "signature_mode", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "signature_scope", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "signature_client", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "signature_client_name", "TEXT");
  await ensureColumn(
    database,
    DB_TYPES.SQLITE,
    "budgets",
    "signature_client_document",
    "TEXT"
  );
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "signature_tech", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "signature_pages", "TEXT");

  return database;
}

async function initPostgres() {
  const databaseUrl = process.env.DATABASE_URL;
  const pool = new Pool({
    connectionString: databaseUrl,
    ssl: shouldUseSsl(databaseUrl) ? { rejectUnauthorized: false } : undefined
  });

  await pool.query("SELECT 1");
  await execPostgres(pool, POSTGRES_SCHEMA);

  const database = createPostgresDb(pool);
  await ensureColumn(database, DB_TYPES.POSTGRES, "task_types", "report_template_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.POSTGRES, "users", "password_hash", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "users", "permissions", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "users", "email_verified", "BOOLEAN DEFAULT FALSE");
  await ensureColumn(database, DB_TYPES.POSTGRES, "users", "email_verified_at", "TEXT");
  await ensureColumn(
    database,
    DB_TYPES.POSTGRES,
    "users",
    "status",
    "TEXT DEFAULT 'pending_verification'"
  );
  await ensureColumn(database, DB_TYPES.POSTGRES, "users", "last_login_at", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "users", "password_changed_at", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_mode", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_scope", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_client", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_client_name", "TEXT");
  await ensureColumn(
    database,
    DB_TYPES.POSTGRES,
    "tasks",
    "signature_client_document",
    "TEXT"
  );
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_tech", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_pages", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "reports", "equipment_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "task_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "proposal_validity", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "payment_terms", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "service_deadline", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "product_validity", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "signature_mode", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "signature_scope", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "signature_client", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "signature_client_name", "TEXT");
  await ensureColumn(
    database,
    DB_TYPES.POSTGRES,
    "budgets",
    "signature_client_document",
    "TEXT"
  );
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "signature_tech", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "signature_pages", "TEXT");

  return database;
}

function normalizePostgresSql(sql) {
  let normalized = sql.trim().replace(/;$/, "");
  if (/INSERT\s+OR\s+IGNORE\s+INTO/i.test(normalized)) {
    normalized = normalized.replace(/INSERT\s+OR\s+IGNORE\s+INTO/i, "INSERT INTO");
    if (!/ON\s+CONFLICT/i.test(normalized)) {
      normalized = `${normalized} ON CONFLICT DO NOTHING`;
    }
  }
  return normalized;
}

function replacePlaceholders(sql) {
  let index = 0;
  return sql.replace(/\?/g, () => `$${++index}`);
}

function shouldReturnId(sql) {
  if (!/^INSERT/i.test(sql)) return false;
  if (/RETURNING/i.test(sql)) return false;
  if (/INSERT\s+INTO\s+task_equipments/i.test(sql)) return false;
  return true;
}

function preparePostgresSql(sql, { returning = false } = {}) {
  let prepared = normalizePostgresSql(sql);
  prepared = replacePlaceholders(prepared);
  if (returning && shouldReturnId(prepared)) {
    prepared = `${prepared} RETURNING id`;
  }
  return prepared;
}

function createPostgresDb(pool) {
  return {
    async exec(sql) {
      await execPostgres(pool, sql);
    },
    async run(sql, params = []) {
      const prepared = preparePostgresSql(sql, { returning: true });
      const result = await pool.query(prepared, params);
      return {
        lastID: result.rows?.[0]?.id ?? null,
        changes: result.rowCount
      };
    },
    async get(sql, params = []) {
      const prepared = preparePostgresSql(sql);
      const result = await pool.query(prepared, params);
      return result.rows[0];
    },
    async all(sql, params = []) {
      const prepared = preparePostgresSql(sql);
      const result = await pool.query(prepared, params);
      return result.rows;
    }
  };
}

async function execPostgres(pool, sql) {
  const statements = sql
    .split(";")
    .map((statement) => statement.trim())
    .filter(Boolean);

  for (const statement of statements) {
    await pool.query(statement);
  }
}

async function ensureColumn(database, type, table, column, columnType) {
  if (type === DB_TYPES.POSTGRES) {
    await database.exec(
      `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS ${column} ${columnType}`
    );
    return;
  }

  const info = await database.all(`PRAGMA table_info(${table})`);
  const exists = info.some((item) => item.name === column);
  if (!exists) {
    await database.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${columnType}`);
  }
}

module.exports = { initDb };
