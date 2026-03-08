import permissionsConfig from "../../../../packages/contracts/permissions.json";

export const PERMISSIONS = permissionsConfig.permissions;
export const ROLE_DEFAULTS = permissionsConfig.roleDefaults;
export const RESERVED_ROLE_KEYS = permissionsConfig.reservedRoleKeys;
export const ALL_PERMISSIONS = Object.values(PERMISSIONS);
