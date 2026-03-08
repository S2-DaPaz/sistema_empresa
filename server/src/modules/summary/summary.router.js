const express = require("express");

const { asyncHandler } = require("../../core/http/async-handler");
const { send } = require("../../core/http/response");

function createSummaryRouter({ db }) {
  const router = express.Router();

  router.get(
    "/",
    asyncHandler(async (req, res) => {
      const tables = ["clients", "tasks", "reports", "budgets", "products", "users"];
      const counts = await Promise.all(
        tables.map(async (table) => {
          const row = await db.get(`SELECT COUNT(*) AS total FROM ${table}`);
          return [table, Number(row?.total || 0)];
        })
      );

      const recentReports = await db.all(
        `SELECT reports.id,
                reports.title,
                reports.status,
                reports.created_at,
                clients.name AS client_name,
                tasks.title AS task_title
         FROM reports
         LEFT JOIN clients ON clients.id = reports.client_id
         LEFT JOIN tasks ON tasks.id = reports.task_id
         ORDER BY reports.created_at DESC, reports.id DESC
         LIMIT 5`
      );

      return send(res, {
        summary: Object.fromEntries(counts),
        recentReports
      });
    })
  );

  return router;
}

module.exports = { createSummaryRouter };
