const CATEGORY_MESSAGES = {
  connection_error: "Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.",
  server_error: "Algo deu errado. Tente novamente em instantes.",
  authentication_error: "Sua sessão expirou. Faça login novamente para continuar.",
  permission_error: "Você não tem permissão para realizar esta ação.",
  validation_error: "Revise os dados informados e tente novamente.",
  not_found: "Não foi possível encontrar as informações solicitadas.",
  operation_invalid: "Não foi possível concluir a operação no momento.",
  unexpected_error: "Não foi possível concluir a operação no momento."
};

const TECHNICAL_MESSAGE_PATTERN =
  /(socketexception|network ?error|econn|internal server error|failed to fetch|typeerror|clientexception|timeout|timed out|xmlhttprequest|unhandled exception|axioserror)/i;

export class AppRequestError extends Error {
  constructor({
    message,
    category = "unexpected_error",
    code = "unexpected_error",
    status = 0,
    requestId = null,
    details = null,
    technicalMessage = "",
    retryable = false
  }) {
    super(message);
    this.name = "AppRequestError";
    this.category = category;
    this.code = code;
    this.status = status;
    this.requestId = requestId;
    this.details = details;
    this.technicalMessage = technicalMessage;
    this.retryable = retryable;
  }
}

function looksTechnical(message) {
  return TECHNICAL_MESSAGE_PATTERN.test(String(message || ""));
}

function getCategoryMessage(category, fallbackMessage) {
  return fallbackMessage || CATEGORY_MESSAGES[category] || CATEGORY_MESSAGES.unexpected_error;
}

function inferCategoryFromStatus(status) {
  if (!status) return "connection_error";
  if (status === 401) return "authentication_error";
  if (status === 403) return "permission_error";
  if (status === 404) return "not_found";
  if (status === 429) return "operation_invalid";
  if (status === 400 || status === 409 || status === 422) return "operation_invalid";
  if (status >= 500) return "server_error";
  return "unexpected_error";
}

export function normalizeError(error, fallbackMessage) {
  if (error instanceof AppRequestError) {
    return error;
  }

  const message = String(error?.message || "").trim();
  const status = Number(error?.status || error?.statusCode || 0);
  const category = error?.category || inferCategoryFromStatus(status);
  const safeMessage =
    message && !looksTechnical(message)
      ? message
      : getCategoryMessage(category, fallbackMessage);

  return new AppRequestError({
    message: safeMessage,
    category,
    code: error?.code || "unexpected_error",
    status,
    requestId: error?.requestId || null,
    details: error?.details ?? null,
    technicalMessage: message || String(error || ""),
    retryable: category === "connection_error" || category === "server_error"
  });
}

export function normalizeApiError({ payload, status, fallbackMessage, technicalMessage }) {
  const apiError = payload?.error || {};
  const category = apiError.category || inferCategoryFromStatus(status);
  const rawMessage = String(apiError.message || technicalMessage || "").trim();
  const safeMessage =
    rawMessage && !looksTechnical(rawMessage)
      ? rawMessage
      : getCategoryMessage(category, fallbackMessage);

  return new AppRequestError({
    message: safeMessage,
    category,
    code: apiError.code || "request_failed",
    status,
    requestId: apiError.requestId || null,
    details: apiError.details ?? null,
    technicalMessage: rawMessage || `HTTP ${status}`,
    retryable: category === "connection_error" || category === "server_error"
  });
}

export function normalizeNetworkError(error, fallbackMessage) {
  return new AppRequestError({
    message: getCategoryMessage("connection_error", fallbackMessage),
    category: "connection_error",
    code: "network_error",
    status: 0,
    technicalMessage: String(error?.message || error || "Network error"),
    retryable: true
  });
}

export function getFriendlyErrorMessage(error, fallbackMessage) {
  return normalizeError(error, fallbackMessage).message;
}
