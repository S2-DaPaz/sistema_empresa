const { ALL_PERMISSIONS, ROLE_DEFAULTS } = require("../../config/contracts");

function parsePermissions(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      return [];
    }
  }
  return [];
}

function getUserPermissions(user) {
  if (!user) return [];
  if (user.role_is_admin || user.role === "administracao") {
    return ALL_PERMISSIONS;
  }

  const rolePermissions = parsePermissions(user.role_permissions);
  const explicitPermissions = parsePermissions(user.permissions);
  const base = explicitPermissions.length
    ? explicitPermissions
    : rolePermissions.length
      ? rolePermissions
      : ROLE_DEFAULTS[user.role] || ROLE_DEFAULTS.visitante;

  return Array.from(new Set(base));
}

function hasPermission(user, permission) {
  if (!user) return false;
  if (user.role_is_admin || user.role === "administracao") return true;

  const permissions = new Set(getUserPermissions(user));
  if (permissions.has(permission)) return true;

  if (permission.startsWith("view_")) {
    const managePermission = permission.replace("view_", "manage_");
    return permissions.has(managePermission);
  }

  return false;
}

function normalizeUser(user) {
  if (!user) return null;

  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    status: user.status || "active",
    email_verified: Boolean(user.email_verified),
    email_verified_at: user.email_verified_at || null,
    last_login_at: user.last_login_at || null,
    role_name: user.role_name || user.role,
    role_is_admin: Boolean(user.role_is_admin),
    role_permissions: parsePermissions(user.role_permissions),
    permissions: parsePermissions(user.permissions)
  };
}

function normalizeRole(role) {
  if (!role) return null;

  return {
    id: role.id,
    key: role.key,
    name: role.name,
    permissions: parsePermissions(role.permissions),
    is_admin: Boolean(role.is_admin)
  };
}

function slugifyRoleKey(value) {
  return value
    .toString()
    .trim()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .toLowerCase();
}

module.exports = {
  parsePermissions,
  getUserPermissions,
  hasPermission,
  normalizeUser,
  normalizeRole,
  slugifyRoleKey
};
