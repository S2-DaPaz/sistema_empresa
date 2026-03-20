const { DB_TYPES } = require("./db-types");

function splitStatements(sql) {
  return String(sql || "")
    .split(";")
    .map((statement) => statement.trim())
    .filter(Boolean);
}

async function ensureMigrationsTable(db, type) {
  const sql =
    type === DB_TYPES.POSTGRES
      ? `
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id TEXT PRIMARY KEY,
          description TEXT,
          applied_at TEXT NOT NULL
        )
      `
      : `
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id TEXT PRIMARY KEY,
          description TEXT,
          applied_at TEXT NOT NULL
        )
      `;

  await db.exec(sql);
}

async function listAppliedMigrationIds(db) {
  const rows = await db.all("SELECT id FROM schema_migrations ORDER BY applied_at ASC");
  return new Set(rows.map((row) => row.id));
}

async function recordMigration(db, migration) {
  await db.run(
    "INSERT INTO schema_migrations (id, description, applied_at) VALUES (?, ?, ?)",
    [migration.id, migration.description || migration.id, new Date().toISOString()]
  );
}

async function runMigration(db, type, migration) {
  if (typeof migration.up === "function") {
    await migration.up({ db, type });
    return;
  }

  const rawSql =
    type === DB_TYPES.POSTGRES ? migration.sql?.postgres || migration.sql?.default : migration.sql?.sqlite || migration.sql?.default;
  for (const statement of splitStatements(rawSql)) {
    await db.exec(statement);
  }
}

async function runMigrations(db, type, migrations) {
  await ensureMigrationsTable(db, type);
  const appliedIds = await listAppliedMigrationIds(db);

  for (const migration of migrations) {
    if (appliedIds.has(migration.id)) {
      continue;
    }

    await runMigration(db, type, migration);
    await recordMigration(db, migration);
  }
}

module.exports = { runMigrations };
