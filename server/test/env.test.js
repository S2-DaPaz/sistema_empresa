const test = require("node:test");
const assert = require("node:assert/strict");

function loadEnvModule() {
  const target = require.resolve("../src/config/env");
  delete require.cache[target];
  return require("../src/config/env");
}

test("generates a stable development JWT secret when not configured", () => {
  const originalJwtSecret = process.env.JWT_SECRET;
  const originalNodeEnv = process.env.NODE_ENV;

  delete process.env.JWT_SECRET;
  process.env.NODE_ENV = "development";

  const { getEnv } = loadEnvModule();
  const first = getEnv();
  const second = getEnv();

  assert.ok(first.jwtSecret);
  assert.equal(first.jwtSecret, second.jwtSecret);

  process.env.JWT_SECRET = originalJwtSecret;
  process.env.NODE_ENV = originalNodeEnv;
});

test("requires JWT secret in production", () => {
  const originalJwtSecret = process.env.JWT_SECRET;
  const originalNodeEnv = process.env.NODE_ENV;

  delete process.env.JWT_SECRET;
  process.env.NODE_ENV = "production";

  const { getEnv } = loadEnvModule();
  assert.throws(() => getEnv(), /JWT_SECRET is required in production/);

  process.env.JWT_SECRET = originalJwtSecret;
  process.env.NODE_ENV = originalNodeEnv;
});
