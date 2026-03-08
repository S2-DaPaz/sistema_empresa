const express = require("express");

const { PERMISSIONS } = require("../../config/contracts");
const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requirePermission } = require("../../core/security/auth");
const { normalizeId } = require("../../core/utils/validation");
const { create, list, update, remove } = require("./roles.service");

function createRolesRouter({ db }) {
  const router = express.Router();

  router.get(
    "/",
    requirePermission(PERMISSIONS.VIEW_USERS),
    asyncHandler(async (req, res) => {
      return send(res, await list(db));
    })
  );

  router.post(
    "/",
    requirePermission(PERMISSIONS.MANAGE_USERS),
    asyncHandler(async (req, res) => {
      return sendCreated(res, await create(db, req.body));
    })
  );

  router.put(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_USERS),
    asyncHandler(async (req, res) => {
      return send(res, await update(db, normalizeId(req.params.id), req.body));
    })
  );

  router.delete(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_USERS),
    asyncHandler(async (req, res) => {
      return send(res, await remove(db, normalizeId(req.params.id)));
    })
  );

  return router;
}

module.exports = { createRolesRouter };
