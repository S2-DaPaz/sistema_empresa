require("dotenv").config();
const fs = require("fs");
const path = require("path");
const sqlite3 = require("sqlite3");
const { open } = require("sqlite");
const { initDb } = require("../db");

const SQLITE_FILE = path.join(__dirname, "..", "data.db");
const TABLES = [
  "users",
  "clients",
  "products",
  "report_templates",
  "task_types",
  "equipments",
  "tasks",
  "reports",
  "task_equipments",
  "budgets",
  "budget_items"
];
const TABLE_COLUMNS = {
  users: ["id", "name", "email", "role", "password_hash", "permissions"],
  clients: ["id", "name", "cnpj", "address", "contact"],
  products: ["id", "name", "sku", "price", "unit"],
  report_templates: ["id", "name", "description", "structure"],
  task_types: ["id", "name", "description", "report_template_id"],
  equipments: ["id", "client_id", "name", "model", "serial", "description", "created_at"],
  tasks: [
    "id",
    "title",
    "description",
    "client_id",
    "user_id",
    "task_type_id",
    "status",
    "priority",
    "start_date",
    "due_date",
    "signature_mode",
    "signature_scope",
    "signature_client",
    "signature_tech",
    "signature_pages"
  ],
  reports: [
    "id",
    "title",
    "task_id",
    "client_id",
    "template_id",
    "equipment_id",
    "content",
    "status",
    "created_at"
  ],
  task_equipments: ["task_id", "equipment_id", "created_at"],
  budgets: [
    "id",
    "client_id",
    "task_id",
    "report_id",
    "notes",
    "internal_note",
    "proposal_validity",
    "payment_terms",
    "service_deadline",
    "product_validity",
    "status",
    "subtotal",
    "discount",
    "tax",
    "total",
    "created_at"
  ],
  budget_items: [
    "id",
    "budget_id",
    "product_id",
    "description",
    "qty",
    "unit_price",
    "total"
  ]
};
const TABLES_WITH_ID = [
  "users",
  "clients",
  "products",
  "report_templates",
  "task_types",
  "equipments",
  "tasks",
  "reports",
  "budgets",
  "budget_items"
];

function buildIdSet(rows) {
  return new Set(rows.map((row) => row.id).filter((id) => id !== null && id !== undefined));
}

function normalizeRow(row) {
  const normalized = {};
  Object.entries(row).forEach(([key, value]) => {
    normalized[key] = value === undefined ? null : value;
  });
  return normalized;
}

function sanitizeData(data) {
  const sets = {
    users: buildIdSet(data.users),
    clients: buildIdSet(data.clients),
    products: buildIdSet(data.products),
    report_templates: buildIdSet(data.report_templates),
    task_types: buildIdSet(data.task_types),
    tasks: buildIdSet(data.tasks),
    equipments: new Set(),
    reports: new Set(),
    budgets: new Set()
  };

  data.task_types = data.task_types.map((row) => ({
    ...row,
    report_template_id: sets.report_templates.has(row.report_template_id)
      ? row.report_template_id
      : null
  }));

  data.equipments = data.equipments.filter((row) => sets.clients.has(row.client_id));
  sets.equipments = buildIdSet(data.equipments);

  data.tasks = data.tasks.map((row) => ({
    ...row,
    client_id: sets.clients.has(row.client_id) ? row.client_id : null,
    user_id: sets.users.has(row.user_id) ? row.user_id : null,
    task_type_id: sets.task_types.has(row.task_type_id) ? row.task_type_id : null
  }));
  sets.tasks = buildIdSet(data.tasks);

  data.reports = data.reports.map((row) => ({
    ...row,
    client_id: sets.clients.has(row.client_id) ? row.client_id : null,
    task_id: sets.tasks.has(row.task_id) ? row.task_id : null,
    template_id: sets.report_templates.has(row.template_id) ? row.template_id : null,
    equipment_id: sets.equipments.has(row.equipment_id) ? row.equipment_id : null
  }));
  sets.reports = buildIdSet(data.reports);

  data.task_equipments = data.task_equipments.filter(
    (row) => sets.tasks.has(row.task_id) && sets.equipments.has(row.equipment_id)
  );

  data.budgets = data.budgets.map((row) => ({
    ...row,
    client_id: sets.clients.has(row.client_id) ? row.client_id : null,
    task_id: sets.tasks.has(row.task_id) ? row.task_id : null,
    report_id: sets.reports.has(row.report_id) ? row.report_id : null
  }));
  sets.budgets = buildIdSet(data.budgets);

  data.budget_items = data.budget_items
    .filter((row) => sets.budgets.has(row.budget_id))
    .map((row) => ({
      ...row,
      product_id: sets.products.has(row.product_id) ? row.product_id : null
    }));
}

async function insertRows(db, table, rows) {
  if (!rows.length) return;
  const columns = TABLE_COLUMNS[table] || Object.keys(rows[0]);
  const placeholders = columns.map(() => "?").join(", ");
  const sql = `INSERT INTO ${table} (${columns.join(", ")}) VALUES (${placeholders})`;
  for (const row of rows) {
    const normalized = normalizeRow(row);
    const values = columns.map((column) =>
      Object.prototype.hasOwnProperty.call(normalized, column) ? normalized[column] : null
    );
    await db.run(sql, values);
  }
}

async function setSequence(db, table) {
  const row = await db.get(`SELECT MAX(id) AS max_id FROM ${table}`);
  const max = Number(row?.max_id || 0);
  const value = max || 1;
  await db.run("SELECT setval(?::regclass, ?, ?)", [
    `${table}_id_seq`,
    value,
    max > 0
  ]);
}

async function ensureEmptyOrReset(db) {
  const counts = await Promise.all(
    TABLES.map(async (table) => {
      const row = await db.get(`SELECT COUNT(*) AS count FROM ${table}`);
      return Number(row?.count || 0);
    })
  );
  const total = counts.reduce((sum, count) => sum + count, 0);
  if (total === 0) return;

  const shouldReset =
    process.env.RESET_DB === "1" ||
    process.env.RESET_DB === "true" ||
    process.env.FORCE === "1" ||
    process.env.FORCE === "true";

  if (!shouldReset) {
    throw new Error(
      "Neon database is not empty. Set RESET_DB=1 to truncate before migrating."
    );
  }

  await db.exec(
    `TRUNCATE ${TABLES.join(", ")} RESTART IDENTITY CASCADE`
  );
}

async function main() {
  if (!process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL is required to migrate to Neon.");
  }

  if (!fs.existsSync(SQLITE_FILE)) {
    throw new Error(`SQLite file not found at ${SQLITE_FILE}`);
  }

  const sqliteDb = await open({
    filename: SQLITE_FILE,
    driver: sqlite3.Database
  });
  const pgDb = await initDb();

  await ensureEmptyOrReset(pgDb);

  const data = {};
  for (const table of TABLES) {
    data[table] = await sqliteDb.all(`SELECT * FROM ${table}`);
  }

  sanitizeData(data);

  await insertRows(pgDb, "users", data.users);
  await insertRows(pgDb, "clients", data.clients);
  await insertRows(pgDb, "products", data.products);
  await insertRows(pgDb, "report_templates", data.report_templates);
  await insertRows(pgDb, "task_types", data.task_types);
  await insertRows(pgDb, "equipments", data.equipments);
  await insertRows(pgDb, "tasks", data.tasks);
  await insertRows(pgDb, "reports", data.reports);
  await insertRows(pgDb, "task_equipments", data.task_equipments);
  await insertRows(pgDb, "budgets", data.budgets);
  await insertRows(pgDb, "budget_items", data.budget_items);

  for (const table of TABLES_WITH_ID) {
    await setSequence(pgDb, table);
  }

  await sqliteDb.close();
  console.log("Migration completed.");
}

main().catch((error) => {
  console.error("Migration failed:", error.message);
  process.exit(1);
});
