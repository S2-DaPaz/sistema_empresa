import { useEffect, useMemo, useState } from "react";
import { apiGet } from "../api";
import BudgetForm from "../components/BudgetForm";
import { buildBudgetEmailText, buildBudgetPdfHtml, openPrintWindow } from "../utils/pdf";
import logo from "../assets/Logo.png";

export default function Budgets() {
  const [budgets, setBudgets] = useState([]);
  const [clients, setClients] = useState([]);
  const [products, setProducts] = useState([]);

  useEffect(() => {
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
  }, []);

  const formatter = useMemo(
    () => new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }),
    []
  );

  function handleExport(budget) {
    const client = clients.find((item) => item.id === Number(budget.client_id));
    const html = buildBudgetPdfHtml({ budget, client, logoUrl: logo });
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

  async function handleReload() {
    const data = await apiGet("/budgets?includeItems=1");
    setBudgets(data || []);
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
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
