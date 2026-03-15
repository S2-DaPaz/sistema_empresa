import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  apiGet,
  createClientError,
  setAuthToken,
  setRefreshHandler,
  setUnauthorizedHandler
} from "./http-client";

describe("http client", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
    setAuthToken("");
    setRefreshHandler(null);
    setUnauthorizedHandler(null);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("unwraps the backend envelope and sends auth + platform headers", async () => {
    setAuthToken("token-123");
    global.fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: { ok: true } })
    });

    const payload = await apiGet("/health");

    expect(payload).toEqual({ ok: true });
    expect(global.fetch).toHaveBeenCalledWith(
      "https://sistema-empresa-jvkb.onrender.com/api/health",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer token-123",
          "X-Client-Platform": "web"
        })
      })
    );
  });

  it("normalizes API errors into friendly request errors", async () => {
    global.fetch
      .mockResolvedValueOnce({
        ok: false,
        status: 403,
        statusText: "Forbidden",
        json: async () => ({
          error: {
            code: "forbidden",
            category: "permission_error",
            message: "Você não tem permissão para realizar esta ação."
          }
        })
      })
      .mockResolvedValueOnce({
        ok: true,
        status: 202,
        json: async () => ({ data: { ok: true } })
      });

    await expect(apiGet("/users")).rejects.toMatchObject({
      category: "permission_error",
      message: "Você não tem permissão para realizar esta ação."
    });

    expect(global.fetch).toHaveBeenNthCalledWith(
      2,
      "https://sistema-empresa-jvkb.onrender.com/api/monitoring/client-errors",
      expect.objectContaining({
        method: "POST"
      })
    );
  });

  it("maps network failures to connection-friendly messages", () => {
    const error = createClientError(new TypeError("Failed to fetch"));
    expect(error.category).toBe("connection_error");
    expect(error.message).toBe(
      "Não foi possível conectar ao servidor. Verifique sua internet e tente novamente."
    );
  });

  it("refreshes the session and retries the request after a 401", async () => {
    const refreshHandler = vi.fn().mockResolvedValue(true);
    setAuthToken("token-expirado");
    setRefreshHandler(refreshHandler);

    global.fetch
      .mockResolvedValueOnce({
        ok: false,
        status: 401,
        statusText: "Unauthorized",
        json: async () => ({
          error: {
            code: "unauthorized",
            category: "authentication_error",
            message: "Sua sessão expirou. Faça login novamente para continuar."
          }
        })
      })
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ data: { ok: true } })
      });

    const payload = await apiGet("/tasks");

    expect(payload).toEqual({ ok: true });
    expect(refreshHandler).toHaveBeenCalledTimes(1);
    expect(global.fetch).toHaveBeenCalledTimes(2);
  });
});
