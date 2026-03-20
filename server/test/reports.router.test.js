const test = require("node:test");
const assert = require("node:assert/strict");

const express = require("express");
const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const { PERMISSIONS } = require("../src/config/contracts");
const { createReportsRouter } = require("../src/modules/reports/reports.router");

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });

  await db.exec(`
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
  app.use(
    "/reports",
    createReportsRouter({
      db,
      publicService: {
        scheduleWarmTaskPdfCache() {}
      }
    })
  );
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

test("partial report update preserves existing fields and created_at", async (t) => {
  const db = await createDb();
  const createdAt = "2026-03-18T10:00:00.000Z";

  await db.run(
    `INSERT INTO reports (
      title,
      task_id,
      client_id,
      template_id,
      equipment_id,
      content,
      status,
      created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      "Relatorio principal",
      12,
      4,
      8,
      null,
      JSON.stringify({
        sections: [{ id: "summary", title: "Resumo", fields: [] }],
        answers: { notes: "ok" }
      }),
      "rascunho",
      createdAt
    ]
  );

  const server = await createServer(db);
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await db.close();
  });

  const response = await fetch(buildUrl(server, "/reports/1"), {
    method: "PUT",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ equipment_id: 33 })
  });

  assert.equal(response.status, 200);

  const payload = await response.json();
  assert.equal(payload.data.title, "Relatorio principal");
  assert.equal(payload.data.task_id, 12);
  assert.equal(payload.data.client_id, 4);
  assert.equal(payload.data.template_id, 8);
  assert.equal(payload.data.equipment_id, 33);
  assert.equal(payload.data.status, "rascunho");
  assert.equal(payload.data.created_at, createdAt);
  assert.deepEqual(payload.data.content.answers, { notes: "ok" });

  const persisted = await db.get("SELECT * FROM reports WHERE id = ?", [1]);
  assert.equal(persisted.created_at, createdAt);
  assert.equal(persisted.title, "Relatorio principal");
  assert.equal(persisted.equipment_id, 33);
});

test("report update returns 404 when the report no longer exists", async (t) => {
  const db = await createDb();
  const server = await createServer(db);

  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await db.close();
  });

  const response = await fetch(buildUrl(server, "/reports/999"), {
    method: "PUT",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ equipment_id: 10 })
  });

  assert.equal(response.status, 404);

  const payload = await response.json();
  assert.equal(payload.error.code, "not_found");
});
