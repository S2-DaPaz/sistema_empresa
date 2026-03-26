const crypto = require("crypto");

const { AppError } = require("../../core/errors/app-error");
const repository = require("./monitoring.repository");

const SENSITIVE_KEYS = [
  "password",
  "password_hash",
  "token",
  "authorization",
  "cookie",
  "secret",
  "signature"
];

const RESOURCE_NAMES = {
  auth: "auth",
  clients: "client",
  products: "product",
  tasks: "task",
  reports: "report",
  budgets: "budget",
  users: "user",
  roles: "role",
  equipments: "equipment",
  "task-types": "task_type",
  "report-templates": "report_template"
};

const RESOURCE_LABELS = {
  auth: "autenticação",
  client: "cliente",
  product: "produto",
  task: "tarefa",
  report: "relatório",
  budget: "orçamento",
  user: "usuário",
  role: "perfil",
  equipment: "equipamento",
  task_type: "tipo de tarefa",
  report_template: "modelo de relatório",
  error_log: "log de erro",
  session: "sessão"
};

function createMonitoringService({ env, logger }) {
  function nowIso() {
    return new Date().toISOString();
  }

  function createRequestId() {
    if (crypto.randomUUID) {
      return crypto.randomUUID();
    }
    return `req_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  }

  function isSensitiveKey(key) {
    const normalized = String(key || "").toLowerCase();
    return SENSITIVE_KEYS.some((entry) => normalized.includes(entry));
  }

  function sanitizeValue(value, parentKey = "") {
    if (value === undefined) return undefined;
    if (value === null) return null;
    if (isSensitiveKey(parentKey)) return "[redacted]";

    if (Array.isArray(value)) {
      return value.slice(0, 20).map((item) => sanitizeValue(item, parentKey));
    }

    if (typeof value === "object") {
      return Object.fromEntries(
        Object.entries(value)
          .slice(0, 50)
          .map(([key, item]) => [key, sanitizeValue(item, key)])
      );
    }

    if (typeof value === "string" && value.length > 1000) {
      return `${value.slice(0, 1000)}...`;
    }

    return value;
  }

  function getClientIp(req = {}) {
    const forwarded = req.headers?.["x-forwarded-for"];
    if (typeof forwarded === "string" && forwarded.trim()) {
      return forwarded.split(",")[0].trim();
    }
    return req.ip || req.socket?.remoteAddress || null;
  }

  function inferPlatform(req = {}, explicitPlatform = null) {
    const header = String(req.headers?.["x-client-platform"] || explicitPlatform || "").trim();
    if (header) return header.toLowerCase();

    const userAgent = String(req.headers?.["user-agent"] || "").toLowerCase();
    if (userAgent.includes("flutter")) return "mobile";
    if (String(req.originalUrl || req.path || "").startsWith("/public/")) return "public";
    return "backend";
  }

  function normalizeModule(value) {
    return String(value || "")
      .replace(/^https?:\/\/[^/]+/i, "")
      .replace(/^\/api\//, "")
      .split("/")[0]
      .toLowerCase() || "system";
  }

  function splitApiPath(pathname = "") {
      return String(pathname)
      .replace(/^https?:\/\/[^/]+/i, "")
      .replace(/\?.*$/g, "")
      .replace(/^\/api\/?/, "")
      .split("/")
      .filter(Boolean);
  }

  function getResourceLabel(resource) {
    return RESOURCE_LABELS[resource] || String(resource || "registro").replace(/_/g, " ");
  }

  function buildFriendlyMessage(req, error) {
    const statusCode = Number(error?.statusCode || 500);
    const code = String(error?.code || "internal_error");

    if (code === "invalid_credentials") {
      return {
        code,
        category: "authentication_error",
        severity: "warning",
        message: "Não foi possível autenticar com os dados informados."
      };
    }

    if (code === "email_verification_required") {
      return {
        code,
        category: "authentication_error",
        severity: "warning",
        message:
          error.message || "Sua conta ainda não foi verificada. Informe o código enviado por e-mail."
      };
    }

    if (
      [
        "auth_code_invalid",
        "auth_code_expired",
        "auth_code_attempts_exceeded",
        "password_reset_invalid",
        "email_already_verified"
      ].includes(code)
    ) {
      return {
        code,
        category: "operation_invalid",
        severity: "warning",
        message: error.message || "Não foi possível validar o código informado."
      };
    }

    if (code === "rate_limited") {
      return {
        code,
        category: "operation_invalid",
        severity: "warning",
        message:
          error.message || "Muitas tentativas em pouco tempo. Aguarde alguns instantes e tente novamente."
      };
    }

    if (code === "email_delivery_failed") {
      return {
        code,
        category: "server_error",
        severity: "error",
        message:
          error.message || "Não foi possível enviar o código por e-mail no momento."
      };
    }

    if (statusCode >= 500) {
      return {
        code,
        category: "server_error",
        severity: "error",
        message: "Algo deu errado. Tente novamente em instantes."
      };
    }

    if (code === "unauthorized") {
      if (req.path === "/api/auth/login" || req.originalUrl === "/api/auth/login") {
        return {
          code,
          category: "authentication_error",
          severity: "warning",
          message: "Não foi possível autenticar com os dados informados."
        };
      }
      return {
        code,
        category: "authentication_error",
        severity: "warning",
        message: "Sua sessão expirou. Faça login novamente para continuar."
      };
    }

    if (code === "forbidden") {
      return {
        code,
        category: "permission_error",
        severity: "warning",
        message: "Você não tem permissão para realizar esta ação."
      };
    }

    if (code === "validation_error") {
      return {
        code,
        category: "validation_error",
        severity: "warning",
        message: error.message || "Revise os dados informados e tente novamente."
      };
    }

    if (code === "not_found" || code === "route_not_found") {
      return {
        code,
        category: "not_found",
        severity: "warning",
        message: "Não foi possível encontrar as informações solicitadas."
      };
    }

    if (code === "conflict") {
      return {
        code,
        category: "operation_invalid",
        severity: "warning",
        message: error.message || "Não foi possível concluir a operação no momento."
      };
    }

    if (statusCode === 400) {
      return {
        code,
        category: "operation_invalid",
        severity: "warning",
        message: error.message || "Não foi possível concluir a operação no momento."
      };
    }

    return {
      code,
      category: "unexpected_error",
      severity: "error",
      message: "Algo deu errado. Tente novamente em instantes."
    };
  }

  function buildErrorLogEntry(req, error, payload = {}) {
    const publicError = buildFriendlyMessage(req, error);
    const rawPayload =
      payload.payloadSummary === undefined ? req.body : payload.payloadSummary;

    return {
      created_at: nowIso(),
      severity: String(payload.severity || publicError.severity || "error").toLowerCase(),
      category: payload.category || publicError.category,
      error_code: String(error?.code || payload.errorCode || "internal_error"),
      friendly_message: payload.friendlyMessage || publicError.message,
      technical_message: String(error?.message || payload.technicalMessage || "Unknown error"),
      stack_trace: error?.stack || payload.stackTrace || null,
      http_status: payload.httpStatus || error?.statusCode || null,
      http_method: payload.httpMethod || req.method || null,
      endpoint: payload.endpoint || req.originalUrl || req.path || null,
      module: normalizeModule(payload.module || req.originalUrl || req.path),
      platform: inferPlatform(req, payload.platform),
      screen_route: payload.screenRoute || null,
      operation: payload.operation || null,
      request_id: req.requestId || null,
      environment: env.nodeEnv || process.env.NODE_ENV || "development",
      user_id: req.user?.id || payload.userId || null,
      user_name: req.user?.name || payload.userName || null,
      user_email: req.user?.email || payload.userEmail || null,
      context_json: sanitizeValue({
        ...(payload.context || {}),
        route: req.path || null,
        params: req.params || {},
        query: req.query || {}
      }),
      payload_json: sanitizeValue(rawPayload)
    };
  }

  async function recordError(db, req, error, payload = {}) {
    try {
      return await repository.insertErrorLog(db, buildErrorLogEntry(req, error, payload));
    } catch (logError) {
      logger.error("error_log_failed", {
        requestId: req.requestId,
        message: logError.message,
        originalError: String(error?.message || "unknown")
      });
      return null;
    }
  }

  async function recordClientError(db, req, payload = {}) {
    const clientError = new Error(String(payload.technicalMessage || "Client error"));
    if (payload.stackTrace) {
      clientError.stack = payload.stackTrace;
    }

    return recordError(db, req, clientError, {
      severity: payload.severity || "error",
      category: payload.category || "unexpected_error",
      errorCode: payload.errorCode || "client_error",
      friendlyMessage: payload.friendlyMessage || "Não foi possível concluir a operação no momento.",
      httpStatus: payload.httpStatus || null,
      httpMethod: payload.httpMethod || null,
      endpoint: payload.endpoint || null,
      module: payload.module || null,
      platform: payload.platform || "web",
      screenRoute: payload.screenRoute || null,
      operation: payload.operation || null,
      userId: payload.userId || null,
      userName: payload.userName || null,
      userEmail: payload.userEmail || null,
      context: payload.context || {},
      payloadSummary: payload.payloadSummary || null
    });
  }

  function getActor(req, res) {
    if (req.user) return req.user;
    const userFromResponse = res.locals?.responseData?.user;
    if (userFromResponse && typeof userFromResponse === "object") {
      return userFromResponse;
    }
    return null;
  }

  function buildAuditAction(req, res) {
    const segments = splitApiPath(req.originalUrl || req.path || "");
    if (!segments.length) return null;

    const method = String(req.method || "GET").toUpperCase();
    const statusCode = Number(res.statusCode || 0);
    const outcome = statusCode >= 200 && statusCode < 400 ? "success" : "failure";

    if (segments[0] === "admin") {
      if (method === "POST" && segments[1] === "error-logs" && segments[3] === "resolve") {
        return {
          action: "ERROR_LOG_RESOLVED",
          description: "Status de resolução do log de erro atualizado.",
          module: "monitoring",
          entityType: "error_log",
          entityId: segments[2] || null
        };
      }
      return null;
    }

    const resource = segments[0];

    if (resource === "auth") {
      if (method === "POST" && segments[1] === "login") {
        return {
          action: outcome === "success" ? "AUTH_LOGIN_SUCCESS" : "AUTH_LOGIN_FAILURE",
          description:
            outcome === "success" ? "Login realizado com sucesso." : "Falha de autenticação.",
          module: "auth",
          entityType: "session",
          entityId: res.locals?.responseData?.user?.id || null
        };
      }

      if (method === "POST" && segments[1] === "register") {
        return {
          action: outcome === "success" ? "AUTH_REGISTER_SUCCESS" : "AUTH_REGISTER_FAILURE",
          description:
            outcome === "success"
              ? "Cadastro realizado com sucesso."
              : "Falha ao registrar um novo usuário.",
          module: "auth",
          entityType: "user",
          entityId: res.locals?.responseData?.account?.id || res.locals?.responseData?.user?.id || null
        };
      }

      if (method === "POST" && segments[1] === "refresh") {
        return {
          action:
            outcome === "success" ? "AUTH_REFRESH_TOKEN_ROTATED" : "AUTH_REFRESH_TOKEN_FAILURE",
          description:
            outcome === "success"
              ? "Sessão renovada com sucesso."
              : "Falha ao renovar a sessão.",
          module: "auth",
          entityType: "session",
          entityId: res.locals?.responseData?.session?.id || null
        };
      }

      if (method === "POST" && segments[1] === "logout") {
        return {
          action: "AUTH_LOGOUT",
          description: "Sessão encerrada.",
          module: "auth",
          entityType: "session",
          entityId: req.auth?.sessionId || null
        };
      }

      if (method === "POST" && segments[1] === "logout-all") {
        return {
          action: "AUTH_LOGOUT_ALL",
          description: "Todas as sessões do usuário foram encerradas.",
          module: "auth",
          entityType: "session",
          entityId: req.auth?.sessionId || null
        };
      }

      if (method === "POST" && segments[1] === "email" && segments[2] === "verify") {
        return {
          action:
            outcome === "success"
              ? "AUTH_EMAIL_VERIFIED"
              : "AUTH_EMAIL_VERIFICATION_FAILED",
          description:
            outcome === "success"
              ? "Endereço de e-mail confirmado."
              : "Falha ao confirmar o endereço de e-mail.",
          module: "auth",
          entityType: "user",
          entityId: res.locals?.responseData?.user?.id || null
        };
      }

      if (method === "POST" && segments[1] === "email" && segments[2] === "resend-code") {
        return {
          action:
            outcome === "success"
              ? "AUTH_EMAIL_VERIFICATION_RESENT"
              : "AUTH_EMAIL_VERIFICATION_RESEND_FAILED",
          description:
            outcome === "success"
              ? "Novo código de verificação enviado."
              : "Falha ao reenviar o código de verificação.",
          module: "auth",
          entityType: "user",
          entityId: null
        };
      }

      if (method === "POST" && segments[1] === "password" && segments[2] === "forgot") {
        return {
          action:
            outcome === "success"
              ? "AUTH_PASSWORD_RESET_REQUESTED"
              : "AUTH_PASSWORD_RESET_REQUEST_FAILED",
          description:
            outcome === "success"
              ? "Solicitação de redefinição de senha registrada."
              : "Falha ao solicitar a redefinição de senha.",
          module: "auth",
          entityType: "user",
          entityId: null
        };
      }

      if (method === "POST" && segments[1] === "password" && segments[2] === "verify-code") {
        return {
          action:
            outcome === "success"
              ? "AUTH_PASSWORD_RESET_CODE_VERIFIED"
              : "AUTH_PASSWORD_RESET_CODE_FAILED",
          description:
            outcome === "success"
              ? "Código de redefinição de senha validado."
              : "Falha ao validar o código de redefinição de senha.",
          module: "auth",
          entityType: "user",
          entityId: null
        };
      }

      if (method === "POST" && segments[1] === "password" && segments[2] === "reset") {
        return {
          action:
            outcome === "success"
              ? "AUTH_PASSWORD_RESET_SUCCESS"
              : "AUTH_PASSWORD_RESET_FAILURE",
          description:
            outcome === "success"
              ? "Senha redefinida com sucesso."
              : "Falha ao redefinir a senha.",
          module: "auth",
          entityType: "user",
          entityId: null
        };
      }

      return null;
    }

    if (method === "GET" && segments[2] === "pdf") {
      const entityName = RESOURCE_NAMES[resource] || resource;
      return {
        action: `${entityName.toUpperCase()}_PDF_EXPORTED`,
        description: `Documento em PDF de ${getResourceLabel(entityName)} gerado.`,
        module: resource,
        entityType: entityName,
        entityId: segments[1] || null
      };
    }

    if (method === "POST" && segments[2] === "public-link") {
      const entityName = RESOURCE_NAMES[resource] || resource;
      return {
        action: `${entityName.toUpperCase()}_PUBLIC_LINK_CREATED`,
        description: `Link público de ${getResourceLabel(entityName)} gerado.`,
        module: resource,
        entityType: entityName,
        entityId: segments[1] || null
      };
    }

    if (resource === "tasks" && method === "POST" && segments[2] === "equipments") {
      return {
        action: "TASK_EQUIPMENT_ATTACHED",
        description: "Equipamento vinculado à tarefa.",
        module: "tasks",
        entityType: "task",
        entityId: segments[1] || null
      };
    }

    if (resource === "tasks" && method === "DELETE" && segments[2] === "equipments") {
      return {
        action: "TASK_EQUIPMENT_DETACHED",
        description: "Equipamento removido da tarefa.",
        module: "tasks",
        entityType: "task",
        entityId: segments[1] || null
      };
    }

    if (!["POST", "PUT", "DELETE"].includes(method)) {
      return null;
    }

    const entityName = RESOURCE_NAMES[resource];
    if (!entityName) return null;

    const suffix =
      method === "POST" ? "CREATED" : method === "PUT" ? "UPDATED" : "DELETED";

    return {
      action: `${entityName.toUpperCase()}_${suffix}`,
      description:
        method === "POST"
          ? `Cadastro de ${getResourceLabel(entityName)} realizado.`
          : method === "PUT"
            ? `Atualização de ${getResourceLabel(entityName)} realizada.`
            : `Remoção de ${getResourceLabel(entityName)} realizada.`,
      module: resource,
      entityType: entityName,
      entityId: segments[1] || res.locals?.responseData?.id || null
    };
  }

  async function recordEvent(db, payload) {
    try {
      return await repository.insertEventLog(db, {
        created_at: nowIso(),
        action: payload.action,
        description: payload.description,
        module: normalizeModule(payload.module),
        entity_type: payload.entityType || null,
        entity_id: payload.entityId ? String(payload.entityId) : null,
        outcome: String(payload.outcome || "success").toLowerCase(),
        platform: inferPlatform(payload.req || {}, payload.platform || null),
        ip_address: payload.ipAddress || getClientIp(payload.req || {}),
        route_path: payload.routePath || payload.req?.originalUrl || null,
        http_method: payload.httpMethod || payload.req?.method || null,
        request_id: payload.requestId || payload.req?.requestId || null,
        user_id: payload.user?.id || null,
        user_name: payload.user?.name || null,
        user_email: payload.user?.email || null,
        user_role: payload.user?.role_name || payload.user?.role || null,
        metadata_json: sanitizeValue(payload.metadata || {}),
        before_json: sanitizeValue(payload.before || null),
        after_json: sanitizeValue(payload.after || null)
      });
    } catch (error) {
      logger.error("event_log_failed", {
        action: payload.action,
        message: error.message
      });
      return null;
    }
  }

  async function captureRequestAudit(db, req, res) {
    const originalUrl = String(req.originalUrl || req.path || "");
    if (!originalUrl.startsWith("/api/")) return null;
    if (originalUrl === "/api/health") return null;
    if (originalUrl.startsWith("/api/monitoring/client-errors")) return null;

    const auditAction = buildAuditAction(req, res);
    if (!auditAction) return null;

    const apiSegments = splitApiPath(originalUrl);
    const isLoginAttempt = apiSegments[0] === "auth" && apiSegments[1] === "login";

    return recordEvent(db, {
      ...auditAction,
      outcome: res.statusCode >= 200 && res.statusCode < 400 ? "success" : "failure",
      req,
      user: getActor(req, res),
      metadata: {
        statusCode: res.statusCode,
        query: sanitizeValue(req.query),
        payload: sanitizeValue(req.body),
        response: sanitizeValue(res.locals?.responseData),
        attemptedEmail: isLoginAttempt ? String(req.body?.email || "") || null : null
      },
      after: sanitizeValue(res.locals?.responseData)
    });
  }

  function createRequestTrackingMiddleware(db) {
    return (req, res, next) => {
      const requestPath = String(req.path || req.originalUrl || "").split("?")[0];
      if (requestPath === "/api/health") {
        return next();
      }

      req.requestId = createRequestId();
      res.setHeader("X-Request-Id", req.requestId);

      res.on("finish", () => {
        captureRequestAudit(db, req, res).catch((error) => {
          logger.error("request_audit_failed", {
            requestId: req.requestId,
            path: req.originalUrl,
            message: error.message
          });
        });
      });

      next();
    };
  }

  async function listErrorLogs(db, query) {
    return repository.listErrorLogs(db, query);
  }

  async function listEventLogs(db, query) {
    return repository.listEventLogs(db, query);
  }

  async function getErrorLog(db, id) {
    return repository.findErrorLogById(db, id);
  }

  async function getEventLog(db, id) {
    return repository.findEventLogById(db, id);
  }

  async function resolveErrorLog(db, id, payload, user) {
    return repository.resolveErrorLog(db, id, {
      resolved_at: payload.resolved_at || nowIso(),
      resolved_by_user_id: user?.id || null,
      resolution_note: payload.resolution_note || null
    });
  }

  function buildErrorResponse(req, error) {
    const friendly = buildFriendlyMessage(req, error);
    const details =
      error instanceof AppError && error.exposeDetails ? sanitizeValue(error.details) : undefined;

    if (error instanceof AppError) {
      return {
        statusCode: error.statusCode,
        payload: {
          error: {
            code: error.code,
            category: friendly.category,
            message: friendly.message,
            details,
            requestId: req.requestId
          }
        }
      };
    }

    return {
      statusCode: 500,
      payload: {
        error: {
          code: "internal_error",
          category: "server_error",
          message: "Algo deu errado. Tente novamente em instantes.",
          requestId: req.requestId
        }
      }
    };
  }

  return {
    buildErrorResponse,
    buildFriendlyMessage,
    recordError,
    recordEvent,
    recordClientError,
    createRequestTrackingMiddleware,
    listErrorLogs,
    listEventLogs,
    getErrorLog,
    getEventLog,
    resolveErrorLog,
    sanitizeValue
  };
}

module.exports = { createMonitoringService };
