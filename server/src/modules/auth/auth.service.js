const bcrypt = require("bcryptjs");

const {
  ConflictError,
  UnauthorizedError
} = require("../../core/errors/app-error");
const { normalizeUser, getUserPermissions } = require("../../core/security/permissions");
const { signToken } = require("../../core/security/auth");
const {
  findUserByEmail,
  findUserWithRoleById,
  createUser
} = require("../users/users.repository");

async function register(db, env, payload) {
  const exists = await findUserByEmail(db, payload.email);
  if (exists) {
    throw new ConflictError("E-mail já cadastrado.");
  }

  const password_hash = await bcrypt.hash(payload.password, 10);
  const user = await createUser(db, {
    name: payload.name,
    email: payload.email,
    role: "visitante",
    password_hash,
    permissions: []
  });

  return buildAuthPayload(user, env);
}

async function login(db, env, payload) {
  const rawUser = await findUserByEmail(db, payload.email);
  if (!rawUser || !rawUser.password_hash) {
    throw new UnauthorizedError("Credenciais inválidas.");
  }

  const validPassword = await bcrypt.compare(payload.password, rawUser.password_hash);
  if (!validPassword) {
    throw new UnauthorizedError("Credenciais inválidas.");
  }

  const user = await findUserWithRoleById(db, rawUser.id);
  return buildAuthPayload(user, env);
}

function buildAuthPayload(user, env) {
  return {
    token: signToken(user, env),
    user: {
      ...normalizeUser(user),
      permissions: getUserPermissions(user)
    }
  };
}

module.exports = {
  register,
  login,
  buildAuthPayload
};
