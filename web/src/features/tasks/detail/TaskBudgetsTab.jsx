import BudgetForm from "../../../components/BudgetForm";

export function TaskBudgetsTab({
  taskId,
  budgets,
  formatter,
  onShareBudgetLink,
  onOpenBudgetPage,
  generalReportId,
  formClientId,
  products,
  clients,
  canManageBudgets,
  onBudgetsSaved
}) {
  return (
    <div className="list">
      {!taskId && (
        <div className="card">
          <small>Salve a tarefa para liberar os orçamentos.</small>
        </div>
      )}

      {taskId && (
        <>
          <div className="card">
            <div className="section-header">
              <h3 className="section-title">Orçamentos vinculados</h3>
            </div>
            {budgets.length === 0 && <small>Nenhum orçamento cadastrado.</small>}
            {budgets.map((budget) => (
              <div key={budget.id} className="card">
                <div className="inline" style={{ justifyContent: "space-between" }}>
                  <strong>Orçamento #{budget.id}</strong>
                  <span className="badge">{budget.status || "rascunho"}</span>
                </div>
                <small>Total: {formatter.format(budget.total || 0)}</small>
                <div className="list" style={{ marginTop: "8px" }}>
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
                  <button className="btn ghost" type="button" onClick={() => onShareBudgetLink(budget.id)} disabled={!taskId}>
                    Compartilhar link
                  </button>
                  <button className="btn secondary" type="button" onClick={() => onOpenBudgetPage(budget.id)} disabled={!taskId}>
                    Abrir PDF
                  </button>
                </div>
              </div>
            ))}
          </div>

          <BudgetForm
            clientId={formClientId}
            reportId={generalReportId}
            taskId={taskId}
            products={products}
            clients={clients}
            canManage={canManageBudgets}
            onSaved={onBudgetsSaved}
          />
        </>
      )}
    </div>
  );
}
