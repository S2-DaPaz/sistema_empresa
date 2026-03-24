const express = require("express");

const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { requireAdmin } = require("../../core/security/auth");
const { normalizeId } = require("../../core/utils/validation");
const { NotFoundError, ForbiddenError } = require("../../core/errors/app-error");
const { listBackupRuns, getBackupRun } = require("./backups.repository");

function createBackupsRouter({ db, backupsService }) {
  const router = express.Router();

  router.get(
    "/",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const page = Math.max(1, Number(req.query.page) || 1);
      const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize) || 20));
      const result = await listBackupRuns(db, { page, pageSize });
      return send(res, result.items, {
        meta: { total: result.total, page: result.page, pageSize: result.pageSize }
      });
    })
  );

  router.get(
    "/:id",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const item = await getBackupRun(db, normalizeId(req.params.id));
      if (!item) {
        throw new NotFoundError("Registro de backup não encontrado.");
      }
      return send(res, item);
    })
  );

  router.post(
    "/trigger",
    requireAdmin,
    asyncHandler(async (req, res) => {
      const id = await backupsService.recordManualTrigger(db, req.user);
      const item = await getBackupRun(db, id);
      return sendCreated(res, item);
    })
  );

  router.post(
    "/webhook",
    asyncHandler(async (req, res) => {
      const secret = req.headers["x-backup-secret"];
      const expected = process.env.BACKUP_WEBHOOK_SECRET;
      if (!expected || secret !== expected) {
        throw new ForbiddenError("Segredo de webhook inválido.");
      }

      const { action, ...payload } = req.body || {};

      if (action === "start") {
        const id = await backupsService.recordGithubActionStart(db, payload);
        return sendCreated(res, { backup_run_id: id });
      }

      if (action === "complete") {
        if (!payload.backup_run_id) {
          throw new NotFoundError("backup_run_id é obrigatório.");
        }
        await backupsService.recordGithubActionComplete(db, payload.backup_run_id, payload);
        const item = await getBackupRun(db, payload.backup_run_id);
        return send(res, item);
      }

      return send(res, { error: "Ação desconhecida." }, { statusCode: 400 });
    })
  );

  return router;
}

module.exports = { createBackupsRouter };
