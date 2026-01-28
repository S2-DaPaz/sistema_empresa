import { useEffect, useMemo, useState } from "react";
import { apiGet, apiPost } from "../api";
import BudgetForm from "../components/BudgetForm";
import { buildBudgetEmailText, buildBudgetPdfHtml, openPrintWindow } from "../utils/pdf";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";
import logo from "../assets/Logo.png";

export default function Budgets() {
  const { hasPermission } = useAuth();
  const canView = hasPermission(PERMISSIONS.VIEW_BUDGETS);
  const canManage = hasPermission(PERMISSIONS.MANAGE_BUDGETS);

  const [budgets, setBudgets] = useState([]);
  const [clients, setClients] = useState([]);
  const [products, setProducts] = useState([]);

  useEffect(() => {
    if (!canView) return;
    async function load() {
      const [budgetData, clientData, productData] = await Promise.all([
        apiGet("/budgets?includeItems=1"),
        apiGet("/clients"),
        apiGet("/products")
      ]);
      setBudgets(budgetData || []);
      setClients(clientData || []);
      setProducts(productData || []);
    }
    load();
  }, [canView]);

  const formatter = useMemo(
    () => new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }),
    []
  );

  function handleExport(budget) {
    const client = clients.find((item) => item.id === Number(budget.client_id));
    const html = buildBudgetPdfHtml({
      budget,
      client,
      signatureMode: budget.signature_mode,
      signatureScope: budget.signature_scope,
      signatureClient: budget.signature_client,
      signatureTech: budget.signature_tech,
      signaturePages: budget.signature_pages || {},
      logoUrl: logo
    });
    openPrintWindow(html);
  }

  function handleSendEmail(budget) {
    const client = clients.find((item) => item.id === Number(budget.client_id));
    const emailMatch = (client?.contact || "").match(
      /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
    );
    const email = emailMatch ? emailMatch[0] : "";
    const subject = `Orçamento #${budget.id}`;
    const body = buildBudgetEmailText(budget, client);
    const mailto = `mailto:${email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    window.location.href = mailto;
  }

  async function ensurePublicLink(taskId) {
    if (!taskId) {
      alert("Este orçamento não está vinculado a uma tarefa.");
      return null;
    }
    const response = await apiPost(`/tasks/${taskId}/public-link`, {});
    return response?.url;
  }

  async function handleShareLink(budget) {
    try {
      const url = await ensurePublicLink(budget.task_id);
      if (!url) return;
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(url);
        alert("Link copiado para a área de transferência.");
      } else {
        window.prompt("Copie o link abaixo:", url);
      }
    } catch (error) {
      alert(error.message || "Falha ao gerar link.");
    }
  }

  async function handleOpenReport(budget) {
    try {
      const url = await ensurePublicLink(budget.task_id);
      if (!url) return;
      window.open(url, "_blank", "noopener");
    } catch (error) {
      alert(error.message || "Falha ao abrir link.");
    }
  }

  async function handleReload() {
    const data = await apiGet("/budgets?includeItems=1");
    setBudgets(data || []);
  }

  if (!canView) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Orçamentos</h2>
        </div>
        <div className="card">
          <p>Você não tem permissão para visualizar orçamentos.</p>
        </div>
      </section>
    );
  }

  return (
    <section className="section">
      <div className="section-header">
        <h2 className="section-title">Orçamentos</h2>
        <span className="muted">Crie orçamentos avulsos ou vinculados a tarefas</span>
      </div>

      <BudgetForm
        clients={clients}
        products={products}
        onSaved={handleReload}
        canManage={canManage}
      />

      <div className="list" style={{ marginTop: "20px" }}>
        {budgets.length === 0 && (
          <div className="card">
            <h3>Nenhum orçamento</h3>
            <small>Crie um orçamento acima para iniciar.</small>
          </div>
        )}
        {budgets.map((budget) => (
          <div key={budget.id} className="card">
            <div className="inline" style={{ justifyContent: "space-between" }}>
              <h3>Orçamento #{budget.id}</h3>
              <span className="badge">{budget.status || "rascunho"}</span>
            </div>
            <small>
              Cliente: {budget.client_name || "Sem cliente"} | Total: {formatter.format(budget.total || 0)}
            </small>
            {budget.task_title && <small>Tarefa: {budget.task_title}</small>}
            {budget.report_title && <small>Relatório: {budget.report_title}</small>}

            <div className="list" style={{ marginTop: "10px" }}>
              {(budget.items || []).map((item) => (
                <div key={item.id} className="card">
                  <div className="inline" style={{ justifyContent: "space-between" }}>
                    <span>{item.description}</span>
                    <span>{formatter.format(item.total || 0)}</span>
                  </div>
                  <small>
                    {item.qty} x {formatter.format(item.unit_price || 0)}
                  </small>
                </div>
              ))}
            </div>

            <div className="inline" style={{ marginTop: "12px" }}>
              <button className="btn secondary" type="button" onClick={() => handleSendEmail(budget)}>
                Enviar e-mail
              </button>
              <button className="btn ghost" type="button" onClick={() => handleExport(budget)}>
                Exportar PDF
              </button>
              <button className="btn ghost" type="button" onClick={() => handleShareLink(budget)}>
                Compartilhar link
              </button>
              <button className="btn secondary" type="button" onClick={() => handleOpenReport(budget)}>
                Abrir relatório
              </button>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
