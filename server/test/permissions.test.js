const test = require("node:test");
const assert = require("node:assert/strict");

const {
  getUserPermissions,
  hasPermission
} = require("../src/core/security/permissions");
const { PERMISSIONS } = require("../src/config/contracts");

test("falls back to role defaults when role permissions are null", () => {
  const permissions = getUserPermissions({
    role: "tecnico",
    role_permissions: null,
    permissions: null,
    role_is_admin: false
  });

  assert.ok(permissions.includes(PERMISSIONS.VIEW_TASKS));
  assert.ok(permissions.includes(PERMISSIONS.MANAGE_TASKS));
});

test("prefers explicit user permissions when provided", () => {
  const permissions = getUserPermissions({
    role: "visitante",
    role_permissions: [],
    permissions: [PERMISSIONS.VIEW_USERS],
    role_is_admin: false
  });

  assert.deepEqual(permissions, [PERMISSIONS.VIEW_USERS]);
});

test("manage permission satisfies related view permission", () => {
  const user = {
    role: "visitante",
    role_permissions: [PERMISSIONS.MANAGE_CLIENTS],
    permissions: [],
    role_is_admin: false
  };

  assert.equal(hasPermission(user, PERMISSIONS.VIEW_CLIENTS), true);
});
