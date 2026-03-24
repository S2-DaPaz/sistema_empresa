const cors = require("cors");
const express = require("express");
const path = require("path");

const { PERMISSIONS } = require("../config/contracts");
const { asyncHandler } = require("../core/http/async-handler");
const { errorHandler } = require("../core/http/error-handler");
const { notFoundHandler } = require("../core/http/not-found-handler");
const { send } = require("../core/http/response");
const { createAuthMiddleware, requirePermission } = require("../core/security/auth");
const { createAuthRouter } = require("../modules/auth/auth.router");
const { createBackupsRouter } = require("../modules/backups/backups.router");
const { createBackupsService } = require("../modules/backups/backups.service");
const { createBudgetsRouter } = require("../modules/budgets/budgets.router");
const { createEquipmentsRouter } = require("../modules/equipments/equipments.router");
const { createMonitoringRouter } = require("../modules/monitoring/monitoring.router");
const { createPublicRouter } = require("../modules/public/public.router");
const { createReportsRouter } = require("../modules/reports/reports.router");
const { createResourceRouter } = require("../modules/resources/resource.router");
const { createRolesRouter } = require("../modules/roles/roles.router");
const { createSummaryRouter } = require("../modules/summary/summary.router");
const { createTasksRouter } = require("../modules/tasks/tasks.router");
const { createUsersRouter } = require("../modules/users/users.router");
const { findUserWithRoleById } = require("../modules/users/users.repository");
const { resolveStaticDir } = require("./static");

function createCorsOptions(env) {
  return {
    origin(origin, callback) {
      if (!origin || env.allowedOrigins.length === 0 || env.allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error("Origin not allowed by CORS"));
    }
  };
}

function createApp({ db, env, logger, publicService, monitoringService, emailService }) {
  const app = express();
  const backupsService = createBackupsService({ logger });

  app.use(cors(createCorsOptions(env)));
  app.use(express.json({ limit: "10mb" }));
  app.use(monitoringService.createRequestTrackingMiddleware(db));

  app.get("/api/health", (req, res) => {
    send(res, { ok: true });
  });

  app.get("/api/app/mobile-update", (req, res) => {
    if (!env.mobileUpdate.apkUrl || !env.mobileUpdate.versionCode) {
      return res.status(204).end();
    }
    return send(res, env.mobileUpdate);
  });

  app.post(
    "/api/monitoring/client-errors",
    asyncHandler(async (req, res) => {
      await monitoringService.recordClientError(db, req, req.body || {});
      return send(res, { ok: true }, { statusCode: 202 });
    })
  );

  app.use("/api", createAuthMiddleware({ db, env, findUserWithRoleById }));
  app.use("/api/auth", createAuthRouter({ db, env, emailService }));

  app.use("/api/admin", createMonitoringRouter({ db, monitoringService }));
  app.use("/api/backups", createBackupsRouter({ db, backupsService }));
  app.use("/api/summary", requirePermission(PERMISSIONS.VIEW_DASHBOARD), createSummaryRouter({ db }));
  app.use(
    "/api/clients",
    createResourceRouter({
      db,
      config: {
        table: "clients",
        fields: ["name", "cnpj", "address", "contact"],
        orderBy: "name ASC",
        permissions: {
          view: PERMISSIONS.VIEW_CLIENTS,
          manage: PERMISSIONS.MANAGE_CLIENTS
        }
      }
    })
  );
  app.use(
    "/api/products",
    createResourceRouter({
      db,
      config: {
        table: "products",
        fields: ["name", "sku", "price", "unit"],
        orderBy: "name ASC",
        permissions: {
          view: PERMISSIONS.VIEW_PRODUCTS,
          manage: PERMISSIONS.MANAGE_PRODUCTS
        }
      }
    })
  );
  app.use(
    "/api/task-types",
    createResourceRouter({
      db,
      config: {
        table: "task_types",
        fields: ["name", "description", "report_template_id"],
        orderBy: "name ASC",
        permissions: {
          view: PERMISSIONS.VIEW_TASK_TYPES,
          manage: PERMISSIONS.MANAGE_TASK_TYPES
        }
      }
    })
  );
  app.use(
    "/api/report-templates",
    createResourceRouter({
      db,
      config: {
        table: "report_templates",
        fields: ["name", "description", "structure"],
        jsonFields: ["structure"],
        orderBy: "name ASC",
        permissions: {
          view: PERMISSIONS.VIEW_TEMPLATES,
          manage: PERMISSIONS.MANAGE_TEMPLATES
        }
      }
    })
  );
  app.use("/api/users", requirePermission(PERMISSIONS.VIEW_USERS), createUsersRouter({ db }));
  app.use("/api/roles", requirePermission(PERMISSIONS.VIEW_USERS), createRolesRouter({ db }));
  app.use("/api/equipments", requirePermission(PERMISSIONS.VIEW_TASKS), createEquipmentsRouter({ db }));
  app.use(
    "/api/tasks",
    requirePermission(PERMISSIONS.VIEW_TASKS),
    createTasksRouter({ db, publicService, emailService })
  );
  app.use("/api/reports", requirePermission(PERMISSIONS.VIEW_TASKS), createReportsRouter({ db, publicService }));
  app.use(
    "/api/budgets",
    requirePermission(PERMISSIONS.VIEW_BUDGETS),
    createBudgetsRouter({ db, publicService, emailService })
  );
  app.use("/public", createPublicRouter({ db, publicService }));

  const staticDir = resolveStaticDir(env.staticDir);
  if (staticDir) {
    app.use(express.static(staticDir));
    app.get("*", (req, res, next) => {
      if (req.path.startsWith("/api")) {
        return next();
      }
      return res.sendFile(path.join(staticDir, "index.html"));
    });
    } else {
      app.get("/", (req, res) => {
        res.status(404).send("Front-end não encontrado. Gere o build de web/dist.");
      });
    }

  app.use(notFoundHandler);
  app.use(errorHandler({ logger, monitoringService, db }));

  return app;
}

module.exports = { createApp };
