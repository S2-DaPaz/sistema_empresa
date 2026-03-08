const API_URL = import.meta.env.VITE_API_URL || "";

let authToken = "";

function buildUrl(path) {
  return `${API_URL}/api${path}`;
}

function extractErrorMessage(payload, fallback) {
  if (payload?.error?.message) return payload.error.message;
  if (payload?.error) return payload.error;
  return fallback;
}

async function request(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {})
  };

  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }

  const response = await fetch(buildUrl(path), {
    ...options,
    headers
  });

  if (response.status === 204) {
    return null;
  }

  const payload = await response
    .json()
    .catch(() => ({ error: { message: "Request failed" } }));

  if (!response.ok) {
    const error = new Error(extractErrorMessage(payload, "Request failed"));
    error.status = response.status;
    error.payload = payload;
    throw error;
  }

  if (payload && Object.prototype.hasOwnProperty.call(payload, "data")) {
    return payload.data;
  }

  return payload;
}

export function setAuthToken(token) {
  authToken = token || "";
}

export function apiGet(path) {
  return request(path);
}

export function apiPost(path, body) {
  return request(path, {
    method: "POST",
    body: JSON.stringify(body)
  });
}

export function apiPut(path, body) {
  return request(path, {
    method: "PUT",
    body: JSON.stringify(body)
  });
}

export function apiDelete(path) {
  return request(path, {
    method: "DELETE"
  });
}
