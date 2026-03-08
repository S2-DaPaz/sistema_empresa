const { RESERVED_ROLE_KEYS } = require("../../config/contracts");
const {
  ConflictError,
  NotFoundError,
  ValidationError
} = require("../../core/errors/app-error");
const { normalizeRole, slugifyRoleKey } = require("../../core/security/permissions");
const {
  listRoles,
  findRoleById,
  findRoleByKey,
  createRole,
  updateRole,
  deleteRole
} = require("./roles.repository");

async function list(db) {
  const roles = await listRoles(db);
  return roles.map(normalizeRole);
}

async function create(db, payload) {
  const name = String(payload.name || "").trim();
  const key = slugifyRoleKey(payload.key || name);
  if (!name || !key) {
    throw new ValidationError("Nome e codigo da funcao sao obrigatorios.");
  }

  const existing = await findRoleByKey(db, key);
  if (existing) {
    throw new ConflictError("Ja existe uma funcao com este codigo.");
  }

  const role = await createRole(db, {
    key,
    name,
    permissions: Array.isArray(payload.permissions) ? payload.permissions : [],
    is_admin: Boolean(payload.is_admin)
  });

  return normalizeRole(role);
}

async function update(db, roleId, payload) {
  const role = await findRoleById(db, roleId);
  if (!role) {
    throw new NotFoundError("Funcao nao encontrada.");
  }

  const updated = await updateRole(db, roleId, {
    name: payload.name || role.key,
    permissions: Array.isArray(payload.permissions) ? payload.permissions : [],
    is_admin: Boolean(payload.is_admin)
  });

  return normalizeRole(updated);
}

async function remove(db, roleId) {
  const role = await findRoleById(db, roleId);
  if (!role) {
    throw new NotFoundError("Funcao nao encontrada.");
  }

  if (RESERVED_ROLE_KEYS.includes(role.key)) {
    throw new ValidationError("Funcoes padrao nao podem ser removidas.");
  }

  await deleteRole(db, roleId);
  return { ok: true };
}

module.exports = {
  list,
  create,
  update,
  remove
};
