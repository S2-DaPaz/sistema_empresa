const test = require("node:test");
const assert = require("node:assert/strict");

const { createApp } = require("../src/app/create-app");

function createEnv() {
  return {
    allowedOrigins: [],
    staticDir: "",
    mobileUpdate: {
      versionCode: 0,
      versionName: "",
      apkUrl: "",
      notes: "",
      mandatory: false
    },
    jwtSecret: "test-secret",
    jwtTtl: "15m",
    accessTokenTtl: "15m"
  };
}

function createMonitoringService(counter) {
  return {
    createRequestTrackingMiddleware() {
      return (req, _res, next) => {
        counter.calls += 1;
        next();
      };
    },
    async recordError() {},
    buildErrorResponse() {
      return {
        statusCode: 500,
        payload: {
          error: {
            code: "internal_error",
            message: "unexpected"
          }
        }
      };
    }
  };
}

function createPublicService() {
  return {
    renderPublicTaskPage: async () => "",
    renderFriendlyPublicError: () => "",
    approveTask: async () => ({}),
    removeTaskSignature: async () => ({}),
    renderTaskPdf: async () => Buffer.from(""),
    renderPublicBudgetPage: async () => "",
    approveBudget: async () => ({}),
    removeBudgetSignature: async () => ({}),
    renderBudgetPdf: async () => Buffer.from("")
  };
}

function buildUrl(server, path) {
  return `http://127.0.0.1:${server.address().port}${path}`;
}

test("GET /api/health returns 200, keeps compatibility and bypasses request tracking", async (t) => {
  const trackingCounter = { calls: 0 };
  const app = createApp({
    db: {},
    env: createEnv(),
    logger: {
      error() {},
      info() {}
    },
    publicService: createPublicService(),
    monitoringService: createMonitoringService(trackingCounter),
    emailService: {}
  });

  const server = await new Promise((resolve) => {
    const instance = app.listen(0, () => resolve(instance));
  });

  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
  });

  const response = await fetch(buildUrl(server, "/api/health"));
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(payload.data.ok, true);
  assert.equal(payload.data.service, "api");
  assert.match(payload.data.timestamp, /^\d{4}-\d{2}-\d{2}T/);
  assert.equal(trackingCounter.calls, 0);
});
