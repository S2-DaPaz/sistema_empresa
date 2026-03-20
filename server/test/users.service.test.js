const test = require("node:test");
const assert = require("node:assert/strict");

const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const { ConflictError } = require("../src/core/errors/app-error");
const usersService = require("../src/modules/users/users.service");

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });

  await db.exec(`
    CREATE TABLE roles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      permissions TEXT,
      is_admin INTEGER DEFAULT 0
    );

    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT,
      role TEXT,
      password_hash TEXT,
      permissions TEXT,
      status TEXT,
      email_verified INTEGER,
      email_verified_at TEXT,
      last_login_at TEXT,
      password_changed_at TEXT
    );
  `);

  await db.run(
    "INSERT INTO roles (key, name, permissions, is_admin) VALUES (?, ?, ?, ?)",
    ["visitante", "Visitante", JSON.stringify([]), 0]
  );

  return db;
}

test("user update rejects duplicate email to avoid ambiguous login accounts", async () => {
  const db = await createDb();

  await db.run(
    `INSERT INTO users (
      name,
      email,
      role,
      password_hash,
      permissions,
      status,
      email_verified,
      email_verified_at,
      last_login_at,
      password_changed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      "Usuario A",
      "a@local",
      "visitante",
      "hash",
      JSON.stringify([]),
      "active",
      1,
      "2026-03-10T10:00:00.000Z",
      null,
      "2026-03-10T10:00:00.000Z"
    ]
  );

  await db.run(
    `INSERT INTO users (
      name,
      email,
      role,
      password_hash,
      permissions,
      status,
      email_verified,
      email_verified_at,
      last_login_at,
      password_changed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      "Usuario B",
      "b@local",
      "visitante",
      "hash",
      JSON.stringify([]),
      "active",
      1,
      "2026-03-10T10:00:00.000Z",
      null,
      "2026-03-10T10:00:00.000Z"
    ]
  );

  await assert.rejects(
    () =>
      usersService.update(db, 1, {
        name: "Usuario A",
        email: "b@local",
        role: "visitante",
        permissions: []
      }),
    (error) => {
      assert.ok(error instanceof ConflictError);
      assert.equal(error.message, "E-mail ja cadastrado.");
      return true;
    }
  );

  await db.close();
});
