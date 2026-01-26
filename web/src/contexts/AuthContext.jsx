import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { apiGet, apiPost, setAuthToken } from "../api";

const AuthContext = createContext(null);

export const PERMISSIONS = {
  VIEW_DASHBOARD: "view_dashboard",
  VIEW_CLIENTS: "view_clients",
  MANAGE_CLIENTS: "manage_clients",
  VIEW_TASKS: "view_tasks",
  MANAGE_TASKS: "manage_tasks",
  VIEW_TEMPLATES: "view_templates",
  MANAGE_TEMPLATES: "manage_templates",
  VIEW_BUDGETS: "view_budgets",
  MANAGE_BUDGETS: "manage_budgets",
  VIEW_USERS: "view_users",
  MANAGE_USERS: "manage_users",
  VIEW_PRODUCTS: "view_products",
  MANAGE_PRODUCTS: "manage_products",
  VIEW_TASK_TYPES: "view_task_types",
  MANAGE_TASK_TYPES: "manage_task_types"
};

const ALL_PERMISSIONS = Object.values(PERMISSIONS);

const ROLE_DEFAULTS = {
  administracao: ALL_PERMISSIONS,
  gestor: [
    PERMISSIONS.VIEW_DASHBOARD,
    PERMISSIONS.VIEW_CLIENTS,
    PERMISSIONS.MANAGE_CLIENTS,
    PERMISSIONS.VIEW_TASKS,
    PERMISSIONS.MANAGE_TASKS,
    PERMISSIONS.VIEW_TEMPLATES,
    PERMISSIONS.MANAGE_TEMPLATES,
    PERMISSIONS.VIEW_BUDGETS,
    PERMISSIONS.MANAGE_BUDGETS,
    PERMISSIONS.VIEW_PRODUCTS,
    PERMISSIONS.MANAGE_PRODUCTS,
    PERMISSIONS.VIEW_TASK_TYPES,
    PERMISSIONS.MANAGE_TASK_TYPES
  ],
  tecnico: [
    PERMISSIONS.VIEW_DASHBOARD,
    PERMISSIONS.VIEW_CLIENTS,
    PERMISSIONS.VIEW_TASKS,
    PERMISSIONS.MANAGE_TASKS,
    PERMISSIONS.VIEW_BUDGETS,
    PERMISSIONS.VIEW_PRODUCTS
  ],
  visitante: [
    PERMISSIONS.VIEW_DASHBOARD,
    PERMISSIONS.VIEW_CLIENTS,
    PERMISSIONS.VIEW_TASKS,
    PERMISSIONS.VIEW_TEMPLATES,
    PERMISSIONS.VIEW_BUDGETS,
    PERMISSIONS.VIEW_PRODUCTS,
    PERMISSIONS.VIEW_TASK_TYPES
  ]
};

function parsePermissions(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      return [];
    }
  }
  return [];
}

function getUserPermissions(user) {
  if (!user) return [];
  if (user.role_is_admin || user.role === "administracao") return ALL_PERMISSIONS;
  const rolePermissions = parsePermissions(user.role_permissions);
  const base = rolePermissions.length
    ? rolePermissions
    : ROLE_DEFAULTS[user.role] || ROLE_DEFAULTS.visitante;
  return Array.from(new Set(base));
}

function hasPermissionFor(user, permission) {
  if (!user) return false;
  if (user.role_is_admin || user.role === "administracao") return true;
  const permissions = new Set(getUserPermissions(user));
  if (permissions.has(permission)) return true;
  if (permission.startsWith("view_")) {
    const manage = permission.replace("view_", "manage_");
    return permissions.has(manage);
  }
  return false;
}

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
    async function load() {
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

    load();
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
