const { ForbiddenError, NotFoundError } = require("../errors/app-error");
const { send } = require("../http/response");

const VISITOR_ROLE = "visitante";
const PROTECTED_PREFIXES = [
  "/admin",
  "/backups",
  "/budgets",
  "/clients",
  "/equipments",
  "/products",
  "/reports",
  "/report-templates",
  "/roles",
  "/summary",
  "/task-types",
  "/tasks",
  "/users"
];

const EMPTY_COLLECTION_PATTERNS = [
  /^\/admin\/error-logs\/?$/u,
  /^\/admin\/event-logs\/?$/u,
  /^\/budgets\/?$/u,
  /^\/clients\/?$/u,
  /^\/equipments\/?$/u,
  /^\/equipments\/task\/\d+\/?$/u,
  /^\/products\/?$/u,
  /^\/reports\/?$/u,
  /^\/report-templates\/?$/u,
  /^\/roles\/?$/u,
  /^\/task-types\/?$/u,
  /^\/tasks\/?$/u,
  /^\/tasks\/\d+\/equipments\/?$/u,
  /^\/users\/?$/u
];

function isVisitorUser(user) {
  return String(user?.role || "").trim().toLowerCase() === VISITOR_ROLE;
}

function isProtectedPath(pathname) {
  return PROTECTED_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

function matchesAny(patterns, pathname) {
  return patterns.some((pattern) => pattern.test(pathname));
}

function buildEmptySummaryPayload() {
  return {
    summary: {
      clients: 0,
      tasks: 0,
      reports: 0,
      budgets: 0,
      products: 0,
      users: 0
    },
    recentReports: [],
    recentTasks: [],
    recentBudgets: [],
    taskMetrics: {
      total: 0,
      open: 0,
      inProgress: 0,
      completed: 0,
      today: 0
    },
    budgetMetrics: {
      total: 0,
      inProgress: 0,
      approved: 0,
      rejected: 0
    },
    notificationCount: 0
  };
}

function buildEmptyMeta(query = {}) {
  const page = Number.parseInt(query.page, 10);
  const pageSize = Number.parseInt(query.pageSize, 10);

  return {
    total: 0,
    page: Number.isFinite(page) && page > 0 ? page : 1,
    pageSize: Number.isFinite(pageSize) && pageSize > 0 ? pageSize : 50
  };
}

function createVisitorDataIsolationMiddleware() {
  return (req, res, next) => {
    if (!isVisitorUser(req.user)) {
      return next();
    }

    const pathname = req.path || "/";
    if (!isProtectedPath(pathname)) {
      return next();
    }

    // O visitante pode navegar pelo app, mas nÃ£o deve tocar no banco para ler
    // nem gravar dados operacionais. O backend responde vazio ou bloqueia.
    if (req.method !== "GET") {
      return next(new ForbiddenError("O perfil visitante nÃ£o possui acesso ao banco de dados."));
    }

    if (pathname === "/summary" || pathname === "/summary/") {
      return send(res, buildEmptySummaryPayload());
    }

    if (matchesAny(EMPTY_COLLECTION_PATTERNS, pathname)) {
      const options = pathname.startsWith("/admin/") ? { meta: buildEmptyMeta(req.query) } : undefined;
      return send(res, [], options);
    }

    return next(new NotFoundError("Nenhum dado disponÃ­vel para o perfil visitante."));
  };
}

module.exports = {
  createVisitorDataIsolationMiddleware,
  isVisitorUser
};
