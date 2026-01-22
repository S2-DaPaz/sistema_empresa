import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

export function RequireAuth({ children }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="auth-loading">
        <div className="card">
          <h3>Carregando acesso</h3>
          <small>Validando sua sessão.</small>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return children || <Outlet />;
}

export function RequireAdmin({ children }) {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="auth-loading">
        <div className="card">
          <h3>Carregando acesso</h3>
          <small>Validando permissões.</small>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (user.role !== "administracao") {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Acesso restrito</h2>
        </div>
        <div className="card">
          <p>Somente o administrador pode acessar esta área.</p>
        </div>
      </section>
    );
  }

  return children || <Outlet />;
}
