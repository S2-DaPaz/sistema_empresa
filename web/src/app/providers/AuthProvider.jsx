import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { apiGet, apiPost, setAuthToken } from "../../shared/api/http-client";
import { PERMISSIONS } from "../../shared/contracts/permissions";
import {
  getUserPermissions,
  hasPermissionFor
} from "../../shared/auth/permissions";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem("rv-token") || "");
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setAuthToken(token);
    if (!token) {
      setUser(null);
      setLoading(false);
      return;
    }

    let active = true;
    async function loadSession() {
      try {
        const data = await apiGet("/auth/me");
        if (!active) return;
        setUser(data?.user || null);
      } catch (error) {
        if (!active) return;
        setUser(null);
        setToken("");
        localStorage.removeItem("rv-token");
        setAuthToken("");
      } finally {
        if (active) setLoading(false);
      }
    }

    loadSession();
    return () => {
      active = false;
    };
  }, [token]);

  const permissions = useMemo(() => getUserPermissions(user), [user]);

  function setSession(nextToken, nextUser) {
    setToken(nextToken);
    localStorage.setItem("rv-token", nextToken);
    setAuthToken(nextToken);
    setUser(nextUser);
  }

  async function login(email, password) {
    const data = await apiPost("/auth/login", { email, password });
    setSession(data.token, data.user);
    return data.user;
  }

  async function register(name, email, password) {
    const data = await apiPost("/auth/register", { name, email, password });
    setSession(data.token, data.user);
    return data.user;
  }

  function logout() {
    setToken("");
    setUser(null);
    localStorage.removeItem("rv-token");
    setAuthToken("");
  }

  const value = {
    user,
    token,
    loading,
    permissions,
    hasPermission: (permission) => hasPermissionFor(user, permission),
    login,
    register,
    logout
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
