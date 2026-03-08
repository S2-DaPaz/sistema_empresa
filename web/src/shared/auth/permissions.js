import { ALL_PERMISSIONS, ROLE_DEFAULTS } from "../contracts/permissions";

export function parsePermissions(value) {
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

export function getUserPermissions(user) {
  if (!user) return [];
  if (user.role_is_admin || user.role === "administracao") return ALL_PERMISSIONS;

  const explicitPermissions = parsePermissions(user.permissions);
  if (explicitPermissions.length) {
    return Array.from(new Set(explicitPermissions));
  }

  const rolePermissions = parsePermissions(user.role_permissions);
  const base = rolePermissions.length
    ? rolePermissions
    : ROLE_DEFAULTS[user.role] || ROLE_DEFAULTS.visitante;
  return Array.from(new Set(base));
}

export function hasPermissionFor(user, permission) {
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
