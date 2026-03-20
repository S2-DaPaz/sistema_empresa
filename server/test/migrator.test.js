const test = require("node:test");
const assert = require("node:assert/strict");

const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const { DB_TYPES } = require("../src/infrastructure/database/db-types");
const { migrations } = require("../src/infrastructure/database/migrations");
const { runMigrations } = require("../src/infrastructure/database/migrator");

async function createDb() {
  return open({
    filename: ":memory:",
    driver: sqlite3.Database
  });
}

test("runMigrations creates schema_migrations and applies all versioned migrations", async () => {
  const db = await createDb();

  await runMigrations(db, DB_TYPES.SQLITE, migrations);

  const applied = await db.all("SELECT id FROM schema_migrations ORDER BY id ASC");
  const tables = await db.all(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('users', 'event_logs', 'background_jobs')"
  );

  assert.deepEqual(applied.map((item) => item.id), migrations.map((migration) => migration.id));
  assert.equal(tables.length, 3);
});

test("runMigrations is idempotent when executed multiple times", async () => {
  const db = await createDb();

  await runMigrations(db, DB_TYPES.SQLITE, migrations);
  await runMigrations(db, DB_TYPES.SQLITE, migrations);

  const applied = await db.all("SELECT id FROM schema_migrations ORDER BY id ASC");
  assert.equal(applied.length, migrations.length);
});
