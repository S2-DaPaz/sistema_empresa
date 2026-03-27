const jwt = require("jsonwebtoken");

const {
  findSessionById,
  touchSessionActivity
} = require("../../modules/auth/auth.repository");
const {
  getClientIp,
  getClientPlatform,
  getDeviceInfo
} = require("../../modules/auth/auth.helpers");
const { ForbiddenError, UnauthorizedError } = require("../errors/app-error");
const { getUserPermissions, hasPermission, normalizeUser } = require("./permissions");

const PUBLIC_PATHS = new Set([
  "/health",
  "/auth/login",
  "/auth/register",
  "/auth/refresh",
  "/auth/email/verify",
  "/auth/email/resend-code",
  "/auth/password/forgot",
  "/auth/password/verify-code",
  "/auth/password/reset",
  "/backups/webhook"
]);

function signToken(user, env, session = null) {
  const payload = {
    id: user.id,
    sub: String(user.id),
    type: "access"
  };

  if (session?.id) {
    payload.sid = session.id;
  }

  return jwt.sign(payload, env.jwtSecret, {
    expiresIn: env.accessTokenTtl || env.jwtTtl
  });
}

function createAuthMiddleware({ db, env, findUserWithRoleById }) {
  return async (req, res, next) => {
    if (req.method === "OPTIONS") return next();
    if (PUBLIC_PATHS.has(req.path) || req.path.startsWith("/public/")) {
      return next();
    }

    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;

    if (!token) {
      return next(new UnauthorizedError("Não autorizado."));
    }

    try {
      const payload = jwt.verify(token, env.jwtSecret);
      if (payload.type && payload.type !== "access") {
        return next(new UnauthorizedError("Token inválido."));
      }

      if (payload.sid) {
        const session = await findSessionById(db, payload.sid);
        if (!session || session.revoked_at || new Date(session.expires_at).getTime() <= Date.now()) {
          return next(
            new UnauthorizedError("Sua sessão expirou. Faça login novamente para continuar.")
          );
        }

        req.auth = {
          sessionId: session.id,
          tokenType: payload.type || "access"
        };
        await touchSessionActivity(db, session.id, {
          last_used_at: new Date().toISOString(),
          device_info: getDeviceInfo(req) || session.device_info,
          ip_address: getClientIp(req) || session.ip_address,
          platform: getClientPlatform(req) || session.platform
        });
      }

      const user = await findUserWithRoleById(db, payload.id);
      if (!user) {
        return next(new UnauthorizedError("Usuário não encontrado."));
      }

      req.user = { ...normalizeUser(user), permissions: getUserPermissions(user) };
      return next();
    } catch (_error) {
      return next(new UnauthorizedError("Token inválido."));
    }
  };
}

function requirePermission(permission) {
  return (req, _res, next) => {
    if (!req.user || !hasPermission(req.user, permission)) {
      return next(new ForbiddenError("Sem permissão."));
    }
    return next();
  };
}

function requireAdmin(req, _res, next) {
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
