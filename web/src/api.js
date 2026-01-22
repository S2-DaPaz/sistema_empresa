const API_URL = import.meta.env.VITE_API_URL || "";
let authToken = "";

export function setAuthToken(token) {
  authToken = token || "";
}

async function request(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {})
  };

  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }

  const response = await fetch(`${API_URL}/api${path}`, {
    ...options,
    headers
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: "Request failed" }));
    const err = new Error(error.error || "Request failed");
    err.status = response.status;
    throw err;
  }

  if (response.status === 204) return null;
  return response.json();
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
