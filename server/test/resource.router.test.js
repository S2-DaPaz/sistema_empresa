const test = require("node:test");
const assert = require("node:assert/strict");

const express = require("express");
const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const { PERMISSIONS } = require("../src/config/contracts");
const { createResourceRouter } = require("../src/modules/resources/resource.router");

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });

  await db.exec(`
    CREATE TABLE clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
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
      permissions: [PERMISSIONS.MANAGE_CLIENTS]
    };
    next();
  });
  app.use(
    "/clients",
    createResourceRouter({
      db,
      config: {
        table: "clients",
        fields: ["name"],
        orderBy: "name ASC",
        permissions: {
          view: PERMISSIONS.VIEW_CLIENTS,
          manage: PERMISSIONS.MANAGE_CLIENTS
        }
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

test("generic resource update returns 404 instead of silent success for missing rows", async (t) => {
  const db = await createDb();
  const server = await createServer(db);

  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await db.close();
  });

  const response = await fetch(buildUrl(server, "/clients/999"), {
    method: "PUT",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ name: "Cliente removido" })
  });

  assert.equal(response.status, 404);

  const payload = await response.json();
  assert.equal(payload.error.code, "not_found");
});
