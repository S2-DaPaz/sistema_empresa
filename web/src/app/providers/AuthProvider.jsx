import { createContext, useContext, useEffect, useMemo, useState } from "react";
import {
  apiGet,
  apiPost,
  setAuthToken,
  setRefreshHandler,
  setUnauthorizedHandler
} from "../../shared/api/http-client";
import { PERMISSIONS } from "../../shared/contracts/permissions";
import { getUserPermissions, hasPermissionFor } from "../../shared/auth/permissions";

const TOKEN_KEY = "rv-token";
const REFRESH_TOKEN_KEY = "rv-refresh-token";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem(TOKEN_KEY) || "");
  const [refreshToken, setRefreshToken] = useState(
    () => localStorage.getItem(REFRESH_TOKEN_KEY) || ""
  );
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  function clearSession() {
    setToken("");
    setRefreshToken("");
    setUser(null);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    setAuthToken("");
  }

  function setSession(payload) {
    setToken(payload.token);
    setRefreshToken(payload.refreshToken);
    setUser(payload.user);
    localStorage.setItem(TOKEN_KEY, payload.token);
    localStorage.setItem(REFRESH_TOKEN_KEY, payload.refreshToken);
    setAuthToken(payload.token);
  }

  async function refreshSession() {
    const activeRefreshToken = localStorage.getItem(REFRESH_TOKEN_KEY) || refreshToken;
    if (!activeRefreshToken) {
      clearSession();
      return false;
    }

    const data = await apiPost(
      "/auth/refresh",
      { refreshToken: activeRefreshToken },
      { reportError: false, skipAuthRefresh: true }
    );
    setSession(data);
    return true;
  }

  useEffect(() => {
    setUnauthorizedHandler(() => {
      clearSession();
    });
    setRefreshHandler(() => refreshSession());

    return () => {
      setUnauthorizedHandler(null);
      setRefreshHandler(null);
    };
  }, [refreshToken]);

  useEffect(() => {
    setAuthToken(token);

    let active = true;

    async function loadSession() {
      if (!token && !refreshToken) {
        if (active) {
          setUser(null);
          setLoading(false);
        }
        return;
      }

      try {
        if (!token && refreshToken) {
          await refreshSession();
        }

        const data = await apiGet("/auth/me", { reportError: false });
        if (!active) return;
        setUser(data?.user || null);
      } catch (_error) {
        if (!active) return;
        clearSession();
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    loadSession();
    return () => {
      active = false;
    };
  }, [token, refreshToken]);

  const permissions = useMemo(() => getUserPermissions(user), [user]);

  async function login(email, password) {
    const data = await apiPost("/auth/login", { email, password }, { skipAuthRefresh: true });
    setSession(data);
    return data;
  }

  async function register(name, email, password) {
    return apiPost(
      "/auth/register",
      { name, email, password },
      { skipAuthRefresh: true }
    );
  }

  async function verifyEmail(email, code) {
    const data = await apiPost(
      "/auth/email/verify",
      { email, code },
      { skipAuthRefresh: true }
    );
    setSession(data);
    return data;
  }

  async function resendVerificationCode(email) {
    return apiPost(
      "/auth/email/resend-code",
      { email },
      { skipAuthRefresh: true }
    );
  }

  async function requestPasswordReset(email) {
    return apiPost(
      "/auth/password/forgot",
      { email },
      { skipAuthRefresh: true }
    );
  }

  async function verifyPasswordResetCode(email, code) {
    return apiPost(
      "/auth/password/verify-code",
      { email, code },
      { skipAuthRefresh: true }
    );
  }

  async function resetPassword(email, code, password) {
    return apiPost(
      "/auth/password/reset",
      { email, code, password },
      { skipAuthRefresh: true }
    );
  }

  async function logout() {
    try {
      if (token) {
        await apiPost("/auth/logout", {}, { reportError: false, skipAuthRefresh: true });
      }
    } finally {
      clearSession();
    }
  }

  async function logoutAll() {
    try {
      if (token) {
        await apiPost("/auth/logout-all", {}, { reportError: false, skipAuthRefresh: true });
      }
    } finally {
      clearSession();
    }
  }

  const value = {
    user,
    token,
    refreshToken,
    loading,
    permissions,
    hasPermission: (permission) => hasPermissionFor(user, permission),
    login,
    register,
    verifyEmail,
    resendVerificationCode,
    requestPasswordReset,
    verifyPasswordResetCode,
    resetPassword,
    refreshSession,
    logout,
    logoutAll
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}

export { PERMISSIONS };
