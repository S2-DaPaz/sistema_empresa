const path = require("path");
const { Pool } = require("pg");

const { DB_TYPES } = require("./db-types");
const { runMigrations } = require("./migrator");
const { migrations } = require("./migrations");

const SQLITE_FILE = path.join(__dirname, "..", "..", "..", "data.db");

let db;
let sqlite3;
let open;

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
  } catch (_error) {
    return false;
  }
}

function normalizePostgresSql(sql) {
  let normalized = String(sql || "").trim().replace(/;$/, "");
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

async function execPostgres(pool, sql) {
  const statements = String(sql || "")
    .split(";")
    .map((statement) => statement.trim())
    .filter(Boolean);

  for (const statement of statements) {
    await pool.query(statement);
  }
}

function createPostgresDb(pool) {
  return {
    type: DB_TYPES.POSTGRES,
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

async function initSqlite() {
  if (!sqlite3) {
    sqlite3 = require("sqlite3");
    ({ open } = require("sqlite"));
  }

  const database = await open({
    filename: SQLITE_FILE,
    driver: sqlite3.Database
  });

  database.type = DB_TYPES.SQLITE;
  await runMigrations(database, DB_TYPES.SQLITE, migrations);
  return database;
}

async function initPostgres() {
  const databaseUrl = process.env.DATABASE_URL;
  const pool = new Pool({
    connectionString: databaseUrl,
    ssl: shouldUseSsl(databaseUrl) ? { rejectUnauthorized: false } : undefined
  });

  await pool.query("SELECT 1");
  const database = createPostgresDb(pool);
  await runMigrations(database, DB_TYPES.POSTGRES, migrations);
  return database;
}

async function initDb() {
  if (db) return db;

  db = shouldUsePostgres() ? await initPostgres() : await initSqlite();
  return db;
}

module.exports = { initDb, DB_TYPES };
