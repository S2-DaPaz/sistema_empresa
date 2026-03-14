const DEFAULT_API_URL = "https://sistema-empresa-jvkb.onrender.com";

export const API_URL = (import.meta.env.VITE_API_URL || DEFAULT_API_URL).replace(/\/$/, "");

export function buildApiUrl(path) {
  const cleanPath = path.startsWith("/") ? path : `/${path}`;
  return `${API_URL}/api${cleanPath}`;
}
