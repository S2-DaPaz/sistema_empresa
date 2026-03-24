const express = require("express");

const { asyncHandler } = require("../../core/http/async-handler");
const { send } = require("../../core/http/response");
const { normalizeId } = require("../../core/utils/validation");

function createPublicRouter({ db, publicService }) {
  const router = express.Router();

  router.get(
    "/tasks/:id",
    asyncHandler(async (req, res) => {
      try {
        const html = await publicService.renderPublicTaskPage(
          db,
          req,
          normalizeId(req.params.id),
          String(req.query.token || "")
        );
        res.setHeader("Content-Type", "text/html; charset=utf-8");
        res.setHeader("Cache-Control", "no-store");
        return res.send(html);
      } catch (error) {
        const html = publicService.renderFriendlyPublicError(req, {
          title: "Nao foi possivel abrir este relatorio",
          message:
            error?.statusCode === 404
              ? "O documento solicitado nao foi encontrado."
              : "Este link publico esta invalido, expirou ou nao pode mais ser usado.",
          detail: error?.message || "",
          statusCode: error?.statusCode || 400
        });
        res.setHeader("Content-Type", "text/html; charset=utf-8");
        res.setHeader("Cache-Control", "no-store");
        return res.status(error?.statusCode || 400).send(html);
      }
    })
  );

  router.post(
    "/tasks/:id/approve",
    asyncHandler(async (req, res) => {
      return send(
        res,
        await publicService.approveTask(
          db,
          normalizeId(req.params.id),
          String(req.query.token || req.body?.token || ""),
          {
            signature: req.body?.signature || "",
            name: req.body?.name ? String(req.body.name).trim() : "",
            document: req.body?.document ? String(req.body.document).trim() : ""
          }
        )
      );
    })
  );

  router.post(
    "/tasks/:id/signature/remove",
    asyncHandler(async (req, res) => {
      return send(
        res,
        await publicService.removeTaskSignature(
          db,
          normalizeId(req.params.id),
          String(req.query.token || req.body?.token || "")
        )
      );
    })
  );

  router.get(
    "/tasks/:id/pdf",
    asyncHandler(async (req, res) => {
      const token = String(req.query.token || "");
      await publicService.renderPublicTaskPage(db, req, normalizeId(req.params.id), token);
      const pdf = await publicService.renderTaskPdf(db, normalizeId(req.params.id), {
        forceRefresh: req.query.refresh === "1"
      });
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `${req.query.download === "1" ? "attachment" : "inline"}; filename="tarefa_${req.params.id}.pdf"`
      );
      return res.send(pdf);
    })
  );

  router.get(
    "/budgets/:id",
    asyncHandler(async (req, res) => {
      try {
        const html = await publicService.renderPublicBudgetPage(
          db,
          req,
          normalizeId(req.params.id),
          String(req.query.token || "")
        );
        res.setHeader("Content-Type", "text/html; charset=utf-8");
        res.setHeader("Cache-Control", "no-store");
        return res.send(html);
      } catch (error) {
        const html = publicService.renderFriendlyPublicError(req, {
          title: "Nao foi possivel abrir este orcamento",
          message:
            error?.statusCode === 404
              ? "A proposta solicitada nao foi encontrada."
              : "Este link publico esta invalido, expirou ou nao pode mais ser usado.",
          detail: error?.message || "",
          statusCode: error?.statusCode || 400
        });
        res.setHeader("Content-Type", "text/html; charset=utf-8");
        res.setHeader("Cache-Control", "no-store");
        return res.status(error?.statusCode || 400).send(html);
      }
    })
  );

  router.post(
    "/budgets/:id/approve",
    asyncHandler(async (req, res) => {
      return send(
        res,
        await publicService.approveBudget(
          db,
          normalizeId(req.params.id),
          String(req.query.token || req.body?.token || ""),
          {
            signature: req.body?.signature || "",
            name: req.body?.name ? String(req.body.name).trim() : "",
            document: req.body?.document ? String(req.body.document).trim() : ""
          }
        )
      );
    })
  );

  router.post(
    "/budgets/:id/signature/remove",
    asyncHandler(async (req, res) => {
      return send(
        res,
        await publicService.removeBudgetSignature(
          db,
          normalizeId(req.params.id),
          String(req.query.token || req.body?.token || "")
        )
      );
    })
  );

  router.get(
    "/budgets/:id/pdf",
    asyncHandler(async (req, res) => {
      const token = String(req.query.token || "");
      await publicService.renderPublicBudgetPage(db, req, normalizeId(req.params.id), token);
      const pdf = await publicService.renderBudgetPdf(db, normalizeId(req.params.id), {
        forceRefresh: req.query.refresh === "1"
      });
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `${req.query.download === "1" ? "attachment" : "inline"}; filename="orcamento_${req.params.id}.pdf"`
      );
      return res.send(pdf);
    })
  );

  return router;
}

module.exports = { createPublicRouter };
