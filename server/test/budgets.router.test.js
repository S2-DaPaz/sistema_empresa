const test = require("node:test");
const assert = require("node:assert/strict");

const express = require("express");
const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const { PERMISSIONS } = require("../src/config/contracts");
const { createBudgetsRouter } = require("../src/modules/budgets/budgets.router");

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });

  await db.exec(`
    CREATE TABLE budgets (
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
      signature_mode TEXT,
      signature_scope TEXT,
      signature_client TEXT,
      signature_client_name TEXT,
      signature_client_document TEXT,
      signature_tech TEXT,
      signature_pages TEXT,
      subtotal REAL DEFAULT 0,
      discount REAL DEFAULT 0,
      tax REAL DEFAULT 0,
      total REAL DEFAULT 0,
      created_at TEXT NOT NULL
    );

    CREATE TABLE budget_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      budget_id INTEGER NOT NULL,
      product_id INTEGER,
      description TEXT NOT NULL,
      qty REAL DEFAULT 1,
      unit_price REAL DEFAULT 0,
      total REAL DEFAULT 0
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
      permissions: [PERMISSIONS.MANAGE_BUDGETS]
    };
    next();
  });
  app.use(
    "/budgets",
    createBudgetsRouter({
      db,
      publicService: {
        scheduleWarmBudgetPdfCache() {},
        scheduleWarmTaskPdfCache() {},
        getBudgetPdfCacheStatus() {
          return { ready: false };
        },
        warmBudgetPdf() {},
        renderBudgetPdf() {}
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

test("budget update returns 404 instead of crashing when the budget no longer exists", async (t) => {
  const db = await createDb();
  const server = await createServer(db);

  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await db.close();
  });

  const response = await fetch(buildUrl(server, "/budgets/999"), {
    method: "PUT",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      client_id: 1,
      status: "em_andamento",
      discount: 0,
      tax: 0,
      items: []
    })
  });

  assert.equal(response.status, 404);

  const payload = await response.json();
  assert.equal(payload.error.code, "not_found");
});
