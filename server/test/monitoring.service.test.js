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
    new UnauthorizedError("Token invalido.")
  );

  assert.equal(response.statusCode, 401);
  assert.deepEqual(response.payload, {
    error: {
      code: "unauthorized",
      category: "authentication_error",
      message: "Nao foi possivel autenticar com os dados informados.",
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
