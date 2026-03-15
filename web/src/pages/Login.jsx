import { useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import { useAuth } from "../contexts/AuthContext";
import logo from "../assets/Logo.png";
import { getFriendlyErrorMessage } from "../shared/errors/error-normalizer";

const FLOW = {
  LOGIN: "login",
  REGISTER: "register",
  VERIFY_EMAIL: "verify-email",
  FORGOT_PASSWORD: "forgot-password",
  VERIFY_RESET_CODE: "verify-reset-code",
  RESET_PASSWORD: "reset-password"
};

function createEmptyForm() {
  return {
    name: "",
    email: "",
    password: "",
    passwordConfirm: "",
    code: "",
    newPassword: "",
    newPasswordConfirm: ""
  };
}

export default function Login() {
  const {
    login,
    register,
    verifyEmail,
    resendVerificationCode,
    requestPasswordReset,
    verifyPasswordResetCode,
    resetPassword
  } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const redirectTo = location.state?.from?.pathname || "/";

  const [flow, setFlow] = useState(FLOW.LOGIN);
  const [form, setForm] = useState(createEmptyForm());
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(false);
  const [verificationMeta, setVerificationMeta] = useState(null);

  const titleMap = useMemo(
    () => ({
      [FLOW.LOGIN]: "Acesse a sua conta",
      [FLOW.REGISTER]: "Crie a sua conta",
      [FLOW.VERIFY_EMAIL]: "Confirme o seu e-mail",
      [FLOW.FORGOT_PASSWORD]: "Recupere o acesso",
      [FLOW.VERIFY_RESET_CODE]: "Valide o código de recuperação",
      [FLOW.RESET_PASSWORD]: "Defina uma nova senha"
    }),
    []
  );

  const subtitleMap = useMemo(
    () => ({
      [FLOW.LOGIN]: "Entre com seu e-mail e senha para continuar.",
      [FLOW.REGISTER]:
        "Cadastre uma nova conta para acessar o sistema e acompanhar suas tarefas.",
      [FLOW.VERIFY_EMAIL]:
        "Informe o código enviado para o seu e-mail para ativar a conta.",
      [FLOW.FORGOT_PASSWORD]:
        "Informe o e-mail cadastrado para receber um código de recuperação.",
      [FLOW.VERIFY_RESET_CODE]:
        "Digite o código recebido por e-mail para continuar com a redefinição.",
      [FLOW.RESET_PASSWORD]:
        "Crie uma nova senha para concluir a recuperação da conta."
    }),
    []
  );

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function switchTo(nextFlow) {
    setFlow(nextFlow);
    setError("");
    setNotice("");
  }

  function validatePasswordConfirmation(password, passwordConfirm) {
    if (password !== passwordConfirm) {
      throw new Error("As senhas informadas não coincidem.");
    }
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (flow === FLOW.LOGIN) {
        await login(form.email, form.password);
        navigate(redirectTo, { replace: true });
        return;
      }

      if (flow === FLOW.REGISTER) {
        validatePasswordConfirmation(form.password, form.passwordConfirm);
        const data = await register(form.name, form.email, form.password);
        setVerificationMeta(data?.verification || null);
        setNotice(data?.message || "Enviamos um código de verificação para o seu e-mail.");
        setFlow(FLOW.VERIFY_EMAIL);
        return;
      }

      if (flow === FLOW.VERIFY_EMAIL) {
        await verifyEmail(form.email, form.code);
        navigate(redirectTo, { replace: true });
        return;
      }

      if (flow === FLOW.FORGOT_PASSWORD) {
        const data = await requestPasswordReset(form.email);
        setNotice(
          data?.message ||
            "Se o e-mail informado estiver cadastrado, você receberá um código para redefinir sua senha."
        );
        setFlow(FLOW.VERIFY_RESET_CODE);
        return;
      }

      if (flow === FLOW.VERIFY_RESET_CODE) {
        const data = await verifyPasswordResetCode(form.email, form.code);
        setNotice(data?.message || "Código validado com sucesso.");
        setFlow(FLOW.RESET_PASSWORD);
        return;
      }

      if (flow === FLOW.RESET_PASSWORD) {
        validatePasswordConfirmation(form.newPassword, form.newPasswordConfirm);
        const data = await resetPassword(form.email, form.code, form.newPassword);
        setNotice(data?.message || "Senha redefinida com sucesso.");
        setFlow(FLOW.LOGIN);
        setForm((prev) => ({
          ...createEmptyForm(),
          email: prev.email
        }));
      }
    } catch (err) {
      if (flow === FLOW.LOGIN && err?.code === "email_verification_required") {
        const details = err.details || {};
        setVerificationMeta(details);
        updateField("email", details.email || form.email);
        setNotice(err.message);
        setFlow(FLOW.VERIFY_EMAIL);
      } else {
        setError(
          getFriendlyErrorMessage(err, "Não foi possível concluir a operação no momento.")
        );
      }
    } finally {
      setLoading(false);
    }
  }

  async function handleResendVerification() {
    setError("");
    setLoading(true);
    try {
      const data = await resendVerificationCode(form.email);
      setVerificationMeta(data?.verification || verificationMeta);
      setNotice(data?.message || "Enviamos um novo código de verificação.");
    } catch (err) {
      setError(
        getFriendlyErrorMessage(
          err,
          "Não foi possível reenviar o código de verificação no momento."
        )
      );
    } finally {
      setLoading(false);
    }
  }

  const maskedEmail = verificationMeta?.maskedEmail || "";

  return (
    <div className="auth-page">
      <div className="auth-card auth-card-wide">
        <div className="auth-brand">
          <img src={logo} alt="RV Sistema Empresa" />
          <div>
            <strong>RV Sistema Empresa</strong>
            <span>Gestão técnica de tarefas, relatórios e orçamentos.</span>
          </div>
        </div>

        <div className="auth-copy">
          <h1>{titleMap[flow]}</h1>
          <p className="muted">{subtitleMap[flow]}</p>
        </div>

        {(flow === FLOW.LOGIN || flow === FLOW.REGISTER) && (
          <div className="auth-tabs">
            <button
              type="button"
              className={flow === FLOW.LOGIN ? "tab active" : "tab"}
              onClick={() => switchTo(FLOW.LOGIN)}
            >
              Entrar
            </button>
            <button
              type="button"
              className={flow === FLOW.REGISTER ? "tab active" : "tab"}
              onClick={() => switchTo(FLOW.REGISTER)}
            >
              Criar conta
            </button>
          </div>
        )}

        {notice && <div className="banner banner-info">{notice}</div>}
        {error && <div className="banner banner-error">{error}</div>}

        <form onSubmit={handleSubmit} className="auth-form">
          {flow === FLOW.REGISTER && (
            <label>
              Nome completo
              <input
                type="text"
                value={form.name}
                onChange={(event) => updateField("name", event.target.value)}
                placeholder="Informe seu nome completo"
                required
              />
            </label>
          )}

          {(flow === FLOW.LOGIN ||
            flow === FLOW.REGISTER ||
            flow === FLOW.VERIFY_EMAIL ||
            flow === FLOW.FORGOT_PASSWORD ||
            flow === FLOW.VERIFY_RESET_CODE ||
            flow === FLOW.RESET_PASSWORD) && (
            <label>
              E-mail
              <input
                type="email"
                value={form.email}
                onChange={(event) => updateField("email", event.target.value)}
                placeholder="voce@empresa.com"
                required
                disabled={[FLOW.VERIFY_EMAIL, FLOW.VERIFY_RESET_CODE, FLOW.RESET_PASSWORD].includes(flow)}
              />
            </label>
          )}

          {(flow === FLOW.LOGIN || flow === FLOW.REGISTER) && (
            <label>
              Senha
              <input
                type="password"
                value={form.password}
                onChange={(event) => updateField("password", event.target.value)}
                placeholder="Informe sua senha"
                required
              />
            </label>
          )}

          {flow === FLOW.REGISTER && (
            <label>
              Confirmar senha
              <input
                type="password"
                value={form.passwordConfirm}
                onChange={(event) => updateField("passwordConfirm", event.target.value)}
                placeholder="Repita a senha informada"
                required
              />
            </label>
          )}

          {(flow === FLOW.VERIFY_EMAIL || flow === FLOW.VERIFY_RESET_CODE) && (
            <label>
              Código
              <input
                type="text"
                inputMode="numeric"
                value={form.code}
                onChange={(event) =>
                  updateField("code", event.target.value.replace(/\D+/g, "").slice(0, 6))
                }
                placeholder="Informe o código de 6 dígitos"
                required
              />
            </label>
          )}

          {flow === FLOW.RESET_PASSWORD && (
            <>
              <label>
                Nova senha
                <input
                  type="password"
                  value={form.newPassword}
                  onChange={(event) => updateField("newPassword", event.target.value)}
                  placeholder="Crie uma nova senha"
                  required
                />
              </label>
              <label>
                Confirmar nova senha
                <input
                  type="password"
                  value={form.newPasswordConfirm}
                  onChange={(event) => updateField("newPasswordConfirm", event.target.value)}
                  placeholder="Repita a nova senha"
                  required
                />
              </label>
            </>
          )}

          {flow === FLOW.VERIFY_EMAIL && maskedEmail && (
            <p className="auth-helper">
              Código enviado para <strong>{maskedEmail}</strong>.
            </p>
          )}

          <button className="btn primary" type="submit" disabled={loading}>
            {loading
              ? "Aguarde..."
              : flow === FLOW.LOGIN
                ? "Entrar"
                : flow === FLOW.REGISTER
                  ? "Criar conta"
                  : flow === FLOW.VERIFY_EMAIL
                    ? "Confirmar e acessar"
                    : flow === FLOW.FORGOT_PASSWORD
                      ? "Enviar código"
                      : flow === FLOW.VERIFY_RESET_CODE
                        ? "Validar código"
                        : "Salvar nova senha"}
          </button>
        </form>

        <div className="auth-links">
          {flow === FLOW.LOGIN && (
            <>
              <button
                type="button"
                className="link-button"
                onClick={() => switchTo(FLOW.FORGOT_PASSWORD)}
              >
                Esqueci minha senha
              </button>
              <span className="muted">A conta precisa estar verificada para liberar o acesso.</span>
            </>
          )}

          {flow === FLOW.REGISTER && (
            <span className="muted">
              Novos cadastros são criados como visitante até a confirmação do e-mail.
            </span>
          )}

          {flow === FLOW.VERIFY_EMAIL && (
            <div className="auth-link-row">
              <button
                type="button"
                className="link-button"
                onClick={handleResendVerification}
                disabled={loading}
              >
                Reenviar código
              </button>
              <button
                type="button"
                className="link-button"
                onClick={() => switchTo(FLOW.LOGIN)}
              >
                Voltar para o login
              </button>
            </div>
          )}

          {(flow === FLOW.FORGOT_PASSWORD ||
            flow === FLOW.VERIFY_RESET_CODE ||
            flow === FLOW.RESET_PASSWORD) && (
            <div className="auth-link-row">
              {flow !== FLOW.FORGOT_PASSWORD && (
                <button
                  type="button"
                  className="link-button"
                  onClick={() => switchTo(FLOW.FORGOT_PASSWORD)}
                >
                  Alterar e-mail
                </button>
              )}
              <button
                type="button"
                className="link-button"
                onClick={() => switchTo(FLOW.LOGIN)}
              >
                Voltar para o login
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
