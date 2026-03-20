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

      const nowIso = new Date().toISOString();
      const overdueTasksRow = await db.get(
        `SELECT COUNT(*) AS total
         FROM tasks
         WHERE due_date IS NOT NULL
           AND due_date != ''
           AND due_date < ?
           AND COALESCE(status, '') != 'concluida'`,
        [nowIso]
      );

      const pendingBudgetsRow = await db.get(
        `SELECT COUNT(*) AS total
         FROM budgets
         WHERE COALESCE(status, 'em_andamento') NOT IN ('aprovado', 'recusado')`
      );

      const budgetTotalsRow = await db.get(
        `SELECT COUNT(*) AS total,
                SUM(CASE WHEN status = 'aprovado' THEN 1 ELSE 0 END) AS approved
         FROM budgets`
      );

      const busiestTechnician = await db.get(
        `SELECT users.id,
                users.name,
                COUNT(tasks.id) AS task_count
         FROM tasks
         INNER JOIN users ON users.id = tasks.user_id
         WHERE COALESCE(tasks.status, '') != 'concluida'
         GROUP BY users.id, users.name
         ORDER BY task_count DESC, users.name ASC
         LIMIT 1`
      );

      const totalBudgets = Number(budgetTotalsRow?.total || 0);
      const approvedBudgets = Number(budgetTotalsRow?.approved || 0);

      return send(res, {
        summary: Object.fromEntries(counts),
        recentReports,
        metrics: {
          overdueTasks: Number(overdueTasksRow?.total || 0),
          pendingBudgets: Number(pendingBudgetsRow?.total || 0),
          budgetConversionRate:
            totalBudgets > 0 ? Number(((approvedBudgets / totalBudgets) * 100).toFixed(1)) : 0,
          busiestTechnician: busiestTechnician
            ? {
                id: busiestTechnician.id,
                name: busiestTechnician.name,
                taskCount: Number(busiestTechnician.task_count || 0)
              }
            : null
        }
      });
    })
  );

  return router;
}

module.exports = { createSummaryRouter };
