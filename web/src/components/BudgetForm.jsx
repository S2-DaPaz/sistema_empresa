import { useEffect, useMemo, useRef, useState } from "react";
import { apiPost } from "../api";
import FormField from "./FormField";
import SignaturePad from "./SignaturePad";

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
  onSaved,
  canManage = true
}) {
  const [localClientId, setLocalClientId] = useState(clientId || "");
  const [status, setStatus] = useState("em_andamento");
  const [notes, setNotes] = useState("");
  const [internalNote, setInternalNote] = useState("");
  const [proposalValidity, setProposalValidity] = useState("30 dias");
  const [paymentTerms, setPaymentTerms] = useState("A vista");
  const [serviceDeadline, setServiceDeadline] = useState("03 a 04 horas");
  const [productValidity, setProductValidity] = useState("03 meses");
  const [discount, setDiscount] = useState(0);
  const [tax, setTax] = useState(0);
  const [signatureMode, setSignatureMode] = useState("none");
  const [signatureScope, setSignatureScope] = useState("last_page");
  const [signatureClient, setSignatureClient] = useState("");
  const [signatureTech, setSignatureTech] = useState("");
  const itemsEndRef = useRef(null);
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
    if (!canManage) return;
    setItems((prev) => [
      ...prev,
      { id: uid(), product_id: "", description: "", qty: 1, unit_price: 0 }
    ]);
    requestAnimationFrame(() => {
      itemsEndRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  }

  function removeItem(id) {
    if (!canManage) return;
    setItems((prev) => prev.filter((item) => item.id !== id));
  }

  function handleProductChange(id, value) {
    const selected = products.find((product) => product.id === Number(value));
    updateItem(id, {
      product_id: value,
      description: selected?.name || "",
      unit_price: selected?.price ? 0
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
    if (!canManage) return;
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
      signature_mode: signatureMode,
      signature_scope: signatureScope,
      signature_client: signatureClient,
      signature_tech: signatureTech,
      signature_pages: {},
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
      setStatus("em_andamento");
      setNotes("");
      setInternalNote("");
      setProposalValidity("30 dias");
      setPaymentTerms("A vista");
      setServiceDeadline("03 a 04 horas");
      setProductValidity("03 meses");
      setSignatureMode("none");
      setSignatureScope("last_page");
      setSignatureClient("");
      setSignatureTech("");
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
            disabled={!canManage}
          />
        )}
        <FormField
          label="Status"
          type="select"
          value={status}
          options={[
            { value: "aprovado", label: "Aprovado" },
            { value: "em_andamento", label: "Em andamento" },
            { value: "recusado", label: "Recusado" }
          ]}
          onChange={setStatus}
          disabled={!canManage}
        />
        <FormField
          label="Desconto"
          type="number"
          value={discount}
          onChange={setDiscount}
          disabled={!canManage}
        />
        <FormField
          label="Taxa"
          type="number"
          value={tax}
          onChange={setTax}
          disabled={!canManage}
        />
      </div>
      <div className="form-grid">
        <FormField
          label="Validade da proposta"
          value={proposalValidity}
          onChange={setProposalValidity}
          disabled={!canManage}
        />
        <FormField
          label="Condição de pagamento"
          type="select"
          value={paymentTerms}
          options={[
            { value: "A vista", label: "A vista" },
            { value: "Parcelado", label: "Parcelado" }
          ]}
          onChange={setPaymentTerms}
          disabled={!canManage}
        />
        <FormField
          label="Prazo de realização dos serviços"
          value={serviceDeadline}
          onChange={setServiceDeadline}
          disabled={!canManage}
        />
        <FormField
          label="Prazo de validade dos produtos"
          value={productValidity}
          onChange={setProductValidity}
          disabled={!canManage}
        />
      </div>
      <div className="form-grid">
        <FormField
          label="Observações"
          type="textarea"
          value={notes}
          onChange={setNotes}
          className="full"
          disabled={!canManage}
        />
        <FormField
          label="Nota interna"
          type="textarea"
          value={internalNote}
          onChange={setInternalNote}
          className="full"
          disabled={!canManage}
        />
      </div>

      <div className="card" style={{ marginTop: "16px" }}>
        <h4>Assinaturas</h4>
        <div className="form-grid">
          <FormField
            label="Assinatura"
            type="select"
            value={signatureMode}
            options={[
              { value: "none", label: "Sem assinatura" },
              { value: "client", label: "Cliente" },
              { value: "tech", label: "Técnico" },
              { value: "both", label: "Cliente e técnico" }
            ]}
            onChange={setSignatureMode}
            disabled={!canManage}
          />
          <FormField
            label="Escopo"
            type="select"
            value={signatureScope}
            options={[
              { value: "last_page", label: "Assinar apenas no final" },
              { value: "all_pages", label: "Assinar todas as páginas" }
            ]}
            onChange={setSignatureScope}
            disabled={!canManage || signatureMode === "none"}
          />
        </div>

        {signatureMode !== "none" && (
          <div className="grid-2" style={{ marginTop: "12px" }}>
            {(signatureMode === "client" || signatureMode === "both") && (
              <div className="card">
                <strong>Assinatura do cliente</strong>
                <SignaturePad
                  value={signatureClient}
                  onChange={setSignatureClient}
                  disabled={!canManage}
                />
              </div>
            )}
            {(signatureMode === "tech" || signatureMode === "both") && (
              <div className="card">
                <strong>Assinatura do técnico</strong>
                <SignaturePad
                  value={signatureTech}
                  onChange={setSignatureTech}
                  disabled={!canManage}
                />
              </div>
            )}
          </div>
        )}
      </div>

      <div className="list" style={{ marginTop: "16px" }}>
        {items.map((item) => (
          <div key={item.id} className="card">
            <div className="form-grid">
              <FormField
                label="Produto"
                type="select"
                value={item.product_id}
                options={productOptions}
                onChange={(value) => handleProductChange(item.id, value)}
                disabled={!canManage}
              />
              <FormField
                label="Descrição"
                value={item.description}
                onChange={(value) => updateItem(item.id, { description: value })}
                disabled={!canManage}
              />
              <FormField
                label="Quantidade"
                type="number"
                value={item.qty}
                onChange={(value) => updateItem(item.id, { qty: value })}
                disabled={!canManage}
              />
              <FormField
                label="Valor unitário"
                type="number"
                value={item.unit_price}
                onChange={(value) => updateItem(item.id, { unit_price: value })}
                disabled={!canManage}
              />
            </div>
            <div className="inline" style={{ justifyContent: "space-between", marginTop: "10px" }}>
              <small>Total: {formatter.format(item.qty * item.unit_price)}</small>
              {canManage && (
                <button className="btn ghost" type="button" onClick={() => removeItem(item.id)}>
                  Remover item
                </button>
              )}
            </div>
          </div>
        ))}
        <div ref={itemsEndRef} />
      </div>

      <div className="inline" style={{ marginTop: "12px" }}>
        {canManage && (
          <button className="btn secondary" type="button" onClick={addItem}>
            Adicionar item
          </button>
        )}
        <span className="badge">Subtotal: {formatter.format(subtotal)}</span>
        <span className="badge">Total: {formatter.format(total)}</span>
      </div>

      {error && <p className="muted">{error}</p>}
      <div className="inline" style={{ marginTop: "16px" }}>
        <button className="btn primary" type="submit" disabled={!canManage}>
          {canManage ? "Salvar orçamento" : "Somente leitura"}
        </button>
      </div>
    </form>
  );
}
