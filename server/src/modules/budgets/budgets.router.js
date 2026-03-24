const express = require("express");

const { PERMISSIONS } = require("../../config/contracts");
const { NotFoundError } = require("../../core/errors/app-error");
const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requirePermission } = require("../../core/security/auth");
const { parseJsonFields, parseJsonList } = require("../../core/utils/json");
const { buildPayload, ensureRequiredFields, normalizeId, toNumber } = require("../../core/utils/validation");
const { calcBudgetTotals } = require("../../core/utils/budgets");

function normalizeBudgetItems(items) {
  return (Array.isArray(items) ? items : []).map((item) => {
    const qty = toNumber(item.qty || 0);
    const unitPrice = toNumber(item.unit_price || 0);
    return {
      product_id: item.product_id || null,
      description: item.description || "Item",
      qty,
      unit_price: unitPrice,
      total: qty * unitPrice
    };
  });
}

async function loadBudgetItems(db, budgets) {
  if (!budgets.length) return budgets;
  const ids = budgets.map((budget) => budget.id);
  const placeholders = ids.map(() => "?").join(", ");
  const items = await db.all(`SELECT * FROM budget_items WHERE budget_id IN (${placeholders})`, ids);
  const grouped = new Map();
  items.forEach((item) => {
    if (!grouped.has(item.budget_id)) grouped.set(item.budget_id, []);
    grouped.get(item.budget_id).push(item);
  });
  budgets.forEach((budget) => {
    budget.items = grouped.get(budget.id) || [];
  });
  return budgets;
}

function createBudgetsRouter({ db, publicService }) {
  const router = express.Router();

  router.get(
    "/",
    requirePermission(PERMISSIONS.VIEW_BUDGETS),
    asyncHandler(async (req, res) => {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("budgets.client_id = ?");
        params.push(req.query.clientId);
      }
      if (req.query.taskId) {
        filters.push("budgets.task_id = ?");
        params.push(req.query.taskId);
      }
      if (req.query.reportId) {
        filters.push("budgets.report_id = ?");
        params.push(req.query.reportId);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = parseJsonList(
        await db.all(
          `SELECT budgets.*,
                  clients.name AS client_name,
                  reports.title AS report_title,
                  tasks.title AS task_title
           FROM budgets
           LEFT JOIN clients ON clients.id = budgets.client_id
           LEFT JOIN reports ON reports.id = budgets.report_id
           LEFT JOIN tasks ON tasks.id = budgets.task_id
           ${where}
           ORDER BY budgets.id DESC`,
          params
        ),
        ["signature_pages"]
      );
      if (req.query.includeItems === "1") {
        await loadBudgetItems(db, rows);
      }
      return send(res, rows);
    })
  );

  router.get(
    "/:id",
    requirePermission(PERMISSIONS.VIEW_BUDGETS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
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
          [id]
        ),
        ["signature_pages"]
        );
        if (!budget) {
          throw new NotFoundError("Orçamento não encontrado.");
        }
      budget.items = await db.all("SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC", [id]);
      return send(res, budget);
    })
  );

  router.get(
    "/:id/pdf/status",
    requirePermission(PERMISSIONS.VIEW_BUDGETS),
    asyncHandler(async (req, res) => {
      return send(res, await publicService.getBudgetPdfCacheStatus(db, normalizeId(req.params.id)));
    })
  );

  router.post(
    "/:id/pdf/warm",
    requirePermission(PERMISSIONS.VIEW_BUDGETS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const status = await publicService.getBudgetPdfCacheStatus(db, id);
      setImmediate(() => {
        publicService.warmBudgetPdf(db, id, true).catch(() => {});
      });
      return send(res, { ...status, warming: true });
    })
  );

  router.get(
    "/:id/pdf",
    requirePermission(PERMISSIONS.VIEW_BUDGETS),
    asyncHandler(async (req, res) => {
      const pdf = await publicService.renderBudgetPdf(db, normalizeId(req.params.id), {
        forceRefresh: req.query.nocache === "1" || req.query.refresh === "1"
      });
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `inline; filename="orcamento_${req.params.id}.pdf"`);
      return res.send(pdf);
    })
  );

  router.post(
    "/:id/public-link",
    requirePermission(PERMISSIONS.VIEW_BUDGETS),
    asyncHandler(async (req, res) => {
        const budgetId = normalizeId(req.params.id);
        const budget = await db.get("SELECT id FROM budgets WHERE id = ?", [budgetId]);
      if (!budget) throw new NotFoundError("Orçamento não encontrado.");
        const link = await publicService.ensureBudgetPublicLink(db, req, budgetId, req.user?.id);
      publicService.scheduleWarmBudgetPdfCache(db, budgetId);
      return send(res, link);
    })
  );

  router.post(
    "/",
    requirePermission(PERMISSIONS.MANAGE_BUDGETS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["client_id"]);
      const items = normalizeBudgetItems(req.body.items);
      const totals = calcBudgetTotals(items, req.body.discount, req.body.tax);
      const fields = [
        "client_id",
        "task_id",
        "report_id",
        "notes",
        "internal_note",
        "proposal_validity",
        "payment_terms",
        "service_deadline",
        "product_validity",
        "status",
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_client_name",
        "signature_client_document",
        "signature_tech",
        "signature_pages",
        "subtotal",
        "discount",
        "tax",
        "total",
        "created_at"
      ];
      const payload = buildPayload(
        {
          ...req.body,
          ...totals,
          created_at: req.body.created_at || new Date().toISOString()
        },
        fields,
        ["signature_pages"]
      );
      const result = await db.run(
        `INSERT INTO budgets (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
        fields.map((field) => payload[field])
      );
      for (const item of items) {
        await db.run(
          `INSERT INTO budget_items (budget_id, product_id, description, qty, unit_price, total)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [result.lastID, item.product_id, item.description, item.qty, item.unit_price, item.total]
        );
      }
      const budget = parseJsonFields(await db.get("SELECT * FROM budgets WHERE id = ?", [result.lastID]), [
        "signature_pages"
      ]);
      budget.items = await db.all("SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC", [
        result.lastID
      ]);
      publicService.scheduleWarmBudgetPdfCache(db, budget?.id);
      publicService.scheduleWarmTaskPdfCache(db, budget?.task_id);
      return sendCreated(res, budget);
    })
  );

  router.put(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_BUDGETS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const existing = await db.get("SELECT * FROM budgets WHERE id = ?", [id]);
      if (!existing) {
        throw new NotFoundError("Orçamento não encontrado.");
      }
      const items = normalizeBudgetItems(req.body.items);
      const totals = calcBudgetTotals(items, req.body.discount, req.body.tax);
      const fields = [
        "client_id",
        "task_id",
        "report_id",
        "notes",
        "internal_note",
        "proposal_validity",
        "payment_terms",
        "service_deadline",
        "product_validity",
        "status",
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_client_name",
        "signature_client_document",
        "signature_tech",
        "signature_pages",
        "subtotal",
        "discount",
        "tax",
        "total",
        "created_at"
      ];
      const payload = buildPayload(
        {
          ...req.body,
          ...totals,
          created_at: req.body.created_at || existing.created_at
        },
        fields,
        ["signature_pages"]
      );
      await db.run(
        `UPDATE budgets SET ${fields.map((field) => `${field} = ?`).join(", ")} WHERE id = ?`,
        [...fields.map((field) => payload[field]), id]
      );
      await db.run("DELETE FROM budget_items WHERE budget_id = ?", [id]);
      for (const item of items) {
        await db.run(
          `INSERT INTO budget_items (budget_id, product_id, description, qty, unit_price, total)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [id, item.product_id, item.description, item.qty, item.unit_price, item.total]
        );
      }
      const budget = parseJsonFields(await db.get("SELECT * FROM budgets WHERE id = ?", [id]), [
        "signature_pages"
      ]);
      budget.items = await db.all("SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC", [id]);
      publicService.scheduleWarmBudgetPdfCache(db, budget?.id);
      publicService.scheduleWarmTaskPdfCache(db, budget?.task_id);
      return send(res, budget);
    })
  );

  router.delete(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_BUDGETS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const existing = await db.get("SELECT task_id FROM budgets WHERE id = ?", [id]);
      await db.run("DELETE FROM budgets WHERE id = ?", [id]);
      publicService.scheduleWarmTaskPdfCache(db, existing?.task_id);
      return send(res, { ok: true });
    })
  );

  return router;
}

module.exports = { createBudgetsRouter };
