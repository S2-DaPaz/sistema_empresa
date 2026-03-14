const express = require("express");

const { PERMISSIONS } = require("../../config/contracts");
const { NotFoundError, ValidationError } = require("../../core/errors/app-error");
const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requirePermission } = require("../../core/security/auth");
const { buildPayload, ensureRequiredFields, normalizeId } = require("../../core/utils/validation");
const { createReportForEquipment } = require("../tasks/task-report.service");

function createEquipmentsRouter({ db }) {
  const router = express.Router();

  router.get(
    "/",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("equipments.client_id = ?");
        params.push(req.query.clientId);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = await db.all(
        `SELECT equipments.*, clients.name AS client_name
         FROM equipments
         LEFT JOIN clients ON clients.id = equipments.client_id
         ${where}
         ORDER BY equipments.id DESC`,
        params
      );
      return send(res, rows);
    })
  );

  router.get(
    "/:id",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const equipment = await db.get(
        `SELECT equipments.*, clients.name AS client_name
         FROM equipments
         LEFT JOIN clients ON clients.id = equipments.client_id
         WHERE equipments.id = ?`,
        [normalizeId(req.params.id)]
        );
        if (!equipment) {
          throw new NotFoundError("Equipamento não encontrado.");
        }
      return send(res, equipment);
    })
  );

  router.post(
    "/",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["client_id", "name"]);
      const fields = ["client_id", "name", "model", "serial", "description", "created_at"];
      const payload = buildPayload(
        { ...req.body, created_at: req.body.created_at || new Date().toISOString() },
        fields
      );
      const result = await db.run(
        `INSERT INTO equipments (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
        fields.map((field) => payload[field])
      );
      const equipment = await db.get("SELECT * FROM equipments WHERE id = ?", [result.lastID]);
      return sendCreated(res, equipment);
    })
  );

  router.put(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const fields = ["client_id", "name", "model", "serial", "description", "created_at"];
      const payload = buildPayload(
        { ...req.body, created_at: req.body.created_at || new Date().toISOString() },
        fields
      );
      await db.run(
        `UPDATE equipments SET ${fields.map((field) => `${field} = ?`).join(", ")} WHERE id = ?`,
        [...fields.map((field) => payload[field]), id]
      );
      const equipment = await db.get("SELECT * FROM equipments WHERE id = ?", [id]);
      return send(res, equipment);
    })
  );

  router.delete(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      await db.run("DELETE FROM equipments WHERE id = ?", [normalizeId(req.params.id)]);
      return send(res, { ok: true });
    })
  );

  router.get(
    "/task/:taskId",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    asyncHandler(async (req, res) => {
      const rows = await db.all(
        `SELECT equipments.*, task_equipments.created_at AS linked_at
         FROM task_equipments
         INNER JOIN equipments ON equipments.id = task_equipments.equipment_id
         WHERE task_equipments.task_id = ?
         ORDER BY equipments.name ASC`,
        [normalizeId(req.params.taskId)]
      );
      return send(res, rows);
    })
  );

  router.post(
    "/task/:taskId",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["equipment_id"]);
      const taskId = normalizeId(req.params.taskId);
      const task = await db.get("SELECT * FROM tasks WHERE id = ?", [taskId]);
      if (!task) {
        throw new NotFoundError("Tarefa nao encontrada.");
      }
      const equipment = await db.get("SELECT * FROM equipments WHERE id = ?", [
        normalizeId(req.body.equipment_id, "equipment_id")
        ]);
        if (!equipment) {
          throw new NotFoundError("Equipamento não encontrado.");
        }
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
    "/task/:taskId/:equipmentId",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    asyncHandler(async (req, res) => {
      await db.run("DELETE FROM task_equipments WHERE task_id = ? AND equipment_id = ?", [
        normalizeId(req.params.taskId),
        normalizeId(req.params.equipmentId, "equipmentId")
      ]);
      return send(res, { ok: true });
    })
  );

  return router;
}

module.exports = { createEquipmentsRouter };
