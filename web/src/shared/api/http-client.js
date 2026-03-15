import { buildApiUrl } from "./config";
import {
  AppRequestError,
  normalizeApiError,
  normalizeError,
  normalizeNetworkError
} from "../errors/error-normalizer";

let authToken = "";
let unauthorizedHandler = null;
let refreshHandler = null;
let refreshPromise = null;

function safeParseBody(body) {
  if (!body || typeof body !== "string") return null;
  try {
    return JSON.parse(body);
  } catch (_error) {
    return body.slice(0, 1000);
  }
}

async function readPayload(response) {
  try {
    return await response.json();
  } catch (_error) {
    return null;
  }
}

function shouldAttemptRefresh(path, status, skipAuthRefresh) {
  if (skipAuthRefresh || status !== 401 || !authToken || !refreshHandler) {
    return false;
  }

  if (path === "/auth/refresh") return false;
  if (path === "/auth/login" || path === "/auth/register") return false;
  if (path.startsWith("/auth/email/") || path.startsWith("/auth/password/")) {
    return false;
  }

  return true;
}

function shouldHandleUnauthorized(path, status) {
  return status === 401 && !["/auth/login", "/auth/register", "/auth/refresh"].includes(path);
}

async function attemptRefresh() {
  if (!refreshHandler) return false;
  if (!refreshPromise) {
    refreshPromise = Promise.resolve(refreshHandler())
      .then((result) => result !== false)
      .catch(() => false)
      .finally(() => {
        refreshPromise = null;
      });
  }
  return refreshPromise;
}

function reportClientError(error, context) {
  if (context.path === "/monitoring/client-errors") {
    return;
  }

  const screenRoute =
    typeof window !== "undefined"
      ? `${window.location.pathname}${window.location.search}`
      : "unknown";

  const payload = {
    friendlyMessage: error.message,
    technicalMessage: error.technicalMessage || error.message,
    category: error.category || "unexpected_error",
    errorCode: error.code || "client_error",
    httpStatus: error.status || null,
    httpMethod: context.method,
    endpoint: buildApiUrl(context.path),
    module: context.path.replace(/^\//, "").split("/")[0] || "web",
    platform: "web",
    screenRoute,
    operation: `${context.method} ${context.path}`,
    context: {
      requestId: error.requestId || null
    },
    payloadSummary: context.payloadSummary
  };

  const headers = {
    "Content-Type": "application/json",
    "X-Client-Platform": "web"
  };

  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }

  fetch(buildApiUrl("/monitoring/client-errors"), {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
    keepalive: true
  }).catch(() => {});
}

async function request(path, options = {}) {
  const {
    withMeta = false,
    reportError = true,
    skipAuthRefresh = false,
    headers: customHeaders = {},
    ...fetchOptions
  } = options;
  const method = String(fetchOptions.method || "GET").toUpperCase();
  const headers = {
    "Content-Type": "application/json",
    "X-Client-Platform": "web",
    ...customHeaders
  };

  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }

  let response;

  try {
    response = await fetch(buildApiUrl(path), {
      ...fetchOptions,
      headers
    });
  } catch (error) {
    const normalized = normalizeNetworkError(error);
    if (reportError) {
      reportClientError(normalized, {
        method,
        path,
        payloadSummary: safeParseBody(fetchOptions.body)
      });
    }
    throw normalized;
  }

  if (!response.ok && shouldAttemptRefresh(path, response.status, skipAuthRefresh)) {
    const refreshed = await attemptRefresh();
    if (refreshed) {
      return request(path, {
        ...options,
        skipAuthRefresh: true
      });
    }
  }

  if (response.status === 204) {
    return null;
  }

  const payload = await readPayload(response);

  if (!response.ok) {
    const normalized = normalizeApiError({
      payload,
      status: response.status,
      technicalMessage:
        payload?.error?.message || response.statusText || `HTTP ${response.status}`
    });

    if (shouldHandleUnauthorized(path, response.status) && unauthorizedHandler) {
      unauthorizedHandler(normalized);
    }

    if (reportError) {
      reportClientError(normalized, {
        method,
        path,
        payloadSummary: safeParseBody(fetchOptions.body)
      });
    }

    throw normalized;
  }

  if (payload && Object.prototype.hasOwnProperty.call(payload, "data")) {
    return withMeta ? { data: payload.data, meta: payload.meta || null } : payload.data;
  }

  return payload;
}

export function setAuthToken(token) {
  authToken = token || "";
}

export function setUnauthorizedHandler(handler) {
  unauthorizedHandler = typeof handler === "function" ? handler : null;
}

export function setRefreshHandler(handler) {
  refreshHandler = typeof handler === "function" ? handler : null;
}

export function createClientError(error, fallbackMessage) {
  return normalizeError(error, fallbackMessage);
}

export function apiGet(path, options = {}) {
  return request(path, options);
}

export function apiPost(path, body, options = {}) {
  return request(path, {
    ...options,
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function apiPut(path, body, options = {}) {
  return request(path, {
    ...options,
    method: "PUT",
    body: JSON.stringify(body)
  });
}

export function apiDelete(path, options = {}) {
  return request(path, {
    ...options,
    method: "DELETE"
  });
}

export { AppRequestError };
