import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { apiGet, setAuthToken } from "./http-client";

describe("http client", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
    setAuthToken("");
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("unwraps the backend data envelope and sends auth header", async () => {
    setAuthToken("token-123");
    global.fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: { ok: true } })
    });

    const payload = await apiGet("/health");

    expect(payload).toEqual({ ok: true });
    expect(global.fetch).toHaveBeenCalledWith(
      "/api/health",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer token-123"
        })
      })
    );
  });

  it("surfaces nested API error messages", async () => {
    global.fetch.mockResolvedValue({
      ok: false,
      status: 403,
      json: async () => ({ error: { message: "Sem permissao." } })
    });

    await expect(apiGet("/users")).rejects.toThrow("Sem permissao.");
  });
});
