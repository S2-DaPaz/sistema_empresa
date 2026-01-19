const path = require("path");
const sqlite3 = require("sqlite3");
const { open } = require("sqlite");

let db;

async function initDb() {
  if (db) return db;

  db = await open({
    filename: path.join(__dirname, "data.db"),
    driver: sqlite3.Database
  });

  await db.exec(`
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
  `);

  await ensureColumn(db, "task_types", "report_template_id", "INTEGER");
  await ensureColumn(db, "tasks", "signature_mode", "TEXT");
  await ensureColumn(db, "tasks", "signature_scope", "TEXT");
  await ensureColumn(db, "tasks", "signature_client", "TEXT");
  await ensureColumn(db, "tasks", "signature_tech", "TEXT");
  await ensureColumn(db, "tasks", "signature_pages", "TEXT");
  await ensureColumn(db, "reports", "equipment_id", "INTEGER");
  await ensureColumn(db, "budgets", "task_id", "INTEGER");
  await ensureColumn(db, "budgets", "proposal_validity", "TEXT");
  await ensureColumn(db, "budgets", "payment_terms", "TEXT");
  await ensureColumn(db, "budgets", "service_deadline", "TEXT");
  await ensureColumn(db, "budgets", "product_validity", "TEXT");

  return db;
}

async function ensureColumn(database, table, column, type) {
  const info = await database.all(`PRAGMA table_info(${table})`);
  const exists = info.some((item) => item.name === column);
  if (!exists) {
    await database.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${type}`);
  }
}

module.exports = { initDb };
