function escapeHtml(value = "") {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escapeHtmlAttribute(value = "") {
  return escapeHtml(value);
}

function normalizePublicStatusLabel(status) {
  if (!status) return null;
  const value = String(status).toLowerCase();
  switch (value) {
    case "aprovado":
      return { text: "Aprovado", variant: "success" };
    case "em_andamento":
      return { text: "Em andamento", variant: "warning" };
    case "recusado":
      return { text: "Recusado", variant: "danger" };
    case "enviado":
      return { text: "Enviado", variant: "info" };
    case "rascunho":
      return { text: "Rascunho", variant: "neutral" };
    case "concluida":
    case "concluido":
      return { text: "Concluido", variant: "success" };
    case "aberta":
      return { text: "Aberta", variant: "info" };
    default:
      return { text: value || "-", variant: "neutral" };
  }
}

function formatPublicDate(value, options = {}) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat(
    "pt-BR",
    options.withTime
      ? { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }
      : { day: "2-digit", month: "short", year: "numeric" }
  ).format(date);
}

function formatPublicCurrency(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return "-";
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    minimumFractionDigits: 2
  }).format(numeric);
}

function resolveSignatureState({ signatureMode, signatureClient, actionLabel }) {
  if (signatureClient) {
    return {
      badgeText: "Concluida",
      badgeVariant: "success",
      title: "Assinatura registrada",
      message:
        "Este documento ja possui uma assinatura registrada. Revise o conteudo e use as acoes rapidas se precisar compartilhar ou baixar o PDF."
    };
  }

  if (signatureMode && signatureMode !== "none") {
    return {
      badgeText: "Pendente",
      badgeVariant: "warning",
      title: "Assinatura pendente",
      message: `Leia o documento com calma e use "${actionLabel}" quando estiver tudo correto.`
    };
  }

  return {
    badgeText: "Disponivel",
    badgeVariant: "info",
    title: "Confirmacao disponivel",
    message: `Se precisar formalizar este envio, use "${actionLabel}" para registrar a confirmacao.`
  };
}

function renderMetricCards(metrics = []) {
  if (!metrics.length) return "";
  return metrics
    .map(
      (metric) => `
        <article class="public-metric-card">
          <strong>${escapeHtml(metric.value ?? "-")}</strong>
          <span>${escapeHtml(metric.label || "")}</span>
          ${metric.helper ? `<small>${escapeHtml(metric.helper)}</small>` : ""}
        </article>
      `
    )
    .join("");
}

function renderDetailRows(details = []) {
  const items = details.filter((item) => item && item.value);
  if (!items.length) {
    return `<div class="public-empty-copy">Nenhum detalhe adicional disponivel.</div>`;
  }

  return `
    <dl class="public-detail-list">
      ${items
        .map(
          (item) => `
            <div class="public-detail-row">
              <dt>${escapeHtml(item.label || "")}</dt>
              <dd>${escapeHtml(item.value || "-")}</dd>
            </div>
          `
        )
        .join("")}
    </dl>
  `;
}

function renderStatusChips({ status, signatureState }) {
  const chips = [];
  if (status) {
    chips.push(
      `<span class="public-chip public-chip--${status.variant}">${escapeHtml(status.text)}</span>`
    );
  }
  if (signatureState) {
    chips.push(
      `<span class="public-chip public-chip--${signatureState.badgeVariant}">Assinatura ${escapeHtml(signatureState.badgeText)}</span>`
    );
  }
  chips.push('<span class="public-chip public-chip--neutral">Link seguro</span>');
  return chips.join("");
}

function renderPrimaryAction({ approveBudget, approveReport, actionLabel }) {
  if (!approveBudget && !approveReport) return "";
  return `<button class="public-button public-button--primary" type="button" onclick="openApproval()">${escapeHtml(actionLabel)}</button>`;
}

function renderQuickActions({ pdfUrl, pdfDownloadUrl, refreshUrl, hasApproval }) {
  const actions = [
    hasApproval
      ? `<button class="public-button public-button--ghost" type="button" onclick="openApproval()">Assinatura</button>`
      : "",
    pdfUrl
      ? `<button class="public-button public-button--secondary" type="button" onclick="sharePdf()">Compartilhar PDF</button>`
      : "",
    pdfDownloadUrl
      ? `<button class="public-button public-button--secondary" type="button" onclick="downloadPdf()">Baixar PDF</button>`
      : "",
    `<button class="public-button public-button--ghost" type="button" onclick="window.print()">Imprimir</button>`,
    `<a class="public-button public-button--ghost" href="${escapeHtmlAttribute(refreshUrl)}">Atualizar</a>`
  ].filter(Boolean);

  return actions.join("");
}

function renderApprovalModal({ actionLabel, showRemoveAction }) {
  return `
    <div class="public-overlay" id="approval-overlay" aria-hidden="true">
      <div class="public-modal" role="dialog" aria-modal="true" aria-labelledby="approval-title">
        <div class="public-modal-header">
          <div>
            <span class="public-eyebrow">Confirmacao</span>
            <h2 id="approval-title">${escapeHtml(actionLabel)}</h2>
            <p>Preencha os dados opcionais abaixo e assine no quadro para concluir esta etapa.</p>
          </div>
          <button class="public-button public-button--ghost" type="button" onclick="closeApproval()">Fechar</button>
        </div>
        <div id="approval-feedback" class="public-inline-feedback" hidden></div>
        <div class="public-form-grid">
          <label class="public-field">
            <span>Nome do responsavel</span>
            <input id="approval-name" type="text" placeholder="Opcional" />
          </label>
          <label class="public-field">
            <span>CPF ou CNPJ</span>
            <input id="approval-document" type="text" placeholder="Opcional" />
          </label>
        </div>
        <div class="public-signature-card">
          <div class="public-signature-copy">
            <strong>Assinatura</strong>
            <p>Assine com o dedo, mouse ou caneta. Se algo sair errado, use "Limpar" e tente novamente.</p>
          </div>
          <canvas id="approval-canvas"></canvas>
        </div>
        <div class="public-modal-actions">
          <button class="public-button public-button--ghost" type="button" onclick="clearApproval()">Limpar</button>
          ${showRemoveAction ? `<button class="public-button public-button--danger" type="button" onclick="removeApproval()">Remover assinatura</button>` : ""}
          <button class="public-button public-button--ghost" type="button" onclick="closeApproval()">Cancelar</button>
          <button class="public-button public-button--primary" id="approval-submit" type="button" onclick="submitApproval()">${escapeHtml(actionLabel)}</button>
        </div>
      </div>
    </div>
  `;
}

function buildPublicHeadExtra() {
  return `
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Sora:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root{--public-primary:#245BEB;--public-primary-dark:#1B46C5;--public-primary-soft:#EDF4FF;--public-secondary:#14C2A3;--public-background:#F7F9FC;--public-background-alt:#F2F5FA;--public-ink:#121826;--public-muted:#5B6475;--public-border:#E4EAF3;--public-success:#12B76A;--public-warning:#F79009;--public-danger:#F04438;--public-info:#2E90FA;--public-shadow:0 18px 40px rgba(18,24,38,.08);--public-radius-lg:24px;--public-radius-md:18px}
  *{box-sizing:border-box}body.public-body{margin:0;min-height:100vh;font-family:"Sora",sans-serif;color:var(--public-ink);background:radial-gradient(circle at top left,rgba(36,91,235,.14),transparent 32%),radial-gradient(circle at top right,rgba(20,194,163,.14),transparent 24%),linear-gradient(180deg,#fbfcff 0%,var(--public-background) 52%,var(--public-background-alt) 100%)}
  .public-root{min-height:100vh;padding:24px}.public-shell{width:min(1240px,100%);margin:0 auto;display:grid;gap:20px}.public-hero,.public-section,.public-panel,.public-feedback{border:1px solid var(--public-border);background:rgba(255,255,255,.92);box-shadow:var(--public-shadow);border-radius:var(--public-radius-lg);backdrop-filter:blur(18px)}
  .public-hero{padding:24px;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:20px;align-items:center}.public-hero-copy{display:flex;gap:18px;align-items:flex-start}.public-brand-mark{width:72px;height:72px;flex:0 0 72px;border-radius:22px;display:flex;align-items:center;justify-content:center;background:linear-gradient(180deg,var(--public-primary),var(--public-primary-dark));color:#fff;box-shadow:0 18px 30px rgba(36,91,235,.22);overflow:hidden}.public-brand-mark img{width:100%;height:100%;object-fit:contain;padding:10px;background:#fff}.public-brand-mark span{font-family:"Space Grotesk",sans-serif;font-size:28px;font-weight:700;letter-spacing:-.04em}
  .public-eyebrow,.public-section-eyebrow{display:inline-flex;align-items:center;gap:6px;margin-bottom:10px;color:var(--public-primary);font-size:12px;font-weight:600;letter-spacing:.08em;text-transform:uppercase}.public-hero h1,.public-section h2,.public-panel h2,.public-modal h2,.public-error-shell h1{margin:0;font-family:"Space Grotesk",sans-serif;color:var(--public-ink)}.public-hero h1{font-size:clamp(28px,4vw,42px);line-height:1.04;letter-spacing:-.04em}.public-hero p,.public-section p,.public-panel p,.public-modal p,.public-error-shell p{margin:0;color:var(--public-muted);line-height:1.6}
  .public-chip-row{margin-top:16px;display:flex;flex-wrap:wrap;gap:10px}.public-chip{display:inline-flex;align-items:center;justify-content:center;min-height:36px;padding:0 14px;border-radius:999px;font-size:13px;font-weight:600;border:1px solid var(--public-border);background:#fff;color:var(--public-ink)}.public-chip--success{background:rgba(18,183,106,.1);color:#0e7a4e;border-color:rgba(18,183,106,.18)}.public-chip--warning{background:rgba(247,144,9,.12);color:#9a5a00;border-color:rgba(247,144,9,.18)}.public-chip--danger{background:rgba(240,68,56,.1);color:#b42318;border-color:rgba(240,68,56,.16)}.public-chip--info{background:rgba(36,91,235,.1);color:var(--public-primary-dark);border-color:rgba(36,91,235,.16)}.public-chip--neutral{background:var(--public-primary-soft);color:var(--public-ink)}
  .public-hero-actions{display:grid;gap:12px;justify-items:end;min-width:min(100%,320px)}.public-hero-meta{max-width:280px;text-align:right;font-size:13px;color:var(--public-muted)}.public-main{display:grid;grid-template-columns:minmax(0,1fr) 320px;gap:20px;align-items:start}.public-main-column,.public-sidebar{display:grid;gap:20px}.public-section,.public-panel{padding:22px}.public-section-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-start;margin-bottom:18px}
  .public-metric-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin-bottom:18px}.public-metric-card{padding:18px;border-radius:var(--public-radius-md);background:linear-gradient(180deg,var(--public-primary-soft),#fff);border:1px solid rgba(36,91,235,.08);display:grid;gap:6px}.public-metric-card strong{font-family:"Space Grotesk",sans-serif;font-size:clamp(22px,3vw,28px);line-height:1;letter-spacing:-.04em}.public-metric-card span{font-size:13px;font-weight:600}.public-metric-card small,.public-empty-copy{color:var(--public-muted);line-height:1.5}
  .public-detail-card{padding:18px;border:1px solid var(--public-border);border-radius:var(--public-radius-md);background:#fff}.public-detail-list{margin:0;display:grid;gap:14px}.public-detail-row{display:grid;gap:6px;padding-bottom:14px;border-bottom:1px solid rgba(228,234,243,.88)}.public-detail-row:last-child{padding-bottom:0;border-bottom:none}.public-detail-row dt{font-size:12px;font-weight:600;color:var(--public-muted);text-transform:uppercase;letter-spacing:.06em}.public-detail-row dd{margin:0;font-size:15px;color:var(--public-ink)}
  .public-preview-header{display:grid;gap:6px;margin-bottom:18px}.document-preview{display:grid;gap:16px}.document-preview .page{overflow:hidden;border-radius:var(--public-radius-lg);background:#fff;box-shadow:0 18px 34px rgba(18,24,38,.08)}.document-preview>p{margin:0;padding:28px;border-radius:var(--public-radius-md);border:1px dashed var(--public-border);background:#fff;color:var(--public-muted)}
  .public-button{appearance:none;border:1px solid transparent;border-radius:16px;min-height:48px;padding:0 16px;display:inline-flex;align-items:center;justify-content:center;gap:8px;text-decoration:none;font-family:"Sora",sans-serif;font-size:14px;font-weight:600;cursor:pointer;transition:transform .18s ease,box-shadow .18s ease,border-color .18s ease,background .18s ease}.public-button:hover{transform:translateY(-1px)}.public-button--primary{color:#fff;background:linear-gradient(180deg,var(--public-primary),var(--public-primary-dark));box-shadow:0 16px 28px rgba(36,91,235,.28)}.public-button--secondary{color:var(--public-primary-dark);background:var(--public-primary-soft);border-color:rgba(36,91,235,.14)}.public-button--ghost{color:var(--public-ink);background:#fff;border-color:var(--public-border)}.public-button--danger{color:#b42318;background:rgba(240,68,56,.08);border-color:rgba(240,68,56,.16)}.public-button[disabled]{opacity:.56;cursor:not-allowed;transform:none;box-shadow:none}
  .public-action-grid{display:grid;gap:10px}.public-feedback{padding:14px 18px;display:flex;align-items:center;justify-content:space-between;gap:12px;font-size:14px}.public-feedback[hidden],.public-inline-feedback[hidden]{display:none!important}.public-feedback--success,.public-inline-feedback--success{border-color:rgba(18,183,106,.16);background:rgba(18,183,106,.1);color:#0e7a4e}.public-feedback--error,.public-inline-feedback--error{border-color:rgba(240,68,56,.16);background:rgba(240,68,56,.1);color:#b42318}.public-feedback--info,.public-inline-feedback--info{border-color:rgba(36,91,235,.14);background:rgba(36,91,235,.08);color:var(--public-primary-dark)}
  .public-inline-feedback{padding:12px 14px;border-radius:16px;border:1px solid transparent;font-size:14px}.public-overlay{position:fixed;inset:0;display:none;align-items:center;justify-content:center;padding:20px;background:rgba(18,24,38,.56);z-index:30}.public-overlay.active{display:flex}.public-modal{width:min(720px,100%);max-height:calc(100vh - 40px);overflow:auto;padding:22px;display:grid;gap:18px;border-radius:28px;background:#fff;border:1px solid var(--public-border);box-shadow:0 30px 60px rgba(18,24,38,.2)}.public-modal-header{display:flex;justify-content:space-between;gap:16px;align-items:flex-start}
  .public-form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.public-field{display:grid;gap:8px}.public-field span{font-size:12px;font-weight:600;color:var(--public-muted);text-transform:uppercase;letter-spacing:.06em}.public-field input,.public-signature-card canvas{width:100%;border-radius:18px;border:1px solid var(--public-border);background:var(--public-background)}.public-field input{min-height:52px;padding:0 16px;font-family:inherit;font-size:15px;color:var(--public-ink)}.public-signature-card{display:grid;gap:14px;padding:18px;border:1px solid var(--public-border);border-radius:22px;background:linear-gradient(180deg,#fff,var(--public-background))}.public-signature-copy{display:grid;gap:6px}.public-signature-card canvas{min-height:240px;background:#fff;touch-action:none}.public-modal-actions{display:flex;gap:10px;justify-content:flex-end;flex-wrap:wrap}
  .public-button:focus-visible,.public-field input:focus-visible,.public-signature-card canvas:focus-visible,.document-preview a:focus-visible{outline:3px solid rgba(36,91,235,.22);outline-offset:2px}
  @media (max-width:1024px){.public-main{grid-template-columns:1fr}.public-sidebar{order:3}}@media (max-width:720px){.public-root{padding:16px}.public-hero{grid-template-columns:1fr;padding:20px}.public-hero-copy{flex-direction:column}.public-hero-actions{justify-items:stretch;min-width:0}.public-hero-meta{max-width:none;text-align:left}.public-metric-grid,.public-form-grid{grid-template-columns:1fr}.public-section,.public-panel{padding:18px}.public-modal{padding:18px;border-radius:24px}.public-modal-actions{justify-content:stretch}.public-modal-actions .public-button{width:100%}}
  @media print{body.public-body{background:#fff!important}.public-root{padding:0!important}.public-chrome,.public-overlay{display:none!important}.public-shell,.public-main,.public-main-column{width:100%!important;max-width:none!important;display:block!important;margin:0!important;gap:0!important}.document-preview{gap:0!important}.document-preview .page{box-shadow:none!important;border-radius:0!important}}
</style>`;
}

function buildPublicScript() {
  return `
<script>
  let canvas; let ctx; let drawing = false; let hasDrawing = false;
  function setFeedback(targetId,message,tone){const node=document.getElementById(targetId);if(!node)return;node.hidden=false;node.className=targetId==='public-feedback'?'public-feedback public-feedback--'+tone:'public-inline-feedback public-inline-feedback--'+tone;node.textContent=message;}
  function clearFeedback(targetId){const node=document.getElementById(targetId);if(!node)return;node.hidden=true;node.textContent='';}
  function setButtonBusy(buttonId,busy,busyLabel){const button=document.getElementById(buttonId);if(!button)return;if(!button.dataset.defaultLabel){button.dataset.defaultLabel=button.textContent;}button.disabled=busy;button.textContent=busy?busyLabel:button.dataset.defaultLabel;}
  function openApproval(){clearFeedback('approval-feedback');const overlay=document.getElementById('approval-overlay');if(!overlay)return;overlay.classList.add('active');overlay.setAttribute('aria-hidden','false');setupCanvas();}
  function closeApproval(){const overlay=document.getElementById('approval-overlay');if(!overlay)return;overlay.classList.remove('active');overlay.setAttribute('aria-hidden','true');}
  async function readResponseMessage(response,fallbackMessage){const text=await response.text();if(!text)return fallbackMessage;try{const parsed=JSON.parse(text);return parsed?.message||parsed?.error?.message||fallbackMessage;}catch(_){return text;}}
  async function copyPdfLink(url){if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(url);setFeedback('public-feedback','Link direto do PDF copiado.','success');return;}window.prompt('Copie o link do PDF abaixo:',url);}
  async function fetchPdfBlob(url){const response=await fetch(url,{credentials:'same-origin'});if(!response.ok){throw new Error(await readResponseMessage(response,'Falha ao carregar o PDF.'));}return response.blob();}
  async function sharePdf(){const pdfUrl=document.body.dataset.publicPdfUrl;const fileName=document.body.dataset.publicPdfFilename||'documento.pdf';if(!pdfUrl)return;try{if(navigator.share){const blob=await fetchPdfBlob(pdfUrl);if(typeof File!=='undefined'){const file=new File([blob],fileName,{type:'application/pdf'});if(navigator.canShare&&navigator.canShare({files:[file]})){await navigator.share({files:[file],title:fileName});return;}}await navigator.share({title:fileName,url:pdfUrl});return;}await copyPdfLink(pdfUrl);}catch(error){if(error?.name==='AbortError')return;await copyPdfLink(pdfUrl);}}
  function downloadPdf(){const pdfUrl=document.body.dataset.publicPdfDownloadUrl||document.body.dataset.publicPdfUrl;const fileName=document.body.dataset.publicPdfFilename||'documento.pdf';if(!pdfUrl)return;const link=document.createElement('a');link.href=pdfUrl;link.download=fileName;link.rel='noopener';document.body.appendChild(link);link.click();link.remove();}
  function point(event){const rect=canvas.getBoundingClientRect();return {x:event.clientX-rect.left,y:event.clientY-rect.top};}
  function setupCanvas(){canvas=document.getElementById('approval-canvas');if(!canvas||canvas.dataset.ready==='true')return;const ratio=window.devicePixelRatio||1;const rect=canvas.getBoundingClientRect();canvas.width=rect.width*ratio;canvas.height=rect.height*ratio;ctx=canvas.getContext('2d');ctx.scale(ratio,ratio);ctx.lineWidth=2;ctx.lineCap='round';ctx.strokeStyle='#121826';canvas.dataset.ready='true';canvas.onpointerdown=(event)=>{drawing=true;hasDrawing=true;const nextPoint=point(event);ctx.beginPath();ctx.moveTo(nextPoint.x,nextPoint.y);};canvas.onpointermove=(event)=>{if(!drawing)return;const nextPoint=point(event);ctx.lineTo(nextPoint.x,nextPoint.y);ctx.stroke();};canvas.onpointerup=()=>{drawing=false;};canvas.onpointerleave=()=>{drawing=false;};}
  function clearApproval(){if(!ctx||!canvas)return;ctx.clearRect(0,0,canvas.width,canvas.height);hasDrawing=false;clearFeedback('approval-feedback');}
  async function submitApproval(){if(!canvas||!ctx){setupCanvas();}if(!hasDrawing){setFeedback('approval-feedback','Assine no quadro antes de confirmar.','error');return;}setButtonBusy('approval-submit',true,'Enviando...');clearFeedback('approval-feedback');const budgetId=document.body.dataset.publicBudgetId;const taskId=document.body.dataset.publicTaskId;const token=document.body.dataset.publicToken;const endpoint=budgetId?'/public/budgets/'+budgetId+'/approve?token='+encodeURIComponent(token):'/public/tasks/'+taskId+'/approve?token='+encodeURIComponent(token);const payload={token,signature:canvas.toDataURL('image/png'),name:document.getElementById('approval-name').value.trim(),document:document.getElementById('approval-document').value.trim()};try{const response=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});if(!response.ok){throw new Error(await readResponseMessage(response,'Nao foi possivel concluir a assinatura.'));}window.location.reload();}catch(error){setFeedback('approval-feedback',error.message||'Nao foi possivel concluir a assinatura.','error');setButtonBusy('approval-submit',false,'Enviando...');}}
  async function removeApproval(){const budgetId=document.body.dataset.publicBudgetId;const taskId=document.body.dataset.publicTaskId;const token=document.body.dataset.publicToken;const endpoint=budgetId?'/public/budgets/'+budgetId+'/signature/remove?token='+encodeURIComponent(token):'/public/tasks/'+taskId+'/signature/remove?token='+encodeURIComponent(token);clearFeedback('approval-feedback');try{const response=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token})});if(!response.ok){throw new Error(await readResponseMessage(response,'Nao foi possivel remover a assinatura.'));}window.location.reload();}catch(error){setFeedback('approval-feedback',error.message||'Nao foi possivel remover a assinatura.','error');}}
  window.addEventListener('keydown',(event)=>{if(event.key==='Escape'){closeApproval();}});
  window.addEventListener('load',()=>{const overlay=document.getElementById('approval-overlay');if(!overlay)return;overlay.addEventListener('click',(event)=>{if(event.target===overlay){closeApproval();}});});
</script>`;
}

function injectPublicPageChrome(html, options) {
  const {
    env,
    title,
    documentKind,
    documentTitle,
    documentSubtitle,
    metrics = [],
    details = [],
    note = "",
    token,
    pdfUrl,
    pdfDownloadUrl,
    pdfFileName,
    refreshUrl,
    approveBudget = null,
    approveReport = null,
    statusLabel = null,
    signatureMode = "none",
    signatureClient = "",
    logoUrl = null
  } = options;

  const status = normalizePublicStatusLabel(statusLabel);
  const actionLabel = approveBudget ? "Aprovar orcamento" : "Assinar relatorio";
  const signatureState = resolveSignatureState({
    signatureMode,
    signatureClient,
    actionLabel
  });
  const hasApproval = Boolean(approveBudget || approveReport);
  const primaryAction = renderPrimaryAction({
    approveBudget,
    approveReport,
    actionLabel
  });
  const heroActions = renderQuickActions({
    pdfUrl,
    pdfDownloadUrl,
    refreshUrl,
    hasApproval
  });
  const modal = hasApproval
    ? renderApprovalModal({
        actionLabel,
        showRemoveAction: Boolean(signatureClient)
      })
    : "";
  const brandMark = logoUrl
    ? `<img src="${escapeHtmlAttribute(logoUrl)}" alt="RV Sistema Empresa" />`
    : "<span>RV</span>";
  const heroSubtitle = documentSubtitle ? `<p>${escapeHtml(documentSubtitle)}</p>` : "";
  const noteBlock = note ? `<p>${escapeHtml(note)}</p>` : "";

  let updated = html.replace("</head>", `${buildPublicHeadExtra()}${buildPublicScript()}</head>`);
  updated = updated.replace(
    "<body>",
    `<body class="public-body" data-public-token="${escapeHtmlAttribute(token)}" data-public-pdf-url="${escapeHtmlAttribute(pdfUrl || "")}" data-public-pdf-download-url="${escapeHtmlAttribute(pdfDownloadUrl || pdfUrl || "")}" data-public-pdf-filename="${escapeHtmlAttribute(pdfFileName || "documento.pdf")}" ${approveBudget ? `data-public-budget-id="${escapeHtmlAttribute(approveBudget.budgetId)}"` : ""} ${approveReport ? `data-public-task-id="${escapeHtmlAttribute(approveReport.taskId)}"` : ""}>
      ${modal}
      <div class="public-root">
        <div id="public-feedback" class="public-feedback public-feedback--info public-chrome" hidden></div>
        <div class="public-shell">
          <header class="public-hero public-chrome">
            <div class="public-hero-copy">
              <div class="public-brand-mark">${brandMark}</div>
              <div>
                <span class="public-eyebrow">${escapeHtml(documentKind)}</span>
                <h1>${escapeHtml(documentTitle || title)}</h1>
                ${heroSubtitle}
                <div class="public-chip-row">${renderStatusChips({ status, signatureState })}</div>
              </div>
            </div>
            <div class="public-hero-actions">
              ${primaryAction}
              <div class="public-action-grid">${heroActions}</div>
              <div class="public-hero-meta">Link publico seguro com validade padrao de ${escapeHtml(String(env.publicLinkDefaultDays || 30))} dias.</div>
            </div>
          </header>
          <div class="public-main">
            <div class="public-main-column">
              <section class="public-section public-chrome">
                <div class="public-section-head">
                  <div>
                    <span class="public-section-eyebrow">Contexto</span>
                    <h2>Resumo do documento</h2>
                    <p>Organizei as informacoes principais para que voce entenda rapidamente o status atual e o que fazer em seguida.</p>
                  </div>
                </div>
                <div class="public-metric-grid">${renderMetricCards(metrics)}</div>
                <div class="public-detail-card">${renderDetailRows(details)}</div>
              </section>
              <section class="public-section">
                <div class="public-preview-header public-chrome">
                  <span class="public-section-eyebrow">Conteudo</span>
                  <h2>Visualizacao do documento</h2>
                  ${noteBlock}
                </div>
                <div class="document-preview">`
  );
  updated = updated.replace(
    "</body>",
    `</div>
              </section>
            </div>
            <aside class="public-sidebar">
              <section class="public-panel public-chrome">
                <span class="public-section-eyebrow">Assinatura</span>
                <h2>${escapeHtml(signatureState.title)}</h2>
                <p>${escapeHtml(signatureState.message)}</p>
                ${hasApproval ? `<button class="public-button public-button--primary" type="button" onclick="openApproval()">${escapeHtml(actionLabel)}</button>` : ""}
              </section>
              <section class="public-panel public-chrome">
                <span class="public-section-eyebrow">Acoes</span>
                <h2>Use o formato que fizer mais sentido</h2>
                <p>Baixe, compartilhe, imprima ou atualize a visualizacao sem perder o contexto do documento.</p>
                <div class="public-action-grid">${renderQuickActions({
                  pdfUrl,
                  pdfDownloadUrl,
                  refreshUrl,
                  hasApproval
                })}</div>
              </section>
            </aside>
          </div>
        </div>
      </div>
    </body>`
  );
  return updated;
}

function renderPublicErrorPage(req, { title, message, detail = "", statusCode = 400 }) {
  const actionLabel = statusCode >= 500 ? "Tentar novamente" : "Solicitar um novo link";
  return `<!doctype html>
  <html lang="pt-BR">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>${escapeHtml(title)}</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Sora:wght@400;500;600&display=swap" rel="stylesheet">
      <style>
        body{margin:0;min-height:100vh;display:grid;place-items:center;padding:16px;font-family:"Sora",sans-serif;color:#121826;background:radial-gradient(circle at top left,rgba(36,91,235,.14),transparent 32%),radial-gradient(circle at top right,rgba(20,194,163,.14),transparent 24%),linear-gradient(180deg,#fbfcff 0%,#f7f9fc 52%,#f2f5fa 100%)}
        .public-error-shell{width:min(720px,100%);padding:28px;border-radius:28px;border:1px solid #E4EAF3;background:rgba(255,255,255,.96);box-shadow:0 18px 40px rgba(18,24,38,.08);display:grid;gap:18px}.public-chip{display:inline-flex;align-items:center;min-height:36px;padding:0 14px;border-radius:999px;background:rgba(240,68,56,.1);color:#B42318;font-size:13px;font-weight:600;width:fit-content}.public-error-shell h1{margin:0;font-family:"Space Grotesk",sans-serif;font-size:clamp(28px,5vw,40px);line-height:1.04;letter-spacing:-.04em}.public-error-shell p{margin:0;color:#5B6475;line-height:1.6}.public-actions-row{display:flex;gap:12px;flex-wrap:wrap}.public-button{min-height:48px;padding:0 16px;border-radius:16px;border:1px solid transparent;display:inline-flex;align-items:center;justify-content:center;text-decoration:none;font-weight:600;cursor:pointer;font-family:inherit}.public-button--primary{background:linear-gradient(180deg,#245BEB,#1B46C5);color:#fff;box-shadow:0 16px 28px rgba(36,91,235,.28)}.public-button--ghost{background:#fff;color:#121826;border-color:#E4EAF3}
      </style>
    </head>
    <body>
      <main class="public-error-shell">
        <span class="public-chip">Link indisponivel</span>
        <h1>${escapeHtml(title)}</h1>
        <p>${escapeHtml(message)}</p>
        ${detail ? `<p>${escapeHtml(detail)}</p>` : ""}
        <div class="public-actions-row">
          <button class="public-button public-button--primary" type="button" onclick="window.location.reload()">${escapeHtml(actionLabel)}</button>
          <button class="public-button public-button--ghost" type="button" onclick="window.history.back()">Voltar</button>
        </div>
      </main>
    </body>
  </html>`;
}

module.exports = {
  normalizePublicStatusLabel,
  formatPublicDate,
  formatPublicCurrency,
  injectPublicPageChrome,
  renderPublicErrorPage
};
