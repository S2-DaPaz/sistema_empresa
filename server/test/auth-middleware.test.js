const test = require("node:test");
const assert = require("node:assert/strict");

const {
  createAuthMiddleware,
  signToken
} = require("../src/core/security/auth");
const { PERMISSIONS } = require("../src/config/contracts");

test("auth middleware populates request user with normalized permissions", async () => {
  const env = { jwtSecret: "test-secret", jwtTtl: "1h" };
  const token = signToken({ id: 42 }, env);
  const middleware = createAuthMiddleware({
    db: {},
    env,
    findUserWithRoleById: async (_db, id) => ({
      id,
      name: "Tecnico",
      email: "tecnico@local",
      role: "tecnico",
      role_name: "Tecnico",
      role_permissions: null,
      permissions: null,
      role_is_admin: false
    })
  });

  const req = {
    method: "GET",
    path: "/tasks",
    headers: { authorization: `Bearer ${token}` }
  };

  await new Promise((resolve, reject) => {
    middleware(req, {}, (error) => (error ? reject(error) : resolve()));
  });

  assert.equal(req.user.id, 42);
  assert.ok(req.user.permissions.includes(PERMISSIONS.MANAGE_TASKS));
});
