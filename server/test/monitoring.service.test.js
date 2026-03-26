const test = require("node:test");
const assert = require("node:assert/strict");

const { UnauthorizedError } = require("../src/core/errors/app-error");
const { createMonitoringService } = require("../src/modules/monitoring/monitoring.service");

function createService() {
  return createMonitoringService({
    env: { nodeEnv: "test" },
    logger: {
      error() {}
    }
  });
}

test("buildErrorResponse maps login unauthorized errors to a friendly auth message", () => {
  const service = createService();
  const response = service.buildErrorResponse(
    {
      path: "/api/auth/login",
      originalUrl: "/api/auth/login",
      requestId: "req-auth"
    },
    new UnauthorizedError("Token inválido.")
  );

  assert.equal(response.statusCode, 401);
  assert.deepEqual(response.payload, {
    error: {
      code: "unauthorized",
      category: "authentication_error",
      message: "Não foi possível autenticar com os dados informados.",
      details: undefined,
      requestId: "req-auth"
    }
  });
});

test("buildErrorResponse hides unexpected technical messages from the client payload", () => {
  const service = createService();
  const response = service.buildErrorResponse(
    {
      path: "/api/tasks",
      originalUrl: "/api/tasks",
      requestId: "req-500"
    },
    new Error("ECONNREFUSED postgres://secret-db")
  );

  assert.equal(response.statusCode, 500);
  assert.equal(response.payload.error.code, "internal_error");
  assert.equal(response.payload.error.category, "server_error");
  assert.equal(
    response.payload.error.message,
    "Algo deu errado. Tente novamente em instantes."
  );
  assert.equal(response.payload.error.requestId, "req-500");
});

test("createRequestTrackingMiddleware skips lightweight health checks", async () => {
  const service = createService();
  const middleware = service.createRequestTrackingMiddleware({});
  const events = [];
  const headers = [];
  const req = {
    path: "/api/health",
    originalUrl: "/api/health"
  };
  const res = {
    setHeader(name, value) {
      headers.push([name, value]);
    },
    on(event, handler) {
      events.push([event, handler]);
    }
  };

  let nextCalled = false;
  await middleware(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, true);
  assert.equal(req.requestId, undefined);
  assert.deepEqual(headers, []);
  assert.deepEqual(events, []);
});
