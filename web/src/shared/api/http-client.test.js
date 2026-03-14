import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  apiGet,
  createClientError,
  setAuthToken,
  setUnauthorizedHandler
} from "./http-client";

describe("http client", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
    setAuthToken("");
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
});
