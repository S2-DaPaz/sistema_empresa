const test = require("node:test");
const assert = require("node:assert/strict");

const express = require("express");
const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const { PERMISSIONS } = require("../src/config/contracts");
const { createEquipmentsRouter } = require("../src/modules/equipments/equipments.router");

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });

  await db.exec(`
    CREATE TABLE equipments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      model TEXT,
      serial TEXT,
      description TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER
    );

    CREATE TABLE task_equipments (
      task_id INTEGER NOT NULL,
      equipment_id INTEGER NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      task_id INTEGER,
      client_id INTEGER,
      template_id INTEGER,
      equipment_id INTEGER,
      content TEXT,
      status TEXT,
      created_at TEXT NOT NULL
    );
  `);

  return db;
}

async function createServer(db) {
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => {
    req.user = {
      role: "gestor",
      permissions: [PERMISSIONS.MANAGE_TASKS]
    };
    next();
  });
  app.use("/equipments", createEquipmentsRouter({ db }));
  app.use((error, _req, res, _next) => {
    res.status(error.statusCode || 500).json({
      error: {
        code: error.code || "internal_error",
        message: error.message
      }
    });
  });

  return new Promise((resolve) => {
    const server = app.listen(0, () => resolve(server));
  });
}

function buildUrl(server, path) {
  return `http://127.0.0.1:${server.address().port}${path}`;
}

test("equipment update preserves created_at when the client omits the field", async (t) => {
  const db = await createDb();
  const createdAt = "2026-03-10T08:30:00.000Z";

  await db.run(
    `INSERT INTO equipments (client_id, name, model, serial, description, created_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [7, "Bomba", "XPTO", "S123", "Original", createdAt]
  );

  const server = await createServer(db);
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await db.close();
  });

  const response = await fetch(buildUrl(server, "/equipments/1"), {
    method: "PUT",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      client_id: 7,
      name: "Bomba revisada",
      model: "XPTO",
      serial: "S123",
      description: "Atualizada"
    })
  });

  assert.equal(response.status, 200);

  const payload = await response.json();
  assert.equal(payload.data.created_at, createdAt);
  assert.equal(payload.data.name, "Bomba revisada");

  const persisted = await db.get("SELECT created_at FROM equipments WHERE id = ?", [1]);
  assert.equal(persisted.created_at, createdAt);
});
