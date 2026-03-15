const bcrypt = require("bcryptjs");

const {
  ConflictError,
  NotFoundError
} = require("../../core/errors/app-error");
const { getUserPermissions, normalizeUser } = require("../../core/security/permissions");
const {
  findUserByEmail,
  listUsers,
  createUser,
  updateUser,
  deleteUser,
  findUserWithRoleById
} = require("./users.repository");

async function list(db) {
  const users = await listUsers(db);
  return users.map((user) => ({
    ...normalizeUser(user),
    permissions: getUserPermissions(user)
  }));
}

async function create(db, payload) {
  const exists = await findUserByEmail(db, payload.email);
  if (exists) {
    throw new ConflictError("E-mail já cadastrado.");
  }

  const password_hash = await bcrypt.hash(payload.password, 10);
  const user = await createUser(db, {
    name: payload.name,
    email: payload.email,
    role: payload.role,
    password_hash,
    permissions: Array.isArray(payload.permissions) ? payload.permissions : [],
    status: "active",
    email_verified: true,
    email_verified_at: new Date().toISOString(),
    last_login_at: null,
    password_changed_at: new Date().toISOString()
  });

  return {
    ...normalizeUser(user),
    permissions: getUserPermissions(user)
  };
}

async function update(db, userId, payload) {
  const current = await findUserWithRoleById(db, userId);
  if (!current) {
    throw new NotFoundError("Usuário não encontrado.");
  }

  const updated = await updateUser(db, userId, {
    name: payload.name,
    email: payload.email,
    role: payload.role,
    permissions: Array.isArray(payload.permissions) ? payload.permissions : [],
    status: current.status || "active",
    email_verified: current.email_verified,
    email_verified_at: current.email_verified_at,
    last_login_at: current.last_login_at,
    password_changed_at: payload.password
      ? new Date().toISOString()
      : current.password_changed_at || null,
    password_hash: payload.password ? await bcrypt.hash(payload.password, 10) : null
  });

  return {
    ...normalizeUser(updated),
    permissions: getUserPermissions(updated)
  };
}

async function remove(db, userId) {
  const current = await findUserWithRoleById(db, userId);
  if (!current) {
    throw new NotFoundError("Usuário não encontrado.");
  }

  await deleteUser(db, userId);
  return { ok: true };
}

module.exports = {
  list,
  create,
  update,
  remove
};
