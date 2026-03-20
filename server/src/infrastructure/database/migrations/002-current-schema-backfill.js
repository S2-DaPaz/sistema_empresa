const { DB_TYPES } = require("../db-types");

async function ensureColumn(db, type, table, column, columnType) {
  if (type === DB_TYPES.POSTGRES) {
    await db.exec(`ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS ${column} ${columnType}`);
    return;
  }

  const info = await db.all(`PRAGMA table_info(${table})`);
  const exists = info.some((item) => item.name === column);
  if (!exists) {
    await db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${columnType}`);
  }
}

const SHARED_COLUMNS = [
  ["task_types", "report_template_id", "INTEGER"],
  ["users", "password_hash", "TEXT"],
  ["users", "permissions", "TEXT"],
  ["users", "email_verified_at", "TEXT"],
  ["users", "last_login_at", "TEXT"],
  ["users", "password_changed_at", "TEXT"],
  ["tasks", "signature_mode", "TEXT"],
  ["tasks", "signature_scope", "TEXT"],
  ["tasks", "signature_client", "TEXT"],
  ["tasks", "signature_client_name", "TEXT"],
  ["tasks", "signature_client_document", "TEXT"],
  ["tasks", "signature_tech", "TEXT"],
  ["tasks", "signature_pages", "TEXT"],
  ["reports", "equipment_id", "INTEGER"],
  ["budgets", "task_id", "INTEGER"],
  ["budgets", "proposal_validity", "TEXT"],
  ["budgets", "payment_terms", "TEXT"],
  ["budgets", "service_deadline", "TEXT"],
  ["budgets", "product_validity", "TEXT"],
  ["budgets", "signature_mode", "TEXT"],
  ["budgets", "signature_scope", "TEXT"],
  ["budgets", "signature_client", "TEXT"],
  ["budgets", "signature_client_name", "TEXT"],
  ["budgets", "signature_client_document", "TEXT"],
  ["budgets", "signature_tech", "TEXT"],
  ["budgets", "signature_pages", "TEXT"]
];

module.exports = {
  id: "002_current_schema_backfill",
  description: "Garante colunas de compatibilidade para bases antigas.",
  async up({ db, type }) {
    const userEmailVerifiedType =
      type === DB_TYPES.POSTGRES ? "BOOLEAN DEFAULT FALSE" : "INTEGER DEFAULT 0";
    const userStatusType =
      type === DB_TYPES.POSTGRES
        ? "TEXT DEFAULT 'pending_verification'"
        : "TEXT DEFAULT 'pending_verification'";

    await ensureColumn(db, type, "users", "email_verified", userEmailVerifiedType);
    await ensureColumn(db, type, "users", "status", userStatusType);

    for (const [table, column, columnType] of SHARED_COLUMNS) {
      await ensureColumn(db, type, table, column, columnType);
    }
  }
};
