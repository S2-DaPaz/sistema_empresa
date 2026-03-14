const express = require("express");

const { NotFoundError } = require("../../core/errors/app-error");
const { asyncHandler } = require("../../core/http/async-handler");
const { send } = require("../../core/http/response");
const { requireAdmin } = require("../../core/security/auth");
const { normalizeId } = require("../../core/utils/validation");

function createMonitoringRouter({ db, monitoringService }) {
  const router = express.Router();

  router.get(
    "/error-logs",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const result = await monitoringService.listErrorLogs(db, req.query);
      return send(res, result.items, {
        meta: {
          total: result.total,
          page: result.page,
          pageSize: result.pageSize
        }
      });
    })
  );

  router.get(
    "/error-logs/:id",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const item = await monitoringService.getErrorLog(db, normalizeId(req.params.id));
      if (!item) {
        throw new NotFoundError("Log de erro nao encontrado.");
      }
      return send(res, item);
    })
  );

  router.post(
    "/error-logs/:id/resolve",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const item = await monitoringService.resolveErrorLog(
        db,
        normalizeId(req.params.id),
        req.body || {},
        req.user
      );
      if (!item) {
        throw new NotFoundError("Log de erro nao encontrado.");
      }
      return send(res, item);
    })
  );

  router.get(
    "/event-logs",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const result = await monitoringService.listEventLogs(db, req.query);
      return send(res, result.items, {
        meta: {
          total: result.total,
          page: result.page,
          pageSize: result.pageSize
        }
      });
    })
  );

  router.get(
    "/event-logs/:id",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const item = await monitoringService.getEventLog(db, normalizeId(req.params.id));
      if (!item) {
        throw new NotFoundError("Log de evento nao encontrado.");
      }
      return send(res, item);
    })
  );

  return router;
}

module.exports = { createMonitoringRouter };
