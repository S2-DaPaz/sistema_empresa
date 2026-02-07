function escapeHtml(value = "") {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const COMPANY = {
  name: "RV DA ROCHA LTDA",
  tagline: "PRODUTOS MÉDICOS E HOSPITALARES",
  phone: "98991545401",
  whatsapp: "9891331000",
  cnpj: "36.105.367/0001-17",
  email: "engtech.life@gmail.com",
  address: "RUA 25 QUADRA 24 CASA 16 COHAJAP 2",
  city: "São Luís",
  instagram: "@RVDAROCHA.LTDA",
  cep: "65.027-740",
  representative: "Robson Victor da Rocha",
  representativeRole: "Diretor Geral"
};

const DEFAULT_CONDITIONS = [
  { label: "Validade da proposta", value: "30 dias" },
  { label: "Condição de pagamento", value: "À vista" },
  { label: "Prazo de realização dos serviços", value: "03 a 04 horas" },
  { label: "Prazo de validade dos produtos", value: "03 meses" }
];

function resolveCondition(value, fallback) {
  return value && String(value).trim() ? value : fallback;
}

function getBudgetConditions(budget) {
  return [
    {
      label: "Validade da proposta",
      value: resolveCondition(budget?.proposal_validity, DEFAULT_CONDITIONS[0].value)
    },
    {
      label: "Condição de pagamento",
      value: resolveCondition(budget?.payment_terms, DEFAULT_CONDITIONS[1].value)
    },
    {
      label: "Prazo de realização dos serviços",
      value: resolveCondition(budget?.service_deadline, DEFAULT_CONDITIONS[2].value)
    },
    {
      label: "Prazo de validade dos produtos",
      value: resolveCondition(budget?.product_validity, DEFAULT_CONDITIONS[3].value)
    }
  ];
}

function formatCurrency(value) {
  const number = Number(value || 0);
  return number.toLocaleString("pt-BR", {
    style: "currency",
    currency: "BRL"
  });
}

function formatAnswer(field, value) {
  if (field.type === "checkbox") return value ? "Sim" : "Não";
  if (field.type === "yesno") {
    if (value === "sim") return "Sim";
    if (value === "nao") return "Não";
    return "-";
  }
  if (value === 0 || value === "0") return "0";
  return value ? escapeHtml(value) : "-";
}

function clampColumns(value) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) return 1;
  return Math.min(Math.max(Math.round(numberValue), 1), 3);
}

function getDocumentLabel(value) {
  const digits = String(value ?? "").replace(/\D/g, "");
  if (digits.length === 11) return "CPF";
  if (digits.length === 14) return "CNPJ";
  return "Documento";
}

function formatDate(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric"
  });
}

function formatCityDate(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) {
    return `${COMPANY.city}, ${value}`;
  }
  const dateText = date.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "long",
    year: "numeric"
  });
  return `${COMPANY.city}, ${dateText}`;
}

function formatMultiline(value) {
  if (!value) return "";
  return escapeHtml(value).replace(/\n/g, "<br />");
}

function buildSignatureHtml(signatureMode, signatureClient, signatureTech, options = {}) {
  if (!signatureMode || signatureMode === "none") return "";
  const order = options.order || ["client", "tech"];
  const clientMeta = [];
  if (options.clientName) {
    clientMeta.push(
      `<div class="signature-meta">Nome: ${escapeHtml(options.clientName)}</div>`
    );
  }
  if (options.clientDocument) {
    clientMeta.push(
      `<div class="signature-meta">CPF: ${escapeHtml(options.clientDocument)}</div>`
    );
  }
  const blocksByRole = {
    client:
      signatureMode === "client" || signatureMode === "both"
        ? `
          <div class="signature-item">
            ${signatureClient ? `<img src="${signatureClient}" alt="Assinatura cliente" />` : ""}
            <div class="signature-line"></div>
            <div class="signature-label">Cliente</div>
            ${clientMeta.join("")}
          </div>
        `
        : "",
    tech:
      signatureMode === "tech" || signatureMode === "both"
        ? `
          <div class="signature-item">
            ${signatureTech ? `<img src="${signatureTech}" alt="Assinatura técnico" />` : ""}
            <div class="signature-line"></div>
            <div class="signature-label">técnico</div>
          </div>
        `
        : ""
  };
  const blocks = order.map((key) => blocksByRole[key]).filter(Boolean);
  return `<div class="signature-block">${blocks.join("")}</div>`;
}

function buildReportPageHtml({ report, task, client, signatureHtml, logoUrl }) {
  const content = report?.content || {};
  const sections = content.sections || [];
  const answers = content.answers || {};
  const photos = content.photos || [];
  const layout = content.layout || {};
  const sectionColumns = clampColumns(layout.sectionColumns);
  const fieldColumns = clampColumns(layout.fieldColumns);
  const reportTitle = report?.title || task?.title || "Relatório";
  const taskTitle = task?.title && task?.title !== reportTitle ? task.title : "";

  const watermarkStyle = "";
  const watermarkHtml = "";

  const metaChips = [
    { label: "Tarefa", value: task?.id ? `#${task.id}` : "-" },
    { label: "Status", value: task?.status || "-" },
    { label: "Prioridade", value: task?.priority || "-" },
    { label: "Início", value: formatDate(task?.start_date) },
    { label: "Fim", value: formatDate(task?.due_date) }
  ];
  if (report?.equipment_name) {
    metaChips.push({ label: "Equipamento", value: report.equipment_name });
  }
  const metaHtml = metaChips
    .map(
      (chip) => `
        <div class="meta-chip">
          <span>${escapeHtml(chip.label)}</span>
          <strong>${escapeHtml(chip.value)}</strong>
        </div>
      `
    )
    .join("");

  const clientRows = [
    { label: "Nome", value: client?.name || "-" },
    { label: "Contato", value: client?.contact || "-" },
    { label: "Endereço", value: client?.address || "-" }
  ];
  if (client?.cnpj) {
    clientRows.push({ label: getDocumentLabel(client.cnpj), value: client.cnpj });
  }
  const clientHtml = clientRows
    .map(
      (row) => `
        <div class="info-row">
          <span>${escapeHtml(row.label)}</span>
          <strong>${escapeHtml(row.value)}</strong>
        </div>
      `
    )
    .join("");

  const taskRows = [
    { label: "Número", value: task?.id ? `#${task.id}` : "-" },
    { label: "Título", value: task?.title || "-" },
    { label: "Status", value: task?.status || "-" },
    { label: "Prioridade", value: task?.priority || "-" },
    { label: "Início", value: formatDate(task?.start_date) },
    { label: "Fim", value: formatDate(task?.due_date) }
  ];
  if (report?.equipment_name) {
    taskRows.push({ label: "Equipamento", value: report.equipment_name });
  }
  const taskHtml = taskRows
    .map(
      (row) => `
        <div class="info-row">
          <span>${escapeHtml(row.label)}</span>
          <strong>${escapeHtml(row.value)}</strong>
        </div>
      `
    )
    .join("");

  const sectionsHtml = sections
    .map((section) => {
      const fields = (section.fields || [])
        .map((field) => {
          const value = formatAnswer(field, answers?.[field.id]);
          return `
            <div class="field-row">
              <span>${escapeHtml(field.label)}</span>
              <strong>${value}</strong>
            </div>
          `;
        })
        .join("");
      const fieldsHtml = fields
        ? `<div class="fields-grid">${fields}</div>`
        : "<p class=\"empty\">-</p>";
      return `
        <div class="section-card">
          <h3>${escapeHtml(section.title || "Seção")}</h3>
          ${fieldsHtml}
        </div>
      `;
    })
    .join("");

  const photosHtml = photos.length
    ? `
      <div class="section-card">
        <h3>Fotos</h3>
        <div class="photo-grid">
          ${photos
            .map(
              (photo) =>
                `<div class="photo"><img src="${photo.dataUrl}" alt="${escapeHtml(photo.name)}" /></div>`
            )
            .join("")}
        </div>
      </div>
    `
    : "";
  const declarationHtml = `
      <div class="section-card declaration-card">
        <h3>Declaração de compromisso</h3>
        <p class="declaration-text">
          Ao assinar esse Relatório, declaro estar ciente dos serviços realizados pelo técnico e
          que o equipamento encontra-se em perfeito estado de funcionamento e autorizamos a
          emissão de notas fiscais e faturas correspondentes a peças, mão de obra e outras
          despesas consignadas neste atendimento.
        </p>
      </div>
    `;
  const footerHtml = `
      <div class="report-footer">
        ${signatureHtml}
        ${declarationHtml}
        ${photosHtml}
      </div>
    `;

  const sectionsContent = sectionsHtml || "<p class=\"empty\">Sem campos cadastrados.</p>";

  return `
    <div class="page report-page" ${watermarkStyle}>
      ${watermarkHtml}
      <div class="report-header">
        <div class="brand-mark">
          ${logoUrl ? `<img src="${logoUrl}" alt="Logo" />` : ""}
        </div>
        <div class="brand-body">
          <div class="report-label">Relatório de tarefas</div>
          <h1>${escapeHtml(reportTitle)}</h1>
          ${taskTitle ? `<p class="report-subtitle">${escapeHtml(taskTitle)}</p>` : ""}
          <div class="meta-row">${metaHtml}</div>
        </div>
        <div class="company-card">
          <div class="company-name">${escapeHtml(COMPANY.name)}</div>
          <div>Telefone: ${escapeHtml(COMPANY.phone)}</div>
          <div>CNPJ: ${escapeHtml(COMPANY.cnpj)}</div>
          <div>E-mail: ${escapeHtml(COMPANY.email)}</div>
          <div>Endereço: ${escapeHtml(COMPANY.address)}</div>
        </div>
      </div>

      <div class="info-grid">
        <div class="info-card">
          <div class="info-title">Cliente</div>
          ${clientHtml}
        </div>
        <div class="info-card">
          <div class="info-title">Tarefa</div>
          ${taskHtml}
        </div>
      </div>

      <div class="section-intro">
        <div class="intro-title">Detalhes do Relatório</div>
        <div class="intro-line"></div>
      </div>

      <div class="report-sections" style="--section-cols: ${sectionColumns}; --field-cols: ${fieldColumns};">
        ${sectionsContent}
      </div>
      ${footerHtml}
    </div>
  `;
}

function buildBudgetItemsHtml(items = []) {
  if (!items.length) {
    return "<tr><td colspan=\"5\">Sem itens</td></tr>";
  }
  return items
    .map(
      (item, index) => `
      <tr>
        <td>${String(index + 1).padStart(2, "0")}</td>
        <td class="budget-desc">${formatMultiline(item.description || "Item")}</td>
        <td>${Number(item.qty || 0)}</td>
        <td>${formatCurrency(item.unit_price)}</td>
        <td>${formatCurrency(item.total)}</td>
      </tr>
    `
    )
    .join("");
}

function formatBudgetStatus(status) {
  const value = String(status || "").toLowerCase();
  switch (value) {
    case "aprovado":
      return "Aprovado";
    case "recusado":
      return "Recusado";
    case "em_andamento":
      return "Em andamento";
    case "enviado":
      return "Enviado";
    case "rascunho":
      return "Rascunho";
    default:
      return value ? value.charAt(0).toUpperCase() + value.slice(1) : "-";
  }
}

function buildBudgetPageHtml({ budget, client, signatureHtml, logoUrl }) {
  const referenceSource =
    budget.report_title || budget.task_title || "Proposta comercial";
  const referenceText = referenceSource.toUpperCase();
  const notes = budget.notes ? formatMultiline(budget.notes) : "-";
  const statusLabel = formatBudgetStatus(budget?.status);
  const signatureBlock = signatureHtml
    ? `<div class="budget-signatures">${signatureHtml}</div>`
    : `
      <div class="budget-signatures">
        <div class="signature-line"></div>
        <div class="signature-name">${escapeHtml(COMPANY.representative)}</div>
        <div class="signature-role">${escapeHtml(COMPANY.representativeRole)}</div>
      </div>
    `;
  const watermarkStyle = logoUrl
    ? `style="--watermark-url: url('${escapeHtml(logoUrl)}')"`
    : "";
  const watermarkHtml = logoUrl
    ? `<div class="watermark"><img src="${logoUrl}" alt="Marca d'água" /></div>`
    : "";
  const conditionsHtml = getBudgetConditions(budget).map(
    (item) => `
      <div class="condition-row">
        <span>${escapeHtml(item.label)}:</span>
        <strong>${escapeHtml(item.value)}</strong>
      </div>
    `
  ).join("");

  return `
    <div class="page budget-page" ${watermarkStyle}>
      ${watermarkHtml}
      <div class="budget-content">
        <div class="budget-header">
          <div class="budget-logo">${logoUrl ? `<img src="${logoUrl}" alt="Logo" />` : ""}</div>
          <div class="budget-title">
            <div class="budget-company">${escapeHtml(COMPANY.name)}</div>
            <div class="budget-tagline">${escapeHtml(COMPANY.tagline)}</div>
          </div>
        </div>

        <div class="budget-meta">
          <div class="budget-date">${formatCityDate(budget.created_at)}</div>
          <div class="budget-status"><span>Status:</span><strong>${escapeHtml(statusLabel)}</strong></div>
        </div>

        <div class="budget-recipient">
          <div class="recipient-name">${escapeHtml(client?.name || "-")}</div>
          <div>A/C: ${escapeHtml(client?.contact || "-")}</div>
          ${client?.cnpj ? `<div>${escapeHtml(getDocumentLabel(client.cnpj))}: ${escapeHtml(client.cnpj)}</div>` : ""}
          ${client?.address ? `<div>Endereço: ${escapeHtml(client.address)}</div>` : ""}
        </div>

        <div class="budget-ref"><strong>REF.:</strong> ${escapeHtml(referenceText)}</div>

        <p class="budget-text">Prezados Senhores,</p>
        <p class="budget-text">Apresentamos nossa melhor proposta para fornecimento dos seguintes itens:</p>

        <table class="budget-table">
          <thead>
            <tr>
              <th>ITEM</th>
              <th>DISCRIMINAÇÃO</th>
              <th>QTD</th>
              <th>UNIT</th>
              <th>TOTAL</th>
            </tr>
          </thead>
          <tbody>
            ${buildBudgetItemsHtml(budget.items || [])}
          </tbody>
          <tfoot>
            <tr>
              <td colspan="4" class="total-label">VALOR TOTAL</td>
              <td class="total-value">${formatCurrency(budget.total)}</td>
            </tr>
          </tfoot>
        </table>

        <div class="budget-notes">
          <div class="notes-title">OBSERVAÇÕES:</div>
          <div class="notes-body">${notes}</div>
        </div>

        <div class="budget-conditions">
          ${conditionsHtml}
        </div>

        <div class="budget-signoff">Atenciosamente,</div>
        ${signatureBlock}

        <div class="budget-footer">
          <div>${escapeHtml(COMPANY.address)} - ${escapeHtml(COMPANY.city)} - MA CEP: ${escapeHtml(COMPANY.cep)}</div>
          <div>FONE/WHATSAPP: ${escapeHtml(COMPANY.phone)} - ${escapeHtml(COMPANY.whatsapp)}</div>
          <div>INSTAGRAM: ${escapeHtml(COMPANY.instagram)} | CNPJ: ${escapeHtml(COMPANY.cnpj)}</div>
        </div>
      </div>
    </div>
  `;
}

export function buildTaskPdfHtml({
  task,
  client,
  reports = [],
  budgets = [],
  signatureMode,
  signatureScope,
  signatureClient,
  signatureTech,
  signaturePages = {},
  logoUrl
}) {
  const pages = [
    ...reports.map((report) => ({ type: "report", data: report })),
    ...budgets.map((budget) => ({ type: "budget", data: budget }))
  ];
  const lastIndex = pages.length - 1;
  const baseReportSignatureHtml = buildSignatureHtml(
    signatureMode,
    signatureClient,
    signatureTech,
    { order: ["client", "tech"] }
  );
  const baseBudgetSignatureHtml = buildSignatureHtml(
    signatureMode,
    signatureClient,
    signatureTech,
    { order: ["tech", "client"] }
  );

  const bodyHtml = pages
    .map((page, index) => {
      const includeSignature =
        signatureMode !== "none" && (signatureScope === "all_pages" || index === lastIndex);
      let signatureHtml = "";
      if (includeSignature) {
        const order = page.type === "budget" ? ["tech", "client"] : ["client", "tech"];
        if (signatureScope === "all_pages") {
          const pageKey =
            page.type === "report"
              ? `report:${page.data.id}`
              : `budget:${page.data.id}`;
          const pageSignature = signaturePages?.[pageKey] || {};
          signatureHtml = buildSignatureHtml(
            signatureMode,
            pageSignature.client,
            pageSignature.tech,
            { order }
          );
        } else {
          signatureHtml = page.type === "budget" ? baseBudgetSignatureHtml : baseReportSignatureHtml;
        }
      }
      if (page.type === "report") {
        return buildReportPageHtml({
          report: page.data,
          task,
          client,
          signatureHtml,
          logoUrl
        });
      }
      return buildBudgetPageHtml({
        budget: page.data,
        client,
        signatureHtml,
        logoUrl
      });
    })
    .join("");

  return `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8" />
<title>${escapeHtml(task?.title || "Tarefa")}</title>
<style>
  @page { size: A4; margin: 14mm; }
  * { box-sizing: border-box; }
  body { font-family: "Helvetica Neue", Arial, sans-serif; color: #0c1b2a; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .page { page-break-after: always; padding: 8mm; min-height: 260mm; box-sizing: border-box; display: flex; flex-direction: column; gap: 14px; }
  .page:last-child { page-break-after: auto; }
  .report-page { position: relative; overflow: hidden; }
  .report-page > *:not(.watermark) { position: relative; z-index: 1; }
  .watermark { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; pointer-events: none; z-index: 0; opacity: 0.16; }
  .watermark img { width: 85%; height: auto; max-height: 85%; object-fit: contain; }
  .report-page .watermark { opacity: 0.14; }
  .budget-page .watermark { opacity: 0.16; }
  .page-header { display: flex; justify-content: space-between; gap: 16px; border-bottom: 1px solid #d7dde6; padding-bottom: 12px; margin-bottom: 16px; }
  .page-header h1 { margin: 0 0 6px; font-size: 20px; }
  .page-header p { margin: 2px 0; font-size: 12px; color: #50607b; }
  .logo { width: 120px; height: auto; object-fit: contain; }
  .report-header { display: grid; grid-template-columns: 96px 1fr 220px; gap: 12px; align-items: center; padding: 12px; border-radius: 16px; border: 1px solid #d9e2ee; background: #f7fafe; page-break-inside: avoid; }
  .brand-mark { width: 96px; height: 96px; background: #ffffff; border-radius: 16px; border: 1px solid #d9e2ee; display: flex; align-items: center; justify-content: center; }
  .brand-mark img { width: 92px; height: 92px; object-fit: contain; }
  .brand-body h1 { margin: 4px 0; font-size: 20px; }
  .report-label { font-size: 10px; text-transform: uppercase; letter-spacing: 0.1em; color: #50607b; }
  .report-subtitle { margin: 0; font-size: 12px; color: #50607b; }
  .meta-row { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
  .meta-chip { display: inline-flex; gap: 6px; align-items: baseline; padding: 4px 8px; border-radius: 999px; background: #ffffff; border: 1px solid #d9e2ee; font-size: 10px; }
  .meta-chip span { color: #6b7a92; }
  .meta-chip strong { color: #0c1b2a; }
  .company-card { background: #ffffff; border-radius: 12px; border: 1px solid #d9e2ee; padding: 8px 10px; font-size: 10px; color: #50607b; line-height: 1.4; }
  .company-name { font-weight: 700; font-size: 11px; color: #0c1b2a; margin-bottom: 4px; }
  .info-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .info-card { background: #fbfdff; border: 1px solid #e1e6ef; border-radius: 12px; padding: 10px 12px; page-break-inside: avoid; }
  .info-title { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: #2a67f1; margin-bottom: 6px; }
  .info-row { display: grid; grid-template-columns: 110px 1fr; gap: 8px; font-size: 11px; padding: 3px 0; border-bottom: 1px dashed #e1e6ef; }
  .info-row:last-child { border-bottom: none; }
  .info-row span { color: #6b7a92; }
  .section-intro { display: flex; align-items: center; gap: 12px; margin-top: 4px; }
  .intro-title { font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; color: #17304f; }
  .intro-line { flex: 1; height: 1px; background: linear-gradient(90deg, rgba(26, 167, 214, 0.6), rgba(20, 194, 163, 0.2)); }
  .section-card { background: #ffffff; border: 1px solid #d7e0ec; border-left: 4px solid #1aa7d6; border-radius: 12px; padding: 12px 14px; page-break-inside: avoid; }
  .section-card h3 { margin: -12px -14px 10px; padding: 8px 14px; font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; color: #17304f; background: #eef4fb; border-bottom: 1px solid #d7e0ec; border-top-left-radius: 10px; border-top-right-radius: 10px; }
  .report-sections { display: grid; grid-template-columns: repeat(var(--section-cols, 1), minmax(0, 1fr)); gap: 12px; }
  .fields-grid { display: grid; grid-template-columns: repeat(var(--field-cols, 1), minmax(0, 1fr)); gap: 10px; }
  .report-sections .empty { grid-column: 1 / -1; }
  .field-row { display: grid; grid-template-columns: 170px 1fr; gap: 10px; font-size: 11px; padding: 4px 0; border-bottom: 1px dashed #e1e6ef; }
  .field-row:last-child { border-bottom: none; }
  .photo-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .photo { border: 1px solid #e3e8f0; border-radius: 8px; background: #fff; padding: 4px; page-break-inside: avoid; }
  .photo img { width: 100%; height: auto; max-height: 180px; object-fit: contain; border-radius: 6px; display: block; }
  .empty { color: #6b7a92; font-size: 12px; }
  .declaration-card { border-left-color: #14c2a3; }
  .declaration-text { margin: 0; font-size: 11px; line-height: 1.5; color: #1f2f44; }
  table.items { width: 100%; border-collapse: collapse; font-size: 12px; margin-bottom: 16px; }
  table.items th, table.items td { border-bottom: 1px solid #e1e6ef; padding: 6px; text-align: left; }
  table.items th { background: #f3f6fb; color: #23324a; }
  .totals { display: grid; gap: 6px; justify-content: flex-end; font-size: 12px; }
  .totals div { display: flex; gap: 16px; justify-content: space-between; min-width: 200px; }
  .totals .total { font-weight: bold; font-size: 14px; }
  .report-footer { margin-top: 12px; display: grid; gap: 12px; page-break-inside: avoid; }
  .signature-block { display: grid; gap: 24px; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); align-items: end; }
  .signature-item { display: flex; flex-direction: column; justify-content: flex-end; min-height: 120px; }
  .signature-item img { width: 100%; height: 60px; object-fit: contain; }
  .signature-line { border-top: 1px solid #3e4b63; margin-top: 8px; }
  .signature-label { font-size: 11px; color: #50607b; margin-top: 4px; text-transform: uppercase; letter-spacing: 0.04em; }
  .signature-meta { font-size: 10px; color: #50607b; margin-top: 2px; }
  .report-footer .signature-item { min-height: 180px; }
  .report-footer .signature-item img { height: 90px; }
  .report-footer .signature-line { margin-top: 16px; }

  .budget-page { position: relative; border: 1px solid #1aa7d6; border-radius: 18px; padding: 12mm; background: #ffffff; overflow: hidden; }
  .budget-page > *:not(.watermark) { position: relative; z-index: 1; }
  .budget-content { position: relative; z-index: 1; display: flex; flex-direction: column; gap: 14px; }
  .budget-header { display: flex; align-items: center; gap: 14px; }
  .budget-logo { width: 84px; height: 84px; border-radius: 14px; border: 1px solid #d9e2ee; display: flex; align-items: center; justify-content: center; background: #ffffff; }
  .budget-logo img { width: 80px; height: 80px; object-fit: contain; }
  .budget-title { display: flex; flex-direction: column; gap: 2px; }
  .budget-company { font-size: 18px; font-weight: 700; color: #0c1b2a; }
  .budget-tagline { font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; color: #607088; }
  .budget-meta { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
  .budget-date { font-size: 11px; color: #50607b; }
  .budget-status { font-size: 11px; padding: 4px 8px; border-radius: 8px; border: 1px solid #d9e2ee; background: #f4f8fd; color: #1c2b3a; }
  .budget-status span { color: #607088; margin-right: 4px; }
  .budget-recipient { font-size: 11px; line-height: 1.5; }
  .recipient-name { font-weight: 700; font-size: 12px; }
  .budget-ref { font-size: 11px; font-weight: 700; padding-top: 4px; border-top: 1px solid #d9e2ee; }
  .budget-text { font-size: 11px; margin: 0; color: #324156; }
  .budget-table { width: 100%; border-collapse: collapse; font-size: 11px; }
  .budget-table th, .budget-table td { border: 1px solid #d9e2ee; padding: 6px; vertical-align: top; }
  .budget-table th { background: #f1f6fb; text-transform: uppercase; letter-spacing: 0.06em; font-size: 10px; }
  .budget-table .budget-desc { min-width: 280px; }
  .budget-table th:nth-child(1), .budget-table td:nth-child(1) { text-align: center; width: 40px; }
  .budget-table th:nth-child(3), .budget-table td:nth-child(3) { text-align: right; width: 60px; }
  .budget-table th:nth-child(4), .budget-table td:nth-child(4),
  .budget-table th:nth-child(5), .budget-table td:nth-child(5) { text-align: right; width: 90px; }
  .budget-table tfoot td { font-weight: 700; background: #f8fbff; }
  .budget-table .total-label { text-align: right; }
  .budget-table .total-value { text-align: right; }
  .budget-notes { font-size: 11px; border-top: 1px solid #d9e2ee; padding-top: 8px; }
  .notes-title { font-weight: 700; margin-bottom: 4px; }
  .notes-body { color: #324156; }
  .budget-conditions { display: grid; gap: 6px; font-size: 11px; margin-top: 6px; }
  .condition-row { display: flex; justify-content: space-between; border-bottom: 1px dashed #e1e6ef; padding-bottom: 4px; }
  .condition-row span { color: #50607b; }
  .budget-signoff { font-size: 11px; margin-top: 8px; }
  .budget-signatures { margin-top: 6px; }
  .budget-signatures .signature-block { margin-top: 0; }
  .budget-signatures .signature-block { margin-top: 0; }
  .signature-name { font-size: 11px; font-weight: 700; margin-top: 4px; }
  .signature-role { font-size: 10px; color: #50607b; }
  .budget-footer { font-size: 10px; text-align: center; color: #50607b; margin-top: auto; border-top: 1px solid #d9e2ee; padding-top: 8px; }
</style>
</head>
<body>
  ${bodyHtml || "<p>Sem dados para exportar.</p>"}
</body>
</html>`;
}

export function buildBudgetPdfHtml({
  budget,
  client,
  signatureMode = "none",
  signatureScope = "last_page",
  signatureClient = "",
  signatureTech = "",
  signaturePages = {},
  logoUrl
}) {
  const signatureOptions = {
    order: ["tech", "client"],
    clientName: budget?.signature_client_name,
    clientDocument: budget?.signature_client_document
  };
  const baseSignatureHtml = buildSignatureHtml(
    signatureMode,
    signatureClient,
    signatureTech,
    signatureOptions
  );
  const pageKey = `budget_${budget?.id ?? "new"}`;
  const pageSignature = signaturePages?.[pageKey] || {};
  const scopedSignatureHtml =
    signatureScope === "all_pages"
      ? buildSignatureHtml(
          signatureMode,
          pageSignature.client,
          pageSignature.tech,
          signatureOptions
        ) || baseSignatureHtml
      : baseSignatureHtml;
  return `<!doctype html>
  <html lang="pt-BR">
  <head>
<meta charset="utf-8" />
<title>Orçamento #${budget.id}</title>
<style>
  @page { size: A4; margin: 14mm; }
  * { box-sizing: border-box; }
  body { font-family: "Helvetica Neue", Arial, sans-serif; color: #0c1b2a; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .page { padding: 8mm; min-height: 260mm; box-sizing: border-box; display: flex; flex-direction: column; gap: 14px; }
  .budget-page { position: relative; border: 1px solid #1aa7d6; border-radius: 18px; padding: 12mm; background: #ffffff; overflow: hidden; }
  .budget-page > *:not(.watermark) { position: relative; z-index: 1; }
  .watermark { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; pointer-events: none; z-index: 0; opacity: 0.16; }
  .watermark img { width: 85%; height: auto; max-height: 85%; object-fit: contain; }
  .budget-content { position: relative; z-index: 1; display: flex; flex-direction: column; gap: 14px; }
  .budget-header { display: flex; align-items: center; gap: 14px; }
  .budget-logo { width: 84px; height: 84px; border-radius: 14px; border: 1px solid #d9e2ee; display: flex; align-items: center; justify-content: center; background: #ffffff; }
  .budget-logo img { width: 80px; height: 80px; object-fit: contain; }
  .budget-title { display: flex; flex-direction: column; gap: 2px; }
  .budget-company { font-size: 18px; font-weight: 700; color: #0c1b2a; }
  .budget-tagline { font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; color: #607088; }
  .budget-meta { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
  .budget-date { font-size: 11px; color: #50607b; }
  .budget-status { font-size: 11px; padding: 4px 8px; border-radius: 8px; border: 1px solid #d9e2ee; background: #f4f8fd; color: #1c2b3a; }
  .budget-status span { color: #607088; margin-right: 4px; }
  .budget-recipient { font-size: 11px; line-height: 1.5; }
  .recipient-name { font-weight: 700; font-size: 12px; }
  .budget-ref { font-size: 11px; font-weight: 700; padding-top: 4px; border-top: 1px solid #d9e2ee; }
  .budget-text { font-size: 11px; margin: 0; color: #324156; }
  .budget-table { width: 100%; border-collapse: collapse; font-size: 11px; }
  .budget-table th, .budget-table td { border: 1px solid #d9e2ee; padding: 6px; vertical-align: top; }
  .budget-table th { background: #f1f6fb; text-transform: uppercase; letter-spacing: 0.06em; font-size: 10px; }
  .budget-table .budget-desc { min-width: 280px; }
  .budget-table th:nth-child(1), .budget-table td:nth-child(1) { text-align: center; width: 40px; }
  .budget-table th:nth-child(3), .budget-table td:nth-child(3) { text-align: right; width: 60px; }
  .budget-table th:nth-child(4), .budget-table td:nth-child(4),
  .budget-table th:nth-child(5), .budget-table td:nth-child(5) { text-align: right; width: 90px; }
  .budget-table tfoot td { font-weight: 700; background: #f8fbff; }
  .budget-table .total-label { text-align: right; }
  .budget-table .total-value { text-align: right; }
  .budget-notes { font-size: 11px; border-top: 1px solid #d9e2ee; padding-top: 8px; }
  .notes-title { font-weight: 700; margin-bottom: 4px; }
  .notes-body { color: #324156; }
  .budget-conditions { display: grid; gap: 6px; font-size: 11px; margin-top: 6px; }
  .condition-row { display: flex; justify-content: space-between; border-bottom: 1px dashed #e1e6ef; padding-bottom: 4px; }
  .condition-row span { color: #50607b; }
  .budget-signoff { font-size: 11px; margin-top: 8px; }
  .budget-signatures { margin-top: 6px; }
  .signature-block { display: grid; gap: 24px; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); align-items: end; }
  .signature-item img { width: 100%; height: 60px; object-fit: contain; }
  .signature-label { font-size: 11px; color: #50607b; margin-top: 4px; text-transform: uppercase; letter-spacing: 0.04em; }
  .signature-line { border-top: 1px solid #3e4b63; margin-top: 8px; }
  .signature-name { font-size: 11px; font-weight: 700; margin-top: 4px; }
  .signature-role { font-size: 10px; color: #50607b; }
  .budget-footer { font-size: 10px; text-align: center; color: #50607b; margin-top: auto; border-top: 1px solid #d9e2ee; padding-top: 8px; }
</style>
</head>
<body>
    ${buildBudgetPageHtml({ budget, client, signatureHtml: scopedSignatureHtml, logoUrl })}
  </body>
  </html>`;
}

export function buildBudgetEmailText(budget, client) {
  const lines = [];
  lines.push(`Orçamento #${budget.id}`);
  if (client?.name) lines.push(`Cliente: ${client.name}`);
  lines.push("");
  (budget.items || []).forEach((item) => {
    lines.push(
      `- ${item.description}: ${item.qty} x ${item.unit_price} = ${item.total}`
    );
  });
  lines.push("");
  lines.push(`Total: ${budget.total || 0}`);
  return lines.join("\n");
}

export function openPrintWindow(html) {
  const printWindow = window.open("", "_blank");
  if (!printWindow) return;
  printWindow.document.write(html);
  printWindow.document.close();
  printWindow.focus();
  printWindow.print();
}


