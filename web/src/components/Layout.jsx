import { Link, NavLink, Outlet } from "react-router-dom";
import logo from "../assets/Logo.png";

const navItems = [
  { to: "/", label: "Painel" },
  { to: "/clientes", label: "Clientes" },
  { to: "/tarefas", label: "Tarefas" },
  { to: "/modelos", label: "Modelos" },
  { to: "/orcamentos", label: "Orçamentos" },
  { to: "/usuarios", label: "Usuários" },
  { to: "/produtos", label: "Produtos" },
  { to: "/tipos-tarefa", label: "Tipos de tarefa" }
];

export default function Layout() {
  return (
    <div className="app-shell">
      <aside className="side-nav">
        <div className="brand">
          <img src={logo} alt="RV TecnoCare" />
          <div>
            <span className="brand-title">RV TecnoCare</span>
            <span className="brand-subtitle">Tarefas e Orçamentos</span>
          </div>
        </div>
        <nav className="nav-links">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                isActive ? "nav-link active" : "nav-link"
              }
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
            <div className="search">
              <input
                type="search"
                placeholder="Buscar clientes e tarefas"
              />
            </div>
            <Link className="btn primary" to="/tarefas/nova">
              Nova tarefa
            </Link>
          </div>
        </header>

        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
