import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

function LoadingCard({ title, subtitle }) {
  return (
    <div className="auth-loading">
      <div className="card">
        <h3>{title}</h3>
        <small>{subtitle}</small>
      </div>
    </div>
  );
}

export function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return <LoadingCard title="Carregando acesso" subtitle="Validando sua sessao." />;
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return children || <Outlet />;
}

export function RequireAdmin({ children }) {
  const { user, loading } = useAuth();
  const isAdmin = user?.role_is_admin === true || user?.role === "administracao";

  if (loading) {
    return <LoadingCard title="Carregando acesso" subtitle="Validando permissoes." />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (!isAdmin) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Acesso restrito</h2>
        </div>
        <div className="card">
          <p>Somente o administrador pode acessar esta area.</p>
        </div>
      </section>
    );
  }

  return children || <Outlet />;
}

export function RequirePermission({ permission, children }) {
  const { user, loading, hasPermission } = useAuth();

  if (loading) {
    return <LoadingCard title="Carregando acesso" subtitle="Validando permissoes." />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (!hasPermission(permission)) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Acesso restrito</h2>
        </div>
        <div className="card">
          <p>Voce nao possui permissao para acessar esta area.</p>
        </div>
      </section>
    );
  }

  return children || <Outlet />;
}
