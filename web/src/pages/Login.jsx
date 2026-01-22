import { useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import logo from "../assets/Logo.png";

export default function Login() {
  const { login, register } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const redirectTo = location.state?.from?.pathname || "/";

  const [mode, setMode] = useState("login");
  const [form, setForm] = useState({ name: "", email: "", password: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    setLoading(true);
    try {
      if (mode === "login") {
        await login(form.email, form.password);
      } else {
        await register(form.name, form.email, form.password);
      }
      navigate(redirectTo, { replace: true });
    } catch (err) {
      setError(err.message || "Falha ao autenticar");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-brand">
          <img src={logo} alt="RV TecnoCare" />
          <div>
            <strong>RV TecnoCare</strong>
            <span>Relatórios e orçamentos técnicos</span>
          </div>
        </div>

        <div className="auth-tabs">
          <button
            type="button"
            className={mode === "login" ? "tab active" : "tab"}
            onClick={() => setMode("login")}
          >
            Entrar
          </button>
          <button
            type="button"
            className={mode === "register" ? "tab active" : "tab"}
            onClick={() => setMode("register")}
          >
            Criar conta
          </button>
        </div>

        <form onSubmit={handleSubmit} className="auth-form">
          {mode === "register" && (
            <label>
              Nome completo
              <input
                type="text"
                value={form.name}
                onChange={(event) => updateField("name", event.target.value)}
                placeholder="Digite seu nome"
                required
              />
            </label>
          )}

          <label>
            E-mail
            <input
              type="email"
              value={form.email}
              onChange={(event) => updateField("email", event.target.value)}
              placeholder="seu@email.com"
              required
            />
          </label>

          <label>
            Senha
            <input
              type="password"
              value={form.password}
              onChange={(event) => updateField("password", event.target.value)}
              placeholder="Digite sua senha"
              required
            />
          </label>

          {error && <p className="muted">{error}</p>}

          <button className="btn primary" type="submit" disabled={loading}>
            {loading ? "Processando..." : mode === "login" ? "Entrar" : "Cadastrar"}
          </button>
        </form>

        <div className="auth-note">
          {mode === "register" ? (
            <small>
              Novos cadastros entram como <strong>visitante</strong> (somente leitura).
            </small>
          ) : (
            <small>Peça ao administrador para liberar permissões adicionais.</small>
          )}
        </div>
      </div>
    </div>
  );
}
