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
      const summary = Object.fromEntries(counts);

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

      const recentTasks = await db.all(
        `SELECT tasks.id,
                tasks.title,
                tasks.status,
                tasks.priority,
                tasks.start_date,
                tasks.due_date,
                clients.name AS client_name,
                clients.address AS client_address
         FROM tasks
         LEFT JOIN clients ON clients.id = tasks.client_id
         ORDER BY COALESCE(tasks.start_date, tasks.due_date, '1970-01-01') DESC, tasks.id DESC
         LIMIT 6`
      );

      const recentBudgets = await db.all(
        `SELECT budgets.id,
                budgets.status,
                budgets.total,
                budgets.created_at,
                clients.name AS client_name,
                tasks.title AS task_title
         FROM budgets
         LEFT JOIN clients ON clients.id = budgets.client_id
         LEFT JOIN tasks ON tasks.id = budgets.task_id
         ORDER BY budgets.created_at DESC, budgets.id DESC
         LIMIT 6`
      );

      const taskBuckets = await db.all(
        `SELECT status, COUNT(*) AS total
         FROM tasks
         GROUP BY status`
      );

      const budgetBuckets = await db.all(
        `SELECT status, COUNT(*) AS total
         FROM budgets
         GROUP BY status`
      );
      const today = new Date().toISOString().slice(0, 10);
      const todayTasksRow = await db.get(
        `SELECT COUNT(*) AS total
         FROM tasks
         WHERE start_date = ? OR due_date = ?`,
        [today, today]
      );

      const taskStatusMap = Object.fromEntries(
        taskBuckets.map((row) => [row.status || "aberta", Number(row.total || 0)])
      );
      const budgetStatusMap = Object.fromEntries(
        budgetBuckets.map((row) => [row.status || "em_andamento", Number(row.total || 0)])
      );
      const todayTasks = Number(todayTasksRow?.total || 0);
      const notificationCount =
        Number(taskStatusMap.aberta || 0) + Number(taskStatusMap.em_andamento || 0);

      return send(res, {
        summary,
        recentReports,
        recentTasks,
        recentBudgets,
        taskMetrics: {
          total: Number(summary.tasks || 0),
          open: Number(taskStatusMap.aberta || 0),
          inProgress: Number(taskStatusMap.em_andamento || 0),
          completed: Number(taskStatusMap.concluida || 0),
          today: todayTasks
        },
        budgetMetrics: {
          total: Number(summary.budgets || 0),
          inProgress: Number(budgetStatusMap.em_andamento || 0),
          approved: Number(budgetStatusMap.aprovado || 0),
          rejected: Number(budgetStatusMap.recusado || 0)
        },
        notificationCount
      });
    })
  );

  return router;
}

module.exports = { createSummaryRouter };
