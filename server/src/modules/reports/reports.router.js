const express = require("express");

const { PERMISSIONS } = require("../../config/contracts");
const { NotFoundError } = require("../../core/errors/app-error");
const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requirePermission } = require("../../core/security/auth");
const { parseJsonFields, parseJsonList } = require("../../core/utils/json");
const { buildPayload, ensureRequiredFields, normalizeId } = require("../../core/utils/validation");

function createReportsRouter({ db, publicService }) {
  const router = express.Router();

  router.get(
    "/",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("reports.client_id = ?");
        params.push(req.query.clientId);
      }
      if (req.query.taskId) {
        filters.push("reports.task_id = ?");
        params.push(req.query.taskId);
      }
      if (req.query.equipmentId) {
        filters.push("reports.equipment_id = ?");
        params.push(req.query.equipmentId);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = await db.all(
        `SELECT reports.*,
                clients.name AS client_name,
                tasks.title AS task_title,
                report_templates.name AS template_name,
                equipments.name AS equipment_name
         FROM reports
         LEFT JOIN clients ON clients.id = reports.client_id
         LEFT JOIN tasks ON tasks.id = reports.task_id
         LEFT JOIN report_templates ON report_templates.id = reports.template_id
         LEFT JOIN equipments ON equipments.id = reports.equipment_id
         ${where}
         ORDER BY reports.id DESC`,
        params
      );
      return send(res, parseJsonList(rows, ["content"]));
    })
  );

  router.get(
    "/:id",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const report = await db.get(
        `SELECT reports.*,
                clients.name AS client_name,
                tasks.title AS task_title,
                report_templates.name AS template_name,
                equipments.name AS equipment_name
         FROM reports
         LEFT JOIN clients ON clients.id = reports.client_id
         LEFT JOIN tasks ON tasks.id = reports.task_id
         LEFT JOIN report_templates ON report_templates.id = reports.template_id
         LEFT JOIN equipments ON equipments.id = reports.equipment_id
         WHERE reports.id = ?`,
        [normalizeId(req.params.id)]
        );
        if (!report) {
          throw new NotFoundError("Relatório não encontrado.");
        }
      return send(res, parseJsonFields(report, ["content"]));
    })
  );

  router.post(
    "/",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["client_id", "template_id"]);
      const fields = [
        "title",
        "task_id",
        "client_id",
        "template_id",
        "equipment_id",
        "content",
        "status",
        "created_at"
      ];
      const payload = buildPayload(
        { ...req.body, created_at: req.body.created_at || new Date().toISOString() },
        fields,
        ["content"]
      );
      const result = await db.run(
        `INSERT INTO reports (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
        fields.map((field) => payload[field])
      );
      const report = await db.get("SELECT * FROM reports WHERE id = ?", [result.lastID]);
      publicService.scheduleWarmTaskPdfCache(db, report?.task_id);
      return sendCreated(res, parseJsonFields(report, ["content"]));
    })
  );

  router.put(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const fields = [
        "title",
        "task_id",
        "client_id",
        "template_id",
        "equipment_id",
        "content",
        "status",
        "created_at"
      ];
      const payload = buildPayload(
        { ...req.body, created_at: req.body.created_at || new Date().toISOString() },
        fields,
        ["content"]
      );
      await db.run(
        `UPDATE reports SET ${fields.map((field) => `${field} = ?`).join(", ")} WHERE id = ?`,
        [...fields.map((field) => payload[field]), id]
      );
      const report = await db.get("SELECT * FROM reports WHERE id = ?", [id]);
      publicService.scheduleWarmTaskPdfCache(db, report?.task_id);
      return send(res, parseJsonFields(report, ["content"]));
    })
  );

  router.delete(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const existing = await db.get("SELECT task_id FROM reports WHERE id = ?", [id]);
      await db.run("DELETE FROM reports WHERE id = ?", [id]);
      publicService.scheduleWarmTaskPdfCache(db, existing?.task_id);
      return send(res, { ok: true });
    })
  );

  return router;
}

module.exports = { createReportsRouter };
