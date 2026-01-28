import { Link, NavLink, Outlet, useLocation, useSearchParams } from "react-router-dom";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";
import logo from "../assets/Logo.png";

const navItems = [
  { to: "/", label: "Painel", permission: PERMISSIONS.VIEW_DASHBOARD },
  { to: "/clientes", label: "Clientes", permission: PERMISSIONS.VIEW_CLIENTS },
  { to: "/tarefas", label: "Tarefas", permission: PERMISSIONS.VIEW_TASKS },
  { to: "/equipamentos", label: "Equipamentos", permission: PERMISSIONS.VIEW_TASKS },
  { to: "/modelos", label: "Modelos", permission: PERMISSIONS.VIEW_TEMPLATES },
  { to: "/orcamentos", label: "Orçamentos", permission: PERMISSIONS.VIEW_BUDGETS },
  { to: "/produtos", label: "Produtos", permission: PERMISSIONS.VIEW_PRODUCTS },
  { to: "/tipos-tarefa", label: "Tipos de tarefa", permission: PERMISSIONS.VIEW_TASK_TYPES },
  { to: "/usuarios", label: "Usuários", permission: PERMISSIONS.VIEW_USERS }
];

export default function Layout() {
  const { user, logout, hasPermission } = useAuth();
  const roleLabel = user?.role_name || user?.role || "visitante";
  const canManageTasks = hasPermission(PERMISSIONS.MANAGE_TASKS);
  const location = useLocation();
  const [searchParams, setSearchParams] = useSearchParams();
  const isTasksRoute = location.pathname.startsWith("/tarefas");
  const taskQuery = searchParams.get("q") || "";
  const statusFilter = searchParams.get("status") || "all";
  const priorityFilter = searchParams.get("priority") || "all";
  const hasFilters =
    taskQuery.trim() !== "" || statusFilter !== "all" || priorityFilter !== "all";

  const visibleItems = navItems.filter((item) => {
    if (item.permission) return hasPermission(item.permission);
    return true;
  });

  function updateParam(key, value) {
    const next = new URLSearchParams(searchParams);
    const normalized = typeof value === "string" ? value.trim() : value;
    if (!normalized || normalized === "all") {
      next.delete(key);
    } else {
      next.set(key, normalized);
    }
    setSearchParams(next, { replace: true });
  }

  function clearFilters() {
    const next = new URLSearchParams(searchParams);
    next.delete("q");
    next.delete("status");
    next.delete("priority");
    setSearchParams(next, { replace: true });
  }

  return (
    <div className="app-shell">
      <aside className="side-nav">
        <div className="brand">
          <img src={logo} alt="RV TecnoCare" />
          <div>
            <span className="brand-title">RV TecnoCare</span>
            <span className="brand-subtitle">Tarefas e orçamentos</span>
          </div>
        </div>
        <nav className="nav-links">
          {visibleItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => (isActive ? "nav-link active" : "nav-link")}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="nav-footer">
          <span className="pill">MVP ativo</span>
          <span className="muted">Versão inicial</span>
        </div>
      </aside>

      <div className="main-wrap">
        <header className="top-bar">
          <div>
            <span className="eyebrow">Sistema de operações</span>
            <h1>Tarefas com relatórios e orçamentos integrados</h1>
          </div>
          <div className="top-actions">
            {isTasksRoute && (
              <div className="task-search">
                <div className="search">
                  <input
                    type="search"
                    placeholder="Buscar tarefas"
                    value={taskQuery}
                    onChange={(event) => updateParam("q", event.target.value)}
                  />
                </div>
                <label className="filter-select">
                  <span>Status</span>
                  <select
                    value={statusFilter}
                    onChange={(event) => updateParam("status", event.target.value)}
                  >
                    <option value="all">Todos</option>
                    <option value="aberta">Aberta</option>
                    <option value="em_andamento">Em andamento</option>
                    <option value="concluida">Concluída</option>
                  </select>
                </label>
                <label className="filter-select">
                  <span>Prioridade</span>
                  <select
                    value={priorityFilter}
                    onChange={(event) => updateParam("priority", event.target.value)}
                  >
                    <option value="all">Todas</option>
                    <option value="alta">Alta</option>
                    <option value="media">Média</option>
                    <option value="baixa">Baixa</option>
                  </select>
                </label>
                {hasFilters && (
                  <button className="btn ghost" type="button" onClick={clearFilters}>
                    Limpar
                  </button>
                )}
              </div>
            )}
            {canManageTasks && (
              <Link className="btn primary" to="/tarefas/nova">
                Nova tarefa
              </Link>
            )}
            <div className="user-pill">
              <span>{user?.name || "Usuário"}</span>
              <small>{roleLabel}</small>
              <button className="btn ghost" type="button" onClick={logout}>
                Sair
              </button>
            </div>
          </div>
        </header>

        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
