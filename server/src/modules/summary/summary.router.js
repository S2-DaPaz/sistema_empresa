const express = require("express");

const { asyncHandler } = require("../../core/http/async-handler");
const { send } = require("../../core/http/response");

function toNumber(value) {
  return Number(value || 0);
}

function normalizeActivity(items) {
  return items
    .filter(Boolean)
    .sort((left, right) => {
      const leftTime = Date.parse(left.createdAt || "") || 0;
      const rightTime = Date.parse(right.createdAt || "") || 0;
      return rightTime - leftTime;
    })
    .slice(0, 6);
}

function createSummaryRouter({ db }) {
  const router = express.Router();

  router.get(
    "/",
    asyncHandler(async (req, res) => {
      const tables = ["clients", "tasks", "reports", "budgets", "products", "users"];
      const counts = await Promise.all(
        tables.map(async (table) => {
          const row = await db.get(`SELECT COUNT(*) AS total FROM ${table}`);
          return [table, toNumber(row?.total)];
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

      const recentTasks = await db.all(
        `SELECT tasks.id,
                tasks.title,
                tasks.status,
                tasks.start_date,
                tasks.due_date,
                clients.name AS client_name
         FROM tasks
         LEFT JOIN clients ON clients.id = tasks.client_id
         ORDER BY COALESCE(tasks.start_date, tasks.due_date, tasks.id) DESC, tasks.id DESC
         LIMIT 4`
      );

      const recentBudgets = await db.all(
        `SELECT budgets.id,
                budgets.status,
                budgets.created_at,
                budgets.total,
                clients.name AS client_name
         FROM budgets
         LEFT JOIN clients ON clients.id = budgets.client_id
         ORDER BY budgets.created_at DESC, budgets.id DESC
         LIMIT 4`
      );

      const nowIso = new Date().toISOString();
      const todayKey = nowIso.slice(0, 10);

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

      const draftReportsRow = await db.get(
        `SELECT COUNT(*) AS total
         FROM reports
         WHERE COALESCE(status, 'rascunho') = 'rascunho'`
      );

      const taskBuckets = await db.get(
        `SELECT
            SUM(CASE WHEN COALESCE(status, 'aberta') = 'aberta' THEN 1 ELSE 0 END) AS open_total,
            SUM(CASE WHEN status = 'em_andamento' THEN 1 ELSE 0 END) AS in_progress_total,
            SUM(CASE WHEN status = 'concluida' THEN 1 ELSE 0 END) AS completed_total,
            SUM(CASE WHEN start_date LIKE ? THEN 1 ELSE 0 END) AS today_total
         FROM tasks`,
        [`${todayKey}%`]
      );

      const budgetTotalsRow = await db.get(
        `SELECT COUNT(*) AS total,
                SUM(CASE WHEN status = 'aprovado' THEN 1 ELSE 0 END) AS approved
         FROM budgets`
      );

      const activeSessionsRow = await db.get(
        `SELECT COUNT(*) AS total
         FROM auth_sessions
         WHERE revoked_at IS NULL
           AND (expires_at IS NULL OR expires_at > ?)`,
        [nowIso]
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

      const totalBudgets = toNumber(budgetTotalsRow?.total);
      const approvedBudgets = toNumber(budgetTotalsRow?.approved);

      const recentActivity = normalizeActivity([
        ...recentTasks.map((task) => ({
          kind: "task",
          id: task.id,
          title: task.title || `Tarefa #${task.id}`,
          subtitle: task.client_name || "Sem cliente",
          status: task.status || "aberta",
          createdAt: task.start_date || task.due_date || nowIso
        })),
        ...recentReports.map((report) => ({
          kind: "report",
          id: report.id,
          title: report.title || `REL #${report.id}`,
          subtitle: report.client_name || report.task_title || "Sem contexto",
          status: report.status || "rascunho",
          createdAt: report.created_at
        })),
        ...recentBudgets.map((budget) => ({
          kind: "budget",
          id: budget.id,
          title: `Orcamento #${budget.id}`,
          subtitle: budget.client_name || "Sem cliente",
          status: budget.status || "em_andamento",
          createdAt: budget.created_at
        }))
      ]);

      const notificationsCount =
        toNumber(overdueTasksRow?.total) +
        toNumber(pendingBudgetsRow?.total) +
        toNumber(draftReportsRow?.total);

      return send(res, {
        summary: Object.fromEntries(counts),
        recentReports,
        recentActivity,
        notifications: {
          count: notificationsCount
        },
        metrics: {
          overdueTasks: toNumber(overdueTasksRow?.total),
          pendingBudgets: toNumber(pendingBudgetsRow?.total),
          draftReports: toNumber(draftReportsRow?.total),
          openTasks: toNumber(taskBuckets?.open_total),
          inProgressTasks: toNumber(taskBuckets?.in_progress_total),
          completedTasks: toNumber(taskBuckets?.completed_total),
          todayTasks: toNumber(taskBuckets?.today_total),
          activeSessions: toNumber(activeSessionsRow?.total),
          budgetConversionRate:
            totalBudgets > 0 ? Number(((approvedBudgets / totalBudgets) * 100).toFixed(1)) : 0,
          busiestTechnician: busiestTechnician
            ? {
                id: busiestTechnician.id,
                name: busiestTechnician.name,
                taskCount: toNumber(busiestTechnician.task_count)
              }
            : null
        }
      });
    })
  );

  return router;
}

module.exports = { createSummaryRouter };
