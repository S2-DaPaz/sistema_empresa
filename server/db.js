const path = require("path");
const sqlite3 = require("sqlite3");
const { open } = require("sqlite");
const { Pool } = require("pg");

const SQLITE_FILE = path.join(__dirname, "data.db");
const DB_TYPES = {
  SQLITE: "sqlite",
  POSTGRES: "postgres"
};

let db;

const SQLITE_SCHEMA = `
  PRAGMA foreign_keys = ON;

  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT,
    role TEXT
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
`;

const POSTGRES_SCHEMA = `
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT,
    role TEXT
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
  const database = await open({
    filename: SQLITE_FILE,
    driver: sqlite3.Database
  });

  await database.exec(SQLITE_SCHEMA);
  await ensureColumn(database, DB_TYPES.SQLITE, "task_types", "report_template_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_mode", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_scope", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_client", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_tech", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "tasks", "signature_pages", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "reports", "equipment_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "task_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "proposal_validity", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "payment_terms", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "service_deadline", "TEXT");
  await ensureColumn(database, DB_TYPES.SQLITE, "budgets", "product_validity", "TEXT");

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
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_mode", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_scope", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_client", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_tech", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "tasks", "signature_pages", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "reports", "equipment_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "task_id", "INTEGER");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "proposal_validity", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "payment_terms", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "service_deadline", "TEXT");
  await ensureColumn(database, DB_TYPES.POSTGRES, "budgets", "product_validity", "TEXT");

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
