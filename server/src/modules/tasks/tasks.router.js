const express = require("express");

const { PERMISSIONS } = require("../../config/contracts");
const { NotFoundError, ValidationError } = require("../../core/errors/app-error");
const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requirePermission } = require("../../core/security/auth");
const { parseJsonFields } = require("../../core/utils/json");
const { buildPayload, ensureRequiredFields, normalizeId } = require("../../core/utils/validation");
const { createReportForTask, syncReportForTask, createReportForEquipment } = require("./task-report.service");

function createTasksRouter({ db, publicService }) {
  const router = express.Router();

  router.get(
    "/",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("tasks.client_id = ?");
        params.push(req.query.clientId);
      }
      if (req.query.userId) {
        filters.push("tasks.user_id = ?");
        params.push(req.query.userId);
      }
      if (req.query.status) {
        filters.push("tasks.status = ?");
        params.push(req.query.status);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = await db.all(
        `SELECT tasks.*,
                clients.name AS client_name,
                clients.address AS client_address,
                clients.contact AS client_contact,
                users.name AS user_name,
                task_types.name AS task_type_name,
                task_types.report_template_id AS report_template_id,
                report_templates.name AS report_template_name,
                (
                  SELECT id
                  FROM reports
                  WHERE reports.task_id = tasks.id
                    AND reports.equipment_id IS NULL
                  ORDER BY reports.id DESC
                  LIMIT 1
                ) AS report_id
         FROM tasks
         LEFT JOIN clients ON clients.id = tasks.client_id
         LEFT JOIN users ON users.id = tasks.user_id
         LEFT JOIN task_types ON task_types.id = tasks.task_type_id
         LEFT JOIN report_templates ON report_templates.id = task_types.report_template_id
         ${where}
         ORDER BY tasks.id DESC`,
        params
      );
      return send(res, rows);
    })
  );

  router.get(
    "/:id",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const task = await db.get(
        `SELECT tasks.*,
                clients.name AS client_name,
                clients.address AS client_address,
                clients.contact AS client_contact,
                users.name AS user_name,
                task_types.name AS task_type_name,
                task_types.report_template_id AS report_template_id,
                report_templates.name AS report_template_name,
                (
                  SELECT id
                  FROM reports
                  WHERE reports.task_id = tasks.id
                    AND reports.equipment_id IS NULL
                  ORDER BY reports.id DESC
                  LIMIT 1
                ) AS report_id
         FROM tasks
         LEFT JOIN clients ON clients.id = tasks.client_id
         LEFT JOIN users ON users.id = tasks.user_id
         LEFT JOIN task_types ON task_types.id = tasks.task_type_id
         LEFT JOIN report_templates ON report_templates.id = task_types.report_template_id
         WHERE tasks.id = ?`,
        [normalizeId(req.params.id)]
      );
      if (!task) {
        throw new NotFoundError("Tarefa nao encontrada.");
      }
      return send(res, parseJsonFields(task, ["signature_pages"]));
    })
  );

  router.post(
    "/",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["title"]);
      const fields = [
        "title",
        "description",
        "client_id",
        "user_id",
        "task_type_id",
        "status",
        "priority",
        "start_date",
        "due_date",
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_tech",
        "signature_pages"
      ];
      const payload = buildPayload(req.body, fields, ["signature_pages"]);
      const result = await db.run(
        `INSERT INTO tasks (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
        fields.map((field) => payload[field])
      );
      const task = await db.get("SELECT * FROM tasks WHERE id = ?", [result.lastID]);
      await createReportForTask(db, task);
      publicService.scheduleWarmTaskPdfCache(db, task.id);
      return sendCreated(res, parseJsonFields(task, ["signature_pages"]));
    })
  );

  router.put(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const fields = [
        "title",
        "description",
        "client_id",
        "user_id",
        "task_type_id",
        "status",
        "priority",
        "start_date",
        "due_date",
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_tech",
        "signature_pages"
      ];
      const payload = buildPayload(req.body, fields, ["signature_pages"]);
      await db.run(
        `UPDATE tasks SET ${fields.map((field) => `${field} = ?`).join(", ")} WHERE id = ?`,
        [...fields.map((field) => payload[field]), id]
      );
      const task = await db.get("SELECT * FROM tasks WHERE id = ?", [id]);
      if (!task) {
        throw new NotFoundError("Tarefa nao encontrada.");
      }
      await syncReportForTask(db, task);
      publicService.scheduleWarmTaskPdfCache(db, id);
      return send(res, parseJsonFields(task, ["signature_pages"]));
    })
  );

  router.delete(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      await db.run("DELETE FROM tasks WHERE id = ?", [normalizeId(req.params.id)]);
      return send(res, { ok: true });
    })
  );

  router.get(
    "/:id/equipments",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const rows = await db.all(
        `SELECT equipments.*, task_equipments.created_at AS linked_at
         FROM task_equipments
         INNER JOIN equipments ON equipments.id = task_equipments.equipment_id
         WHERE task_equipments.task_id = ?
         ORDER BY equipments.name ASC`,
        [normalizeId(req.params.id)]
      );
      return send(res, rows);
    })
  );

  router.post(
    "/:id/equipments",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["equipment_id"]);
      const taskId = normalizeId(req.params.id);
      const task = await db.get("SELECT * FROM tasks WHERE id = ?", [taskId]);
      if (!task) throw new NotFoundError("Tarefa nao encontrada.");
      const equipment = await db.get("SELECT * FROM equipments WHERE id = ?", [
        normalizeId(req.body.equipment_id, "equipment_id")
      ]);
      if (!equipment) throw new NotFoundError("Equipamento não encontrado.");
      if (task.client_id && equipment.client_id !== task.client_id) {
        throw new ValidationError("O equipamento não pertence ao cliente da tarefa.");
      }
      await db.run(
        `INSERT OR IGNORE INTO task_equipments (task_id, equipment_id, created_at)
         VALUES (?, ?, ?)`,
        [taskId, equipment.id, new Date().toISOString()]
      );
      await createReportForEquipment(db, task, equipment);
      return sendCreated(res, { ok: true });
    })
  );

  router.delete(
    "/:id/equipments/:equipmentId",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      const taskId = normalizeId(req.params.id);
      const equipmentId = normalizeId(req.params.equipmentId, "equipmentId");
      await db.run("DELETE FROM task_equipments WHERE task_id = ? AND equipment_id = ?", [
        taskId,
        equipmentId
      ]);
      return send(res, { ok: true });
    })
  );

  router.post(
    "/:id/public-link",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const taskId = normalizeId(req.params.id);
      const task = await db.get("SELECT id FROM tasks WHERE id = ?", [taskId]);
      if (!task) throw new NotFoundError("Tarefa nao encontrada.");
      const link = await publicService.ensureTaskPublicLink(db, req, taskId, req.user?.id);
      publicService.scheduleWarmTaskPdfCache(db, taskId);
      return send(res, link);
    })
  );

  router.delete(
    "/:id/public-link/:linkId",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      const taskId = normalizeId(req.params.id);
      const linkId = normalizeId(req.params.linkId, "linkId");
      const link = await db.get("SELECT id FROM task_public_links WHERE id = ? AND task_id = ?", [
        linkId,
        taskId
      ]);
      if (!link) throw new NotFoundError("Link público não encontrado.");
      await db.run("UPDATE task_public_links SET revoked_at = ? WHERE id = ?", [
        new Date().toISOString(),
        link.id
      ]);
      return send(res, { ok: true });
    })
  );

  router.get(
    "/:id/pdf/status",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      return send(res, await publicService.getTaskPdfCacheStatus(db, normalizeId(req.params.id)));
    })
  );

  router.post(
    "/:id/pdf/warm",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const taskId = normalizeId(req.params.id);
      const status = await publicService.getTaskPdfCacheStatus(db, taskId);
      setImmediate(() => {
        publicService.warmTaskPdf(db, taskId, true).catch(() => {});
      });
      return send(res, { ...status, warming: true });
    })
  );

  router.get(
    "/:id/pdf",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const pdf = await publicService.renderTaskPdf(db, normalizeId(req.params.id), {
        forceRefresh: req.query.nocache === "1" || req.query.refresh === "1"
      });
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `inline; filename="tarefa_${req.params.id}.pdf"`);
      return res.send(pdf);
    })
  );

  return router;
}

module.exports = { createTasksRouter };
