import { useEffect, useMemo, useState } from "react";
import { apiPost } from "../api";
import FormField from "./FormField";

function uid() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return `id_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

export default function BudgetForm({
  clientId,
  taskId,
  reportId,
  products,
  clients = [],
  onSaved
}) {
  const [localClientId, setLocalClientId] = useState(clientId || "");
  const [status, setStatus] = useState("rascunho");
  const [notes, setNotes] = useState("");
  const [internalNote, setInternalNote] = useState("");
  const [proposalValidity, setProposalValidity] = useState("30 dias");
  const [paymentTerms, setPaymentTerms] = useState("À vista");
  const [serviceDeadline, setServiceDeadline] = useState("03 a 04 horas");
  const [productValidity, setProductValidity] = useState("03 meses");
  const [discount, setDiscount] = useState(0);
  const [tax, setTax] = useState(0);
  const [items, setItems] = useState([
    {
      id: uid(),
      product_id: "",
      description: "",
      qty: 1,
      unit_price: 0
    }
  ]);
  const [error, setError] = useState("");

  const productOptions = useMemo(
    () => products.map((product) => ({ value: product.id, label: product.name })),
    [products]
  );

  useEffect(() => {
    setLocalClientId(clientId || "");
  }, [clientId]);

  const effectiveClientId = clientId || localClientId;

  function updateItem(id, updates) {
    setItems((prev) => prev.map((item) => (item.id === id ? { ...item, ...updates } : item)));
  }

  function addItem() {
    setItems((prev) => [
      ...prev,
      { id: uid(), product_id: "", description: "", qty: 1, unit_price: 0 }
    ]);
  }

  function removeItem(id) {
    setItems((prev) => prev.filter((item) => item.id !== id));
  }

  function handleProductChange(id, value) {
    const selected = products.find((product) => product.id === Number(value));
    updateItem(id, {
      product_id: value,
      description: selected?.name || "",
      unit_price: selected?.price ?? 0
    });
  }

  const subtotal = items.reduce(
    (sum, item) => sum + Number(item.qty || 0) * Number(item.unit_price || 0),
    0
  );
  const total = subtotal - Number(discount || 0) + Number(tax || 0);

  const formatter = useMemo(
    () => new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }),
    []
  );

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");

    if (!effectiveClientId) {
      setError("Selecione um cliente antes de salvar o orçamento.");
      return;
    }

    const payload = {
      client_id: Number(effectiveClientId),
      task_id: taskId ? Number(taskId) : null,
      report_id: reportId ? Number(reportId) : null,
      status,
      notes,
      internal_note: internalNote,
      proposal_validity: proposalValidity,
      payment_terms: paymentTerms,
      service_deadline: serviceDeadline,
      product_validity: productValidity,
      discount: Number(discount || 0),
      tax: Number(tax || 0),
      items: items.map((item) => ({
        product_id: item.product_id ? Number(item.product_id) : null,
        description: item.description || "Item",
        qty: Number(item.qty || 0),
        unit_price: Number(item.unit_price || 0)
      }))
    };

    try {
      await apiPost("/budgets", payload);
      setStatus("rascunho");
      setNotes("");
      setInternalNote("");
      setProposalValidity("30 dias");
      setPaymentTerms("À vista");
      setServiceDeadline("03 a 04 horas");
      setProductValidity("03 meses");
      setDiscount(0);
      setTax(0);
      setItems([
        {
          id: uid(),
          product_id: "",
          description: "",
          qty: 1,
          unit_price: 0
        }
      ]);
      onSaved?.();
    } catch (err) {
      setError(err.message || "Falha ao salvar");
    }
  }

  return (
    <form className="card" onSubmit={handleSubmit}>
      <h3>Novo orçamento</h3>
      <div className="form-grid">
        {!clientId && (
          <FormField
            label="Cliente"
            type="select"
            value={localClientId}
            options={clients.map((client) => ({ value: client.id, label: client.name }))}
            onChange={setLocalClientId}
          />
        )}
        <FormField
          label="Status"
          type="select"
          value={status}
          options={[
            { value: "rascunho", label: "Rascunho" },
            { value: "enviado", label: "Enviado" },
            { value: "aprovado", label: "Aprovado" }
          ]}
          onChange={setStatus}
        />
        <FormField
          label="Desconto"
          type="number"
          value={discount}
          onChange={setDiscount}
        />
        <FormField label="Taxa" type="number" value={tax} onChange={setTax} />
      </div>
      <div className="form-grid">
        <FormField
          label="Validade da proposta"
          value={proposalValidity}
          onChange={setProposalValidity}
        />
        <FormField
          label="Condição de pagamento"
          value={paymentTerms}
          onChange={setPaymentTerms}
        />
        <FormField
          label="Prazo de realização dos serviços"
          value={serviceDeadline}
          onChange={setServiceDeadline}
        />
        <FormField
          label="Prazo de validade dos produtos"
          value={productValidity}
          onChange={setProductValidity}
        />
      </div>
      <div className="form-grid">
        <FormField
          label="Observação"
          type="textarea"
          value={notes}
          onChange={setNotes}
          className="full"
        />
        <FormField
          label="Nota interna"
          type="textarea"
          value={internalNote}
          onChange={setInternalNote}
          className="full"
        />
      </div>

      <div className="section-header" style={{ marginTop: "16px" }}>
        <h3 className="section-title">Itens</h3>
        <button className="btn secondary" type="button" onClick={addItem}>
          Adicionar item
        </button>
      </div>

      <div className="list">
        {items.map((item) => (
          <div key={item.id} className="card">
            <div className="form-grid">
              <FormField
                label="Produto"
                type="select"
                value={item.product_id}
                options={productOptions}
                onChange={(value) => handleProductChange(item.id, value)}
              />
              <FormField
                label="Descrição"
                value={item.description}
                onChange={(value) => updateItem(item.id, { description: value })}
              />
              <FormField
                label="Qtd."
                type="number"
                value={item.qty}
                onChange={(value) => updateItem(item.id, { qty: value })}
              />
              <FormField
                label="Valor"
                type="number"
                value={item.unit_price}
                onChange={(value) => updateItem(item.id, { unit_price: value })}
              />
            </div>
            <div className="inline" style={{ marginTop: "10px" }}>
              <button className="btn ghost" type="button" onClick={() => removeItem(item.id)}>
                Remover item
              </button>
            </div>
          </div>
        ))}
      </div>

      <div className="inline" style={{ justifyContent: "space-between", marginTop: "16px" }}>
        <div className="inline">
          <span className="badge">Subtotal: {formatter.format(subtotal)}</span>
          <span className="badge">Total: {formatter.format(total)}</span>
        </div>
        <button className="btn primary" type="submit">
          Salvar orçamento
        </button>
      </div>
      {error && <p className="muted">{error}</p>}
    </form>
  );
}
