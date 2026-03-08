const express = require("express");

const { PERMISSIONS } = require("../../config/contracts");
const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requirePermission } = require("../../core/security/auth");
const { ensureRequiredFields, normalizeId } = require("../../core/utils/validation");
const usersService = require("./users.service");

function createUsersRouter({ db }) {
  const router = express.Router();

  router.get(
    "/",
    requirePermission(PERMISSIONS.VIEW_USERS),
    asyncHandler(async (req, res) => {
      return send(res, await usersService.list(db));
    })
  );

  router.post(
    "/",
    requirePermission(PERMISSIONS.MANAGE_USERS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["name", "email", "password", "role"]);
      return sendCreated(res, await usersService.create(db, req.body));
    })
  );

  router.put(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_USERS),
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["name", "email", "role"]);
      return send(res, await usersService.update(db, normalizeId(req.params.id), req.body));
    })
  );

  router.delete(
    "/:id",
    requirePermission(PERMISSIONS.MANAGE_USERS),
    asyncHandler(async (req, res) => {
      return send(res, await usersService.remove(db, normalizeId(req.params.id)));
    })
  );

  return router;
}

module.exports = { createUsersRouter };
