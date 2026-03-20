import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { apiGet } from "../api";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";
import { getFriendlyErrorMessage } from "../shared/errors/error-normalizer";

function DashboardCard({ title, subtitle, value, actionLabel, onClick, disabled = false }) {
  return (
    <div className="card">
      <div className="inline" style={{ justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <h3>{title}</h3>
          <small>{subtitle}</small>
        </div>
        <span className="badge">{value}</span>
      </div>

      {onClick && (
        <div className="inline" style={{ marginTop: "16px" }}>
          <button className="btn secondary" type="button" onClick={onClick} disabled={disabled}>
            {actionLabel}
          </button>
        </div>
      )}
    </div>
  );
}

function formatPercentage(value) {
  const numeric = Number(value || 0);
  return `${numeric.toFixed(numeric % 1 === 0 ? 0 : 1)}%`;
}

export default function Dashboard() {
  const navigate = useNavigate();
  const { hasPermission } = useAuth();
  const canViewDashboard = hasPermission(PERMISSIONS.VIEW_DASHBOARD);
  const canViewClients = hasPermission(PERMISSIONS.VIEW_CLIENTS);
  const canViewTasks = hasPermission(PERMISSIONS.VIEW_TASKS);
  const canViewBudgets = hasPermission(PERMISSIONS.VIEW_BUDGETS);
  const canViewProducts = hasPermission(PERMISSIONS.VIEW_PRODUCTS);

  const [summary, setSummary] = useState({});
  const [metrics, setMetrics] = useState({});
  const [recentReports, setRecentReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!canViewDashboard) return;

    let active = true;

    async function loadDashboard() {
      setLoading(true);
      setError("");

      try {
        const payload = await apiGet("/summary");
        if (!active) return;
        setSummary(payload?.summary || {});
        setMetrics(payload?.metrics || {});
        setRecentReports((payload?.recentReports || []).slice(0, 5));
      } catch (requestError) {
        if (!active) return;
        setSummary({});
        setMetrics({});
        setRecentReports([]);
        setError(
          getFriendlyErrorMessage(
            requestError,
            "Nao foi possivel carregar o painel operacional."
          )
        );
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    loadDashboard();

    return () => {
      active = false;
    };
  }, [canViewDashboard]);

  const overviewCards = useMemo(
    () => [
      {
        key: "clients",
        title: "Clientes",
        subtitle: "Base cadastrada para atendimento",
        value: summary.clients ?? 0,
        actionLabel: "Abrir clientes",
        onClick: canViewClients ? () => navigate("/clientes") : null
      },
      {
        key: "tasks",
        title: "Tarefas",
        subtitle: "Fluxos operacionais em andamento",
        value: summary.tasks ?? 0,
        actionLabel: "Abrir tarefas",
        onClick: canViewTasks ? () => navigate("/tarefas") : null
      },
      {
        key: "products",
        title: "Produtos",
        subtitle: "Itens disponiveis para orcamentos",
        value: summary.products ?? 0,
        actionLabel: "Abrir produtos",
        onClick: canViewProducts ? () => navigate("/produtos") : null
      },
      {
        key: "budgets",
        title: "Orcamentos",
        subtitle: "Propostas vinculadas aos atendimentos",
        value: summary.budgets ?? 0,
        actionLabel: "Abrir orcamentos",
        onClick: canViewBudgets ? () => navigate("/orcamentos") : null
      }
    ],
    [summary, canViewBudgets, canViewClients, canViewProducts, canViewTasks, navigate]
  );

  const operationalCards = useMemo(
    () => [
      {
        key: "overdue",
        title: "Tarefas vencidas",
        subtitle: "Demandas fora do prazo previsto",
        value: metrics.overdueTasks ?? 0
      },
      {
        key: "pending-budgets",
        title: "Orcamentos pendentes",
        subtitle: "Ainda aguardando decisao ou fechamento",
        value: metrics.pendingBudgets ?? 0
      },
      {
        key: "conversion",
        title: "Conversao de orcamentos",
        subtitle: "Aprovados em relacao ao total emitido",
        value: formatPercentage(metrics.budgetConversionRate ?? 0)
      }
    ],
    [metrics]
  );

  if (!canViewDashboard) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Painel</h2>
        </div>
        <div className="card">
          <p>Voce nao tem permissao para visualizar o painel.</p>
        </div>
      </section>
    );
  }

  return (
    <div className="content">
      <section className="section">
        <div className="section-header">
          <div>
            <h2 className="section-title">Painel operacional</h2>
            <p className="muted">
              Visao consolidada da operacao para abrir modulos e identificar gargalos.
            </p>
          </div>
        </div>

        {error && <div className="banner banner-error">{error}</div>}

        <div className="grid-3 stagger">
          {overviewCards.map((card) => (
            <DashboardCard
              key={card.key}
              title={card.title}
              subtitle={card.subtitle}
              value={loading ? "..." : card.value}
              actionLabel={card.actionLabel}
              onClick={card.onClick}
              disabled={loading}
            />
          ))}
        </div>
      </section>

      <section className="section">
        <div className="section-header">
          <div>
            <h2 className="section-title">Metricas operacionais</h2>
            <p className="muted">
              Indicadores para priorizacao diaria e leitura rapida da saude da operacao.
            </p>
          </div>
        </div>

        <div className="grid-3 stagger">
          {operationalCards.map((card) => (
            <DashboardCard
              key={card.key}
              title={card.title}
              subtitle={card.subtitle}
              value={loading ? "..." : card.value}
            />
          ))}
        </div>

        <div className="card" style={{ marginTop: "16px" }}>
          <h3>Tecnico com maior carga</h3>
          {loading ? (
            <small>Carregando distribuicao de tarefas...</small>
          ) : metrics?.busiestTechnician ? (
            <small>
              {metrics.busiestTechnician.name} lidera a fila atual com{" "}
              {metrics.busiestTechnician.taskCount} tarefa(s) abertas.
            </small>
          ) : (
            <small>Nenhum tecnico com carga ativa foi identificado no momento.</small>
          )}
        </div>
      </section>

      <section className="section">
        <div className="section-header">
          <div>
            <h2 className="section-title">Ultimos relatorios</h2>
            <p className="muted">Acompanhe os registros recentes sem sair do painel.</p>
          </div>
          {canViewTasks && (
            <button className="btn secondary" type="button" onClick={() => navigate("/tarefas")}>
              Abrir tarefas
            </button>
          )}
        </div>

        <div className="list">
          {!loading && recentReports.length === 0 && (
            <div className="card">
              <h3>Nenhum relatorio recente</h3>
              <small>Os proximos registros enviados aparecerao aqui.</small>
            </div>
          )}

          {recentReports.map((report) => (
            <div key={report.id} className="card">
              <div className="inline" style={{ justifyContent: "space-between", alignItems: "flex-start" }}>
                <div>
                  <h3>{report.title || report.template_name || "Relatorio"}</h3>
                  <small>
                    {report.client_name ? `Cliente: ${report.client_name}` : "Sem cliente vinculado"}
                  </small>
                </div>
                <span className="badge neutral">{report.status || "rascunho"}</span>
              </div>
              <small className="muted" style={{ display: "block", marginTop: "12px" }}>
                {report.task_title ? `Tarefa: ${report.task_title}` : "Sem tarefa vinculada"}
                {report.created_at ? ` • ${new Date(report.created_at).toLocaleString("pt-BR")}` : ""}
              </small>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
