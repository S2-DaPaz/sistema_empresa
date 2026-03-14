const jwt = require("jsonwebtoken");

const {
  ForbiddenError,
  UnauthorizedError
} = require("../errors/app-error");
const {
  getUserPermissions,
  hasPermission,
  normalizeUser
} = require("./permissions");

function signToken(user, env) {
  return jwt.sign({ id: user.id }, env.jwtSecret, { expiresIn: env.jwtTtl });
}

function createAuthMiddleware({ db, env, findUserWithRoleById }) {
  return async (req, res, next) => {
    if (req.method === "OPTIONS") return next();
    if (req.path === "/health" || req.path === "/auth/login" || req.path === "/auth/register") {
      return next();
    }
    if (req.path.startsWith("/public/")) {
      return next();
    }

    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;

    if (!token) {
      return next(new UnauthorizedError("Não autorizado."));
    }

    try {
      const payload = jwt.verify(token, env.jwtSecret);
      const user = await findUserWithRoleById(db, payload.id);
      if (!user) {
        return next(new UnauthorizedError("Usuário não encontrado."));
      }

      req.user = { ...normalizeUser(user), permissions: getUserPermissions(user) };
      return next();
    } catch (error) {
      return next(new UnauthorizedError("Token inválido."));
    }
  };
}

function requirePermission(permission) {
  return (req, res, next) => {
    if (!req.user || !hasPermission(req.user, permission)) {
      return next(new ForbiddenError("Sem permissão."));
    }
    return next();
  };
}

function requireAdmin(req, res, next) {
  if (!req.user || !req.user.role_is_admin) {
    return next(new ForbiddenError("Acesso restrito ao administrador."));
  }
  return next();
}

module.exports = {
  signToken,
  createAuthMiddleware,
  requirePermission,
  requireAdmin
};
