const path = require("path");

const permissionsConfig = require(path.join(
  __dirname,
  "..",
  "..",
  "..",
  "packages",
  "contracts",
  "permissions.json"
));
const domainOptions = require(path.join(
  __dirname,
  "..",
  "..",
  "..",
  "packages",
  "contracts",
  "domain-options.json"
));

const PERMISSIONS = permissionsConfig.permissions;
const ALL_PERMISSIONS = Object.values(PERMISSIONS);

module.exports = {
  PERMISSIONS,
  ALL_PERMISSIONS,
  ROLE_DEFAULTS: permissionsConfig.roleDefaults,
  RESERVED_ROLE_KEYS: permissionsConfig.reservedRoleKeys,
  DOMAIN_OPTIONS: domainOptions
};
