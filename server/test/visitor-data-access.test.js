const test = require("node:test");
const assert = require("node:assert/strict");

const express = require("express");

const { createVisitorDataIsolationMiddleware } = require("../src/core/security/visitor-data-access");

function buildUrl(server, path) {
  return `http://127.0.0.1:${server.address().port}${path}`;
}

async function createServer(user) {
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => {
    req.user = user;
    next();
  });
  app.use(createVisitorDataIsolationMiddleware());

  app.get("/summary", (_req, res) => {
    res.status(200).json({ reached: true });
  });

  app.get("/clients", (_req, res) => {
    res.status(200).json({ reached: true });
  });

  app.get("/clients/:id", (_req, res) => {
    res.status(200).json({ reached: true });
  });

  app.post("/clients", (_req, res) => {
    res.status(201).json({ reached: true });
  });

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

test("visitor receives empty dashboard payload without reaching downstream route", async (t) => {
  const server = await createServer({ role: "visitante" });

  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
  });

  const response = await fetch(buildUrl(server, "/summary"));
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.data.summary.clients, 0);
  assert.equal(payload.data.summary.tasks, 0);
  assert.deepEqual(payload.data.recentTasks, []);
  assert.equal(payload.data.notificationCount, 0);
});

test("visitor receives empty lists and cannot access detail or writes", async (t) => {
  const server = await createServer({ role: "visitante" });

  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
  });

  const listResponse = await fetch(buildUrl(server, "/clients"));
  const listPayload = await listResponse.json();
  assert.equal(listResponse.status, 200);
  assert.deepEqual(listPayload.data, []);

  const detailResponse = await fetch(buildUrl(server, "/clients/1"));
  const detailPayload = await detailResponse.json();
  assert.equal(detailResponse.status, 404);
  assert.equal(detailPayload.error.code, "not_found");

  const createResponse = await fetch(buildUrl(server, "/clients"), {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ name: "Cliente visitante" })
  });
  const createPayload = await createResponse.json();
  assert.equal(createResponse.status, 403);
  assert.equal(createPayload.error.code, "forbidden");
});

test("non-visitor requests continue to downstream routes", async (t) => {
  const server = await createServer({ role: "gestor" });

  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
  });

  const response = await fetch(buildUrl(server, "/clients"));
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.reached, true);
});
