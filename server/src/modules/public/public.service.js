const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");

const puppeteer = require("puppeteer");

const { NotFoundError, ValidationError } = require("../../core/errors/app-error");
const { parseJsonFields, safeJsonParse } = require("../../core/utils/json");

function createPublicService({ env, logger }) {
  let cachedLogoDataUrl;
  let pdfHelpersPromise;
  let pdfBrowserPromise;

  const pdfInFlight = {
    tasks: new Map(),
    budgets: new Map()
  };
  const taskWarmTimers = new Map();
  const budgetWarmTimers = new Map();

  function ensureDir(dirPath) {
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
  }

  function getPdfCachePath(type, id, hash) {
    const dir = path.join(__dirname, "..", "..", "..", ".cache", "pdfs", type);
    ensureDir(dir);
    return path.join(dir, `${id}.${hash}.pdf`);
  }

  function removeOldPdfCaches(type, id, keepHash) {
    const dir = path.dirname(getPdfCachePath(type, id, keepHash || "keep"));
    if (!fs.existsSync(dir)) return;

    fs.readdirSync(dir)
      .filter((fileName) => fileName.startsWith(`${id}.`) && fileName.endsWith(".pdf"))
      .forEach((fileName) => {
        if (keepHash && fileName === `${id}.${keepHash}.pdf`) return;
        try {
          fs.unlinkSync(path.join(dir, fileName));
        } catch (error) {
          logger.warn("pdf_cache_cleanup_failed", { fileName, message: error.message });
        }
      });
  }

  function stableSerialize(value) {
    if (Array.isArray(value)) {
      return `[${value.map(stableSerialize).join(",")}]`;
    }
    if (value && typeof value === "object") {
      return `{${Object.keys(value)
        .sort()
        .map((key) => `${JSON.stringify(key)}:${stableSerialize(value[key])}`)
        .join(",")}}`;
    }
    return JSON.stringify(value);
  }

  function computeCacheHash(data) {
    return crypto.createHash("sha256").update(stableSerialize(data)).digest("hex");
  }

  async function getCachedPdf({ type, id, hash, forceRefresh, render }) {
    if (!env.pdfCacheEnabled) {
      return render();
    }

    const filePath = getPdfCachePath(type, id, hash);
    if (!forceRefresh && fs.existsSync(filePath)) {
      return fs.readFileSync(filePath);
    }

    const bucket = type === "tasks" ? pdfInFlight.tasks : pdfInFlight.budgets;
    const inFlightKey = `${id}:${hash}`;
    if (bucket.has(inFlightKey)) {
      return bucket.get(inFlightKey);
    }

    const promise = (async () => {
      const pdf = await render();
      fs.writeFileSync(filePath, pdf);
      removeOldPdfCaches(type, id, hash);
      return pdf;
    })();

    bucket.set(inFlightKey, promise);

    try {
      return await promise;
    } finally {
      bucket.delete(inFlightKey);
    }
  }

  function isCachedPdfReady(type, id, hash) {
    if (!env.pdfCacheEnabled) return false;
    return fs.existsSync(getPdfCachePath(type, id, hash));
  }

  function nowIso() {
    return new Date().toISOString();
  }

  function addDaysIso(days) {
    const numeric = Number(days);
    if (!Number.isFinite(numeric) || numeric <= 0) return null;
    const date = new Date();
    date.setDate(date.getDate() + numeric);
    return date.toISOString();
  }

  function generatePublicToken() {
    return crypto.randomBytes(32).toString("base64url");
  }

  function getPublicBaseUrl(req) {
    if (env.publicBaseUrl) {
      return env.publicBaseUrl.replace(/\/+$/g, "");
    }
    const protocol = req.headers["x-forwarded-proto"] || req.protocol || "https";
    return `${protocol}://${req.get("host")}`;
  }

  function buildPublicTaskUrl(req, taskId, token) {
    return `${getPublicBaseUrl(req)}/public/tasks/${taskId}?token=${encodeURIComponent(token)}`;
  }

  function buildPublicBudgetUrl(req, budgetId, token) {
    return `${getPublicBaseUrl(req)}/public/budgets/${budgetId}?token=${encodeURIComponent(token)}`;
  }

  async function getActiveLink(db, { table, foreignKey, id }) {
    return db.get(
      `SELECT *
       FROM ${table}
       WHERE ${foreignKey} = ?
         AND revoked_at IS NULL
         AND (expires_at IS NULL OR expires_at > ?)
       ORDER BY id DESC
       LIMIT 1`,
      [id, nowIso()]
    );
  }

  async function createLink(db, { table, foreignKey, id, userId, expiresAt }) {
    const createdAt = nowIso();
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const token = generatePublicToken();
      try {
        const result = await db.run(
          `INSERT INTO ${table} (${foreignKey}, token, created_at, created_by_user_id, expires_at)
           VALUES (?, ?, ?, ?, ?)`,
          [id, token, createdAt, userId || null, expiresAt]
        );
        return db.get(`SELECT * FROM ${table} WHERE id = ?`, [result.lastID]);
      } catch (error) {
        const message = String(error?.message || "").toLowerCase();
        const isUniqueError = message.includes("unique") || message.includes("duplicate");
        if (!isUniqueError) throw error;
      }
    }

    throw new ValidationError("Falha ao gerar token público.");
  }

  async function findValidLink(db, { table, foreignKey, id, token }) {
    if (!token) return null;

    const link = await db.get(
      `SELECT *
       FROM ${table}
       WHERE ${foreignKey} = ?
         AND token = ?
         AND revoked_at IS NULL
         AND (expires_at IS NULL OR expires_at > ?)
       LIMIT 1`,
      [id, token, nowIso()]
    );

    if (!link) return null;

    await db.run(`UPDATE ${table} SET last_used_at = ? WHERE id = ?`, [nowIso(), link.id]);
    return link;
  }

  function resolveLogoPath() {
    const candidates = [
      process.env.PDF_LOGO_PATH,
      path.join(process.cwd(), "Logo.png"),
      path.join(__dirname, "..", "..", "..", "..", "web", "src", "assets", "Logo.png"),
      path.join(__dirname, "..", "..", "..", "..", "web", "src", "assets", "rv-logo.png")
    ].filter(Boolean);

    return candidates.find((candidate) => fs.existsSync(candidate)) || null;
  }

  function getLogoDataUrl() {
    if (cachedLogoDataUrl) return cachedLogoDataUrl;
    const logoPath = resolveLogoPath();
    if (!logoPath) return null;
    cachedLogoDataUrl = `data:image/png;base64,${fs.readFileSync(logoPath).toString("base64")}`;
    return cachedLogoDataUrl;
  }

  async function loadPdfHelpers() {
    if (!pdfHelpersPromise) {
      const modulePath =
        process.env.PDF_TEMPLATE_PATH ||
        path.join(__dirname, "..", "..", "..", "..", "web", "src", "utils", "pdf.js");
      if (!fs.existsSync(modulePath)) {
        throw new Error("Template de PDF não encontrado.");
      }
      pdfHelpersPromise = import(pathToFileURL(modulePath).href);
    }
    return pdfHelpersPromise;
  }

  async function getPdfBrowser() {
    if (!pdfBrowserPromise) {
      const launchOptions = {
        headless: "new",
        args: ["--no-sandbox", "--disable-setuid-sandbox", ...env.puppeteerArgs]
      };
      if (env.puppeteerExecutablePath) {
        launchOptions.executablePath = env.puppeteerExecutablePath;
      }
      pdfBrowserPromise = puppeteer.launch(launchOptions);
    }
    return pdfBrowserPromise;
  }

  async function renderPdfFromHtml(html) {
    const browser = await getPdfBrowser();
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: "networkidle0" });
    const pdf = await page.pdf({ format: "A4", printBackground: true });
    await page.close();
    return Buffer.from(pdf);
  }

  function normalizeReportContent(report) {
    const content = safeJsonParse(report.content) || report.content || {};
    const templateStructure = safeJsonParse(report.template_structure) || report.template_structure || {};
    return {
      ...report,
      content: {
        sections: content.sections || templateStructure.sections || [],
        layout: content.layout || templateStructure.layout || { sectionColumns: 1, fieldColumns: 1 },
        answers: content.answers || {},
        photos: content.photos || []
      }
    };
  }

  async function fetchTaskPdfData(db, taskId) {
    const task = await db.get("SELECT * FROM tasks WHERE id = ?", [taskId]);
    if (!task) return null;

    const client = task.client_id
      ? await db.get("SELECT * FROM clients WHERE id = ?", [task.client_id])
      : null;

    const reportRows = await db.all(
      `SELECT reports.*,
              report_templates.structure AS template_structure,
              equipments.name AS equipment_name,
              equipments.model AS equipment_model,
              equipments.serial AS equipment_serial,
              equipments.description AS equipment_description
       FROM reports
       LEFT JOIN report_templates ON report_templates.id = reports.template_id
       LEFT JOIN equipments ON equipments.id = reports.equipment_id
       WHERE reports.task_id = ?
       ORDER BY reports.id ASC`,
      [taskId]
    );

    const reports = reportRows.map((row) => normalizeReportContent(row));
    const budgets = await db.all(
      `SELECT budgets.*,
              clients.name AS client_name,
              reports.title AS report_title,
              tasks.title AS task_title
       FROM budgets
       LEFT JOIN clients ON clients.id = budgets.client_id
       LEFT JOIN reports ON reports.id = budgets.report_id
       LEFT JOIN tasks ON tasks.id = budgets.task_id
       WHERE budgets.task_id = ?
       ORDER BY budgets.id ASC`,
      [taskId]
    );

    if (budgets.length) {
      const ids = budgets.map((budget) => budget.id);
      const placeholders = ids.map(() => "?").join(", ");
      const items = await db.all(
        `SELECT * FROM budget_items WHERE budget_id IN (${placeholders}) ORDER BY id ASC`,
        ids
      );
      const grouped = new Map();
      items.forEach((item) => {
        if (!grouped.has(item.budget_id)) grouped.set(item.budget_id, []);
        grouped.get(item.budget_id).push(item);
      });
      budgets.forEach((budget) => {
        budget.items = grouped.get(budget.id) || [];
      });
    }

    return {
      task: parseJsonFields(task, ["signature_pages"]),
      client,
      reports,
      budgets
    };
  }

  async function fetchBudgetPdfData(db, budgetId) {
    const budget = parseJsonFields(
      await db.get(
        `SELECT budgets.*,
                clients.name AS client_name,
                reports.title AS report_title,
                tasks.title AS task_title
         FROM budgets
         LEFT JOIN clients ON clients.id = budgets.client_id
         LEFT JOIN reports ON reports.id = budgets.report_id
         LEFT JOIN tasks ON tasks.id = budgets.task_id
         WHERE budgets.id = ?`,
        [budgetId]
      ),
      ["signature_pages"]
    );

    if (!budget) return null;

    budget.items = await db.all("SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC", [
      budgetId
    ]);

    const client = budget.client_id
      ? await db.get("SELECT * FROM clients WHERE id = ?", [budget.client_id])
      : null;

    return { budget, client };
  }

  async function renderTaskPdf(db, taskId, { forceRefresh = false } = {}) {
    const data = await fetchTaskPdfData(db, taskId);
    if (!data) {
      throw new NotFoundError("Tarefa nao encontrada.");
    }

    const logoUrl = getLogoDataUrl();
    const hash = computeCacheHash({ type: "task", data, logoUrl });
    const { buildTaskPdfHtml } = await loadPdfHelpers();

    return getCachedPdf({
      type: "tasks",
      id: taskId,
      hash,
      forceRefresh,
      render: () =>
        renderPdfFromHtml(
          buildTaskPdfHtml({
            task: data.task,
            client: data.client,
            reports: data.reports,
            budgets: data.budgets,
            signatureMode: data.task.signature_mode,
            signatureScope: data.task.signature_scope,
            signatureClient: data.task.signature_client,
            signatureTech: data.task.signature_tech,
            signaturePages: data.task.signature_pages || {},
            logoUrl
          })
        )
    });
  }

  async function renderBudgetPdf(db, budgetId, { forceRefresh = false } = {}) {
    const data = await fetchBudgetPdfData(db, budgetId);
    if (!data) {
      throw new NotFoundError("Orçamento não encontrado.");
    }

    const logoUrl = getLogoDataUrl();
    const hash = computeCacheHash({ type: "budget", data, logoUrl });
    const { buildBudgetPdfHtml } = await loadPdfHelpers();

    return getCachedPdf({
      type: "budgets",
      id: budgetId,
      hash,
      forceRefresh,
      render: () =>
        renderPdfFromHtml(
          buildBudgetPdfHtml({
            budget: data.budget,
            client: data.client,
            signatureMode: data.budget.signature_mode,
            signatureScope: data.budget.signature_scope,
            signatureClient: data.budget.signature_client,
            signatureTech: data.budget.signature_tech,
            signaturePages: data.budget.signature_pages || {},
            logoUrl
          })
        )
    });
  }

  async function getTaskPdfCacheStatus(db, taskId) {
    const data = await fetchTaskPdfData(db, taskId);
    if (!data) throw new NotFoundError("Tarefa nao encontrada.");
    const hash = computeCacheHash({ type: "task", data, logoUrl: getLogoDataUrl() });
    return { ready: isCachedPdfReady("tasks", taskId, hash), hash };
  }

  async function getBudgetPdfCacheStatus(db, budgetId) {
    const data = await fetchBudgetPdfData(db, budgetId);
    if (!data) throw new NotFoundError("Orçamento não encontrado.");
    const hash = computeCacheHash({ type: "budget", data, logoUrl: getLogoDataUrl() });
    return { ready: isCachedPdfReady("budgets", budgetId, hash), hash };
  }

  async function warmTaskPdf(db, taskId, forceRefresh = true) {
    return renderTaskPdf(db, taskId, { forceRefresh });
  }

  async function warmBudgetPdf(db, budgetId, forceRefresh = true) {
    return renderBudgetPdf(db, budgetId, { forceRefresh });
  }

  function scheduleWarmTaskPdfCache(db, taskId, forceRefresh = true) {
    if (!env.pdfCacheEnabled || !taskId) return;
    clearTimeout(taskWarmTimers.get(taskId));
    const timer = setTimeout(() => {
      taskWarmTimers.delete(taskId);
      warmTaskPdf(db, taskId, forceRefresh).catch((error) => {
        logger.warn("task_pdf_warm_failed", { taskId, message: error.message });
      });
    }, env.pdfWarmDebounceMs);
    taskWarmTimers.set(taskId, timer);
  }

  function scheduleWarmBudgetPdfCache(db, budgetId, forceRefresh = true) {
    if (!env.pdfCacheEnabled || !budgetId) return;
    clearTimeout(budgetWarmTimers.get(budgetId));
    const timer = setTimeout(() => {
      budgetWarmTimers.delete(budgetId);
      warmBudgetPdf(db, budgetId, forceRefresh).catch((error) => {
        logger.warn("budget_pdf_warm_failed", { budgetId, message: error.message });
      });
    }, env.pdfWarmDebounceMs);
    budgetWarmTimers.set(budgetId, timer);
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
      default:
        return { text: value || "-", variant: "neutral" };
    }
  }

  function escapeHtmlAttribute(value = "") {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function injectPublicToolbar(
    html,
    {
      title,
      token,
      pdfUrl,
      pdfDownloadUrl,
      pdfFileName,
      refreshUrl,
      approveBudget = null,
      approveReport = null,
      statusLabel = null
    }
  ) {
    const status = normalizePublicStatusLabel(statusLabel);
    const statusBadge = status
      ? `<span class="badge ${status.variant}">${status.text}</span>`
      : "";
    const actionLabel = approveBudget ? "Aprovar orçamento" : "Assinar relatório";
    const approveButton = approveBudget || approveReport
      ? `<button type="button" onclick="openApproval()">${actionLabel}</button>`
      : "";
    const sharePdfButton = pdfUrl
      ? `<button type="button" onclick="sharePdf()">Compartilhar PDF</button>`
      : "";
    const downloadPdfButton = pdfDownloadUrl
      ? `<button type="button" onclick="downloadPdf()">Baixar PDF</button>`
      : "";
    const modal = approveBudget || approveReport
      ? `<div class="overlay" id="approval-overlay"><div class="card"><h3>${actionLabel}</h3><input id="approval-name" type="text" placeholder="Nome (opcional)" /><input id="approval-document" type="text" placeholder="CPF/CNPJ (opcional)" /><canvas id="approval-canvas"></canvas><div class="actions"><button type="button" onclick="clearApproval()">Limpar</button><button type="button" onclick="removeApproval()">Remover assinatura</button><button type="button" onclick="closeApproval()">Cancelar</button><button type="button" onclick="submitApproval()">Salvar</button></div></div></div>`
      : "";

    const headExtra = `
<style>
  body { margin: 0; background: #eef3f9; }
  .shell { min-height: 100vh; padding-bottom: 32px; }
  .toolbar { position: sticky; top: 0; z-index: 10; display: flex; gap: 8px; align-items: center; justify-content: center; padding: 12px; background: rgba(12, 27, 42, 0.96); color: #fff; }
  .toolbar .title { font-weight: 700; margin-right: 8px; }
  .toolbar .badge { padding: 4px 10px; border-radius: 999px; border: 1px solid rgba(255,255,255,0.24); font-size: 11px; text-transform: uppercase; }
  .toolbar .badge.success { background: rgba(34,197,94,0.2); }
  .toolbar .badge.warning { background: rgba(245,158,11,0.2); }
  .toolbar .badge.danger { background: rgba(239,68,68,0.24); }
  .toolbar .badge.info { background: rgba(56,189,248,0.2); }
  .toolbar button, .toolbar a { padding: 8px 12px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.24); background: rgba(255,255,255,0.12); color: #fff; text-decoration: none; cursor: pointer; }
  .content { width: min(1100px, 96vw); margin: 16px auto 0; display: grid; gap: 16px; }
  .content .page { box-shadow: 0 16px 30px rgba(17,52,86,0.12); border-radius: 18px; background: #fff; }
  .overlay { position: fixed; inset: 0; display: none; align-items: center; justify-content: center; background: rgba(12,27,42,0.66); z-index: 20; }
  .overlay.active { display: flex; }
  .card { width: min(620px, 96vw); display: grid; gap: 12px; padding: 18px; border-radius: 18px; background: #fff; }
  .card input { width: 100%; padding: 12px; border-radius: 12px; border: 1px solid #d7e0ec; background: #f7f9fc; }
  .card canvas { width: 100%; height: 220px; border-radius: 12px; border: 1px solid #d7e0ec; background: #fff; touch-action: none; }
  .actions { display: flex; gap: 8px; justify-content: flex-end; }
  @media print { .toolbar { display: none !important; } .content { width: 100% !important; margin: 0 !important; gap: 0 !important; } .content .page { box-shadow: none !important; border-radius: 0 !important; } }
</style>
<script>
  let canvas; let ctx; let drawing = false;
  function openApproval() { document.getElementById('approval-overlay')?.classList.add('active'); setupCanvas(); }
  function closeApproval() { document.getElementById('approval-overlay')?.classList.remove('active'); }
  async function copyPdfLink(url) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(url);
      alert('Link direto do PDF copiado.');
      return;
    }
    window.prompt('Copie o link do PDF abaixo:', url);
  }
  async function fetchPdfBlob(url) {
    const response = await fetch(url, { credentials: 'same-origin' });
    if (!response.ok) {
        throw new Error('Falha ao carregar o PDF.');
    }
    return response.blob();
  }
  async function sharePdf() {
    const pdfUrl = document.body.dataset.publicPdfUrl;
    const fileName = document.body.dataset.publicPdfFilename || 'documento.pdf';
    if (!pdfUrl) return;
    try {
      if (navigator.share) {
        const blob = await fetchPdfBlob(pdfUrl);
        if (typeof File !== 'undefined') {
          const file = new File([blob], fileName, { type: 'application/pdf' });
          if (navigator.canShare && navigator.canShare({ files: [file] })) {
            await navigator.share({ files: [file], title: fileName });
            return;
          }
        }
        await navigator.share({ title: fileName, url: pdfUrl });
        return;
      }
      await copyPdfLink(pdfUrl);
    } catch (error) {
      if (error?.name === 'AbortError') return;
      await copyPdfLink(pdfUrl);
    }
  }
  function downloadPdf() {
    const pdfUrl = document.body.dataset.publicPdfDownloadUrl || document.body.dataset.publicPdfUrl;
    const fileName = document.body.dataset.publicPdfFilename || 'documento.pdf';
    if (!pdfUrl) return;
    const link = document.createElement('a');
    link.href = pdfUrl;
    link.download = fileName;
    link.rel = 'noopener';
    document.body.appendChild(link);
    link.click();
    link.remove();
  }
  function setupCanvas() {
    canvas = document.getElementById('approval-canvas');
    if (!canvas) return;
    const ratio = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * ratio; canvas.height = rect.height * ratio;
    ctx = canvas.getContext('2d'); ctx.scale(ratio, ratio); ctx.lineWidth = 2; ctx.lineCap = 'round'; ctx.strokeStyle = '#0f172a';
    canvas.onpointerdown = (event) => { drawing = true; const p = point(event); ctx.beginPath(); ctx.moveTo(p.x, p.y); };
    canvas.onpointermove = (event) => { if (!drawing) return; const p = point(event); ctx.lineTo(p.x, p.y); ctx.stroke(); };
    canvas.onpointerup = () => drawing = false; canvas.onpointerleave = () => drawing = false;
  }
  function point(event) { const rect = canvas.getBoundingClientRect(); return { x: event.clientX - rect.left, y: event.clientY - rect.top }; }
  function clearApproval() { if (!ctx || !canvas) return; ctx.clearRect(0, 0, canvas.width, canvas.height); }
  async function submitApproval() {
    const budgetId = document.body.dataset.publicBudgetId;
    const taskId = document.body.dataset.publicTaskId;
    const token = document.body.dataset.publicToken;
    const endpoint = budgetId ? '/public/budgets/' + budgetId + '/approve?token=' + encodeURIComponent(token) : '/public/tasks/' + taskId + '/approve?token=' + encodeURIComponent(token);
    const payload = { token, signature: canvas.toDataURL('image/png'), name: document.getElementById('approval-name').value.trim(), document: document.getElementById('approval-document').value.trim() };
    const response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    if (!response.ok) { alert(await response.text()); return; }
    window.location.reload();
  }
  async function removeApproval() {
    const budgetId = document.body.dataset.publicBudgetId;
    const taskId = document.body.dataset.publicTaskId;
    const token = document.body.dataset.publicToken;
    const endpoint = budgetId ? '/public/budgets/' + budgetId + '/signature/remove?token=' + encodeURIComponent(token) : '/public/tasks/' + taskId + '/signature/remove?token=' + encodeURIComponent(token);
    const response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token }) });
    if (!response.ok) { alert(await response.text()); return; }
    window.location.reload();
  }
</script>`;

    const toolbar = `<div class="toolbar"><div class="title">${title}</div>${statusBadge}<button type="button" onclick="window.print()">Imprimir</button>${sharePdfButton}${downloadPdfButton}${approveButton}<a href="${refreshUrl}">Atualizar</a><span>Link expira em ${env.publicLinkDefaultDays} dias.</span></div>`;

    let updated = html.replace("</head>", `${headExtra}</head>`);
    updated = updated.replace(
      "<body>",
      `<body data-public-token="${escapeHtmlAttribute(token)}" data-public-pdf-url="${escapeHtmlAttribute(pdfUrl || "")}" data-public-pdf-download-url="${escapeHtmlAttribute(pdfDownloadUrl || pdfUrl || "")}" data-public-pdf-filename="${escapeHtmlAttribute(pdfFileName || "documento.pdf")}" ${approveBudget ? `data-public-budget-id="${escapeHtmlAttribute(approveBudget.budgetId)}"` : ""} ${approveReport ? `data-public-task-id="${escapeHtmlAttribute(approveReport.taskId)}"` : ""}><div class="shell">${toolbar}${modal}<main class="content">`
    );
    updated = updated.replace("</body>", "</main></div></body>");
    return updated;
  }

  async function ensureTaskPublicLink(db, req, taskId, userId) {
    const link =
      (await getActiveLink(db, { table: "task_public_links", foreignKey: "task_id", id: taskId })) ||
      (await createLink(db, {
        table: "task_public_links",
        foreignKey: "task_id",
        id: taskId,
        userId,
        expiresAt: addDaysIso(env.publicLinkDefaultDays)
      }));

    return { ...link, url: buildPublicTaskUrl(req, taskId, link.token) };
  }

  async function ensureBudgetPublicLink(db, req, budgetId, userId) {
    const link =
      (await getActiveLink(db, { table: "budget_public_links", foreignKey: "budget_id", id: budgetId })) ||
      (await createLink(db, {
        table: "budget_public_links",
        foreignKey: "budget_id",
        id: budgetId,
        userId,
        expiresAt: addDaysIso(env.publicLinkDefaultDays)
      }));

    return { ...link, url: buildPublicBudgetUrl(req, budgetId, link.token) };
  }

  async function renderPublicTaskPage(db, req, taskId, token) {
    const link = await findValidLink(db, {
      table: "task_public_links",
      foreignKey: "task_id",
      id: taskId,
      token
    });
    if (!link) {
      throw new ValidationError("Link público inválido ou expirado.");
    }

    const data = await fetchTaskPdfData(db, taskId);
    if (!data) {
      throw new NotFoundError("Tarefa nao encontrada.");
    }

    const logoUrl = getLogoDataUrl();
    const { buildTaskPdfHtml } = await loadPdfHelpers();
    const html = buildTaskPdfHtml({
      task: data.task,
      client: data.client,
      reports: data.reports,
      budgets: data.budgets,
      signatureMode: data.task.signature_mode,
      signatureScope: data.task.signature_scope,
      signatureClient: data.task.signature_client,
      signatureTech: data.task.signature_tech,
      signaturePages: data.task.signature_pages || {},
      logoUrl
    });
    const encodedToken = encodeURIComponent(token);
    const baseUrl = getPublicBaseUrl(req);

    return injectPublicToolbar(html, {
      title: `Relatório da tarefa #${taskId}`,
      token,
      pdfUrl: `${baseUrl}/public/tasks/${taskId}/pdf?token=${encodedToken}`,
      pdfDownloadUrl: `${baseUrl}/public/tasks/${taskId}/pdf?token=${encodedToken}&download=1`,
      pdfFileName: `relatorio_tarefa_${taskId}.pdf`,
      refreshUrl: `${baseUrl}/public/tasks/${taskId}?token=${encodedToken}`,
      approveReport: { taskId },
      statusLabel: data.task.status
    });
  }

  async function renderPublicBudgetPage(db, req, budgetId, token) {
    const link = await findValidLink(db, {
      table: "budget_public_links",
      foreignKey: "budget_id",
      id: budgetId,
      token
    });
    if (!link) {
      throw new ValidationError("Link público inválido ou expirado.");
    }

    const data = await fetchBudgetPdfData(db, budgetId);
    if (!data) {
      throw new NotFoundError("Orçamento não encontrado.");
    }

    const logoUrl = getLogoDataUrl();
    const { buildBudgetPdfHtml } = await loadPdfHelpers();
    const html = buildBudgetPdfHtml({
      budget: data.budget,
      client: data.client,
      signatureMode: data.budget.signature_mode,
      signatureScope: data.budget.signature_scope,
      signatureClient: data.budget.signature_client,
      signatureTech: data.budget.signature_tech,
      signaturePages: data.budget.signature_pages || {},
      logoUrl
    });
    const encodedToken = encodeURIComponent(token);
    const baseUrl = getPublicBaseUrl(req);

    return injectPublicToolbar(html, {
      title: `Orçamento #${budgetId}`,
      token,
      pdfUrl: `${baseUrl}/public/budgets/${budgetId}/pdf?token=${encodedToken}`,
      pdfDownloadUrl: `${baseUrl}/public/budgets/${budgetId}/pdf?token=${encodedToken}&download=1`,
      pdfFileName: `orcamento_${budgetId}.pdf`,
      refreshUrl: `${baseUrl}/public/budgets/${budgetId}?token=${encodedToken}`,
      approveBudget: { budgetId },
      statusLabel: data.budget.status
    });
  }

  async function approveTask(db, taskId, token, payload) {
    const link = await findValidLink(db, {
      table: "task_public_links",
      foreignKey: "task_id",
      id: taskId,
      token
    });
    if (!link) {
      throw new ValidationError("Link público inválido ou expirado.");
    }
    if (!payload.signature || !String(payload.signature).startsWith("data:image")) {
      throw new ValidationError("Assinatura inválida.");
    }

    const task = await db.get("SELECT signature_mode, signature_scope FROM tasks WHERE id = ?", [taskId]);
    let nextMode = task?.signature_mode || "client";
    if (nextMode === "none") nextMode = "client";
    if (nextMode === "tech") nextMode = "both";

    await db.run(
      `UPDATE tasks
       SET signature_client = ?,
           signature_client_name = ?,
           signature_client_document = ?,
           signature_mode = ?,
           signature_scope = ?
       WHERE id = ?`,
      [
        payload.signature,
        payload.name || null,
        payload.document || null,
        nextMode,
        task?.signature_scope || "last_page",
        taskId
      ]
    );

    scheduleWarmTaskPdfCache(db, taskId);
    return { ok: true };
  }

  async function approveBudget(db, budgetId, token, payload) {
    const link = await findValidLink(db, {
      table: "budget_public_links",
      foreignKey: "budget_id",
      id: budgetId,
      token
    });
    if (!link) {
      throw new ValidationError("Link público inválido ou expirado.");
    }
    if (!payload.signature || !String(payload.signature).startsWith("data:image")) {
      throw new ValidationError("Assinatura inválida.");
    }

    const budget = await db.get("SELECT signature_mode, signature_scope, task_id FROM budgets WHERE id = ?", [
      budgetId
    ]);
    let nextMode = budget?.signature_mode || "client";
    if (nextMode === "none") nextMode = "client";
    if (nextMode === "tech") nextMode = "both";

    await db.run(
      `UPDATE budgets
       SET signature_client = ?,
           signature_client_name = ?,
           signature_client_document = ?,
           signature_mode = ?,
           signature_scope = ?,
           status = 'aprovado'
       WHERE id = ?`,
      [
        payload.signature,
        payload.name || null,
        payload.document || null,
        nextMode,
        budget?.signature_scope || "last_page",
        budgetId
      ]
    );

    scheduleWarmBudgetPdfCache(db, budgetId);
    scheduleWarmTaskPdfCache(db, budget?.task_id);
    return { ok: true };
  }

  async function removeTaskSignature(db, taskId, token) {
    const link = await findValidLink(db, {
      table: "task_public_links",
      foreignKey: "task_id",
      id: taskId,
      token
    });
    if (!link) {
      throw new ValidationError("Link público inválido ou expirado.");
    }

    await db.run(
      `UPDATE tasks
       SET signature_client = NULL,
           signature_client_name = NULL,
           signature_client_document = NULL
       WHERE id = ?`,
      [taskId]
    );
    scheduleWarmTaskPdfCache(db, taskId);
    return { ok: true };
  }

  async function removeBudgetSignature(db, budgetId, token) {
    const link = await findValidLink(db, {
      table: "budget_public_links",
      foreignKey: "budget_id",
      id: budgetId,
      token
    });
    if (!link) {
      throw new ValidationError("Link público inválido ou expirado.");
    }

    const budget = await db.get("SELECT task_id FROM budgets WHERE id = ?", [budgetId]);
    await db.run(
      `UPDATE budgets
       SET signature_client = NULL,
           signature_client_name = NULL,
           signature_client_document = NULL,
           status = 'em_andamento'
       WHERE id = ?`,
      [budgetId]
    );
    scheduleWarmBudgetPdfCache(db, budgetId);
    scheduleWarmTaskPdfCache(db, budget?.task_id);
    return { ok: true };
  }

  return {
    fetchTaskPdfData,
    fetchBudgetPdfData,
    renderTaskPdf,
    renderBudgetPdf,
    getTaskPdfCacheStatus,
    getBudgetPdfCacheStatus,
    warmTaskPdf,
    warmBudgetPdf,
    scheduleWarmTaskPdfCache,
    scheduleWarmBudgetPdfCache,
    ensureTaskPublicLink,
    ensureBudgetPublicLink,
    renderPublicTaskPage,
    renderPublicBudgetPage,
    approveTask,
    approveBudget,
    removeTaskSignature,
    removeBudgetSignature
  };
}

module.exports = { createPublicService };
