const express = require("express");

const { NotFoundError } = require("../../core/errors/app-error");
const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requirePermission } = require("../../core/security/auth");
const { parseJsonFields, parseJsonList } = require("../../core/utils/json");
const { buildPayload, normalizeId } = require("../../core/utils/validation");
const {
  listRows,
  findRowById,
  createRow,
  updateRow,
  deleteRow
} = require("./resource.repository");

function createResourceRouter({ db, config }) {
  const router = express.Router();
  const {
    table,
    fields,
    jsonFields = [],
    orderBy = "id DESC",
    permissions = {}
  } = config;

  router.get(
    "/",
    permissions.view ? requirePermission(permissions.view) : (req, res, next) => next(),
    asyncHandler(async (req, res) => {
      const rows = await listRows(db, table, orderBy);
      return send(res, parseJsonList(rows, jsonFields));
    })
  );

  router.get(
    "/:id",
    permissions.view ? requirePermission(permissions.view) : (req, res, next) => next(),
    asyncHandler(async (req, res) => {
      const row = await findRowById(db, table, normalizeId(req.params.id));
      if (!row) {
        throw new NotFoundError();
      }
      return send(res, parseJsonFields(row, jsonFields));
    })
  );

  router.post(
    "/",
    permissions.manage ? requirePermission(permissions.manage) : (req, res, next) => next(),
    asyncHandler(async (req, res) => {
      const payload = buildPayload(req.body, fields, jsonFields);
      const row = await createRow(db, table, fields, payload);
      return sendCreated(res, parseJsonFields(row, jsonFields));
    })
  );

  router.put(
    "/:id",
    permissions.manage ? requirePermission(permissions.manage) : (req, res, next) => next(),
    asyncHandler(async (req, res) => {
      const id = normalizeId(req.params.id);
      const payload = buildPayload(req.body, fields, jsonFields);
      const row = await updateRow(db, table, id, fields, payload);
      return send(res, parseJsonFields(row, jsonFields));
    })
  );

  router.delete(
    "/:id",
    permissions.manage ? requirePermission(permissions.manage) : (req, res, next) => next(),
    asyncHandler(async (req, res) => {
      await deleteRow(db, table, normalizeId(req.params.id));
      return send(res, { ok: true });
    })
  );

  return router;
}

module.exports = { createResourceRouter };
