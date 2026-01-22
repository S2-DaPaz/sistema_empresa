const path = require("path");
const { pathToFileURL } = require("url");
require("dotenv").config({ path: path.join(__dirname, ".env") });
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const { initDb } = require("./db");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const puppeteer = require("puppeteer");

const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || "rv-sistema-secret";
const JWT_TTL = process.env.JWT_TTL || "7d";

function resolveStaticDir() {
  const candidates = [];
  if (process.env.STATIC_DIR) {
    candidates.push(process.env.STATIC_DIR);
  }
  candidates.push(path.join(__dirname, "..", "web", "dist"));
  candidates.push(path.join(process.cwd(), "web", "dist"));

  for (const candidate of candidates) {
    if (!candidate) continue;
    const indexPath = path.join(candidate, "index.html");
    if (fs.existsSync(indexPath)) {
      return candidate;
    }
  }
  return null;
}

function isEmpty(value) {
  return value === undefined || value === null || value === "";
}

function ensureFields(body, fields) {
  const missing = fields.filter((field) => isEmpty(body[field]));
  return missing;
}

function parseJsonFields(row, jsonFields) {
  if (!row) return row;
  jsonFields.forEach((field) => {
    if (row[field] && typeof row[field] === "string") {
      try {
        row[field] = JSON.parse(row[field]);
      } catch (error) {
        row[field] = null;
      }
    }
  });
  return row;
}

function parseJsonList(rows, jsonFields) {
  return rows.map((row) => parseJsonFields(row, jsonFields));
}

function buildPayload(body, fields, jsonFields) {
  const data = {};
  fields.forEach((field) => {
    const value = body[field] !== undefined ? body[field] : null;
    if (jsonFields.includes(field)) {
      data[field] = value === null ? null : JSON.stringify(value);
    } else {
      data[field] = value;
    }
  });
  return data;
}

function toNumber(value) {
  const num = Number(value);
  return Number.isFinite(num) ? num : 0;
}

function calcBudgetTotals(items, discount, tax) {
  const subtotal = items.reduce((sum, item) => sum + item.qty * item.unit_price, 0);
  const discountValue = toNumber(discount);
  const taxValue = toNumber(tax);
  const total = subtotal - discountValue + taxValue;
  return {
    subtotal,
    discount: discountValue,
    tax: taxValue,
    total
  };
}

const PERMISSIONS = {
  VIEW_DASHBOARD: "view_dashboard",
  VIEW_CLIENTS: "view_clients",
  MANAGE_CLIENTS: "manage_clients",
  VIEW_TASKS: "view_tasks",
  MANAGE_TASKS: "manage_tasks",
  VIEW_TEMPLATES: "view_templates",
  MANAGE_TEMPLATES: "manage_templates",
  VIEW_BUDGETS: "view_budgets",
  MANAGE_BUDGETS: "manage_budgets",
  VIEW_USERS: "view_users",
  MANAGE_USERS: "manage_users",
  VIEW_PRODUCTS: "view_products",
  MANAGE_PRODUCTS: "manage_products",
  VIEW_TASK_TYPES: "view_task_types",
  MANAGE_TASK_TYPES: "manage_task_types"
};

const ALL_PERMISSIONS = Object.values(PERMISSIONS);

const ROLE_DEFAULTS = {
  administracao: ALL_PERMISSIONS,
  gestor: [
    PERMISSIONS.VIEW_DASHBOARD,
    PERMISSIONS.VIEW_CLIENTS,
    PERMISSIONS.MANAGE_CLIENTS,
    PERMISSIONS.VIEW_TASKS,
    PERMISSIONS.MANAGE_TASKS,
    PERMISSIONS.VIEW_TEMPLATES,
    PERMISSIONS.MANAGE_TEMPLATES,
    PERMISSIONS.VIEW_BUDGETS,
    PERMISSIONS.MANAGE_BUDGETS,
    PERMISSIONS.VIEW_PRODUCTS,
    PERMISSIONS.MANAGE_PRODUCTS,
    PERMISSIONS.VIEW_TASK_TYPES,
    PERMISSIONS.MANAGE_TASK_TYPES
  ],
  tecnico: [
    PERMISSIONS.VIEW_DASHBOARD,
    PERMISSIONS.VIEW_CLIENTS,
    PERMISSIONS.VIEW_TASKS,
    PERMISSIONS.MANAGE_TASKS,
    PERMISSIONS.VIEW_BUDGETS,
    PERMISSIONS.VIEW_PRODUCTS
  ],
  visitante: [
    PERMISSIONS.VIEW_DASHBOARD,
    PERMISSIONS.VIEW_CLIENTS,
    PERMISSIONS.VIEW_TASKS,
    PERMISSIONS.VIEW_TEMPLATES,
    PERMISSIONS.VIEW_BUDGETS,
    PERMISSIONS.VIEW_PRODUCTS,
    PERMISSIONS.VIEW_TASK_TYPES
  ]
};

function parsePermissions(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      return [];
    }
  }
  return [];
}

function getUserPermissions(user) {
  if (!user) return [];
  if (user.role === "administracao") return ALL_PERMISSIONS;
  const base = ROLE_DEFAULTS[user.role] || ROLE_DEFAULTS.visitante;
  const custom = parsePermissions(user.permissions);
  return Array.from(new Set([...base, ...custom]));
}

function hasPermission(user, permission) {
  if (!user) return false;
  if (user.role === "administracao") return true;
  const permissions = new Set(getUserPermissions(user));
  if (permissions.has(permission)) return true;
  if (permission.startsWith("view_")) {
    const manage = permission.replace("view_", "manage_");
    return permissions.has(manage);
  }
  return false;
}

function normalizeUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    permissions: parsePermissions(user.permissions)
  };
}

function signToken(user) {
  return jwt.sign({ id: user.id }, JWT_SECRET, { expiresIn: JWT_TTL });
}

function createAuthMiddleware(db) {
  return async (req, res, next) => {
    if (req.method === "OPTIONS") return next();
    if (req.path === "/health" || req.path === "/auth/login" || req.path === "/auth/register") {
      return next();
    }
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) {
      return res.status(401).json({ error: "Não autorizado" });
    }
    try {
      const payload = jwt.verify(token, JWT_SECRET);
      const user = await db.get("SELECT id, name, email, role, permissions FROM users WHERE id = ?", [payload.id]);
      if (!user) {
        return res.status(401).json({ error: "Usuário não encontrado" });
      }
      req.user = { ...normalizeUser(user), permissions: getUserPermissions(user) };
      return next();
    } catch (error) {
      return res.status(401).json({ error: "Token inválido" });
    }
  };
}

function requirePermission(permission) {
  return (req, res, next) => {
    if (!req.user || !hasPermission(req.user, permission)) {
      return res.status(403).json({ error: "Sem permissão" });
    }
    return next();
  };
}

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== "administracao") {
    return res.status(403).json({ error: "Acesso restrito ao administrador" });
  }
  return next();
}

async function ensureAdminUser(db) {
  const name = process.env.ADMIN_NAME || "Administrador";
  const email = process.env.ADMIN_EMAIL || "admin@local";
  const password = process.env.ADMIN_PASSWORD || "admin123";
  const existing = await db.get("SELECT id FROM users WHERE lower(email) = lower(?)", [email]);
  if (existing) return;
  const hash = await bcrypt.hash(password, 10);
  await db.run(
    "INSERT INTO users (name, email, role, password_hash, permissions) VALUES (?, ?, ?, ?, ?)",
    [name, email, "administracao", hash, JSON.stringify([])]
  );
  console.log(`Usuário admin criado: ${email}`);
}

function safeJsonParse(value) {
  if (!value || typeof value !== "string") return null;
  try {
    return JSON.parse(value);
  } catch (error) {
    return null;
  }
}

let pdfHelpersPromise;
let pdfBrowserPromise;
let cachedLogoDataUrl;

function resolveLogoPath() {
  const candidates = [
    process.env.PDF_LOGO_PATH,
    path.join(process.cwd(), "Logo.png"),
    path.join(__dirname, "..", "web", "src", "assets", "Logo.png"),
    path.join(__dirname, "..", "web", "src", "assets", "rv-logo.png")
  ].filter(Boolean);

  return candidates.find((candidate) => fs.existsSync(candidate)) || null;
}

function getLogoDataUrl() {
  if (cachedLogoDataUrl) return cachedLogoDataUrl;
  const logoPath = resolveLogoPath();
  if (!logoPath) return null;
  const buffer = fs.readFileSync(logoPath);
  cachedLogoDataUrl = `data:image/png;base64,${buffer.toString("base64")}`;
  return cachedLogoDataUrl;
}

async function loadPdfHelpers() {
  if (!pdfHelpersPromise) {
    const modulePath = path.join(__dirname, "..", "web", "src", "utils", "pdf.js");
    if (!fs.existsSync(modulePath)) {
      throw new Error("Template de PDF não encontrado.");
    }
    pdfHelpersPromise = import(pathToFileURL(modulePath).href);
  }
  return pdfHelpersPromise;
}

async function getPdfBrowser() {
  if (!pdfBrowserPromise) {
    pdfBrowserPromise = puppeteer.launch({
      headless: "new",
      args: ["--no-sandbox", "--disable-setuid-sandbox"]
    });
  }
  return pdfBrowserPromise;
}

async function renderPdfFromHtml(html) {
  const browser = await getPdfBrowser();
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: "networkidle0" });
  const pdf = await page.pdf({ format: "A4", printBackground: true });
  await page.close();
  return Buffer.from(pdf);
}

function normalizeReportContent(report) {
  const content = safeJsonParse(report.content) || report.content || {};
  const templateStructure =
    safeJsonParse(report.template_structure) || report.template_structure || {};
  const layout =
    content.layout ||
    templateStructure.layout || {
      sectionColumns: 1,
      fieldColumns: 1
    };
  const sections = content.sections || templateStructure.sections || [];
  return {
    ...report,
    content: {
      sections,
      layout,
      answers: content.answers || {},
      photos: content.photos || []
    }
  };
}

async function fetchTaskPdfData(db, taskId) {
  const task = await db.get("SELECT * FROM tasks WHERE id = ?", [taskId]);
  if (!task) return null;
  const client = task.client_id
    ? await db.get("SELECT * FROM clients WHERE id = ?", [task.client_id])
    : null;

  const reportRows = await db.all(
    `
    SELECT
      reports.*,
      report_templates.structure AS template_structure,
      equipments.name AS equipment_name
    FROM reports
    LEFT JOIN report_templates ON report_templates.id = reports.template_id
    LEFT JOIN equipments ON equipments.id = reports.equipment_id
    WHERE reports.task_id = ?
    ORDER BY reports.id ASC
  `,
    [taskId]
  );
  const reports = reportRows.map((row) => normalizeReportContent(row));

  const budgets = await db.all(
    `
    SELECT
      budgets.*,
      clients.name AS client_name,
      reports.title AS report_title,
      tasks.title AS task_title
    FROM budgets
    LEFT JOIN clients ON clients.id = budgets.client_id
    LEFT JOIN reports ON reports.id = budgets.report_id
    LEFT JOIN tasks ON tasks.id = budgets.task_id
    WHERE budgets.task_id = ?
    ORDER BY budgets.id ASC
  `,
    [taskId]
  );

  if (budgets.length) {
    const ids = budgets.map((budget) => budget.id);
    const placeholders = ids.map(() => "?").join(", ");
    const items = await db.all(
      `SELECT * FROM budget_items WHERE budget_id IN (${placeholders}) ORDER BY id ASC`,
      ids
    );
    const grouped = new Map();
    items.forEach((item) => {
      if (!grouped.has(item.budget_id)) grouped.set(item.budget_id, []);
      grouped.get(item.budget_id).push(item);
    });
    budgets.forEach((budget) => {
      budget.items = grouped.get(budget.id) || [];
    });
  }

  return {
    task: parseJsonFields(task, ["signature_pages"]),
    client,
    reports,
    budgets
  };
}

async function fetchBudgetPdfData(db, budgetId) {
  const budget = await db.get(
    `
    SELECT
      budgets.*,
      clients.name AS client_name,
      reports.title AS report_title,
      tasks.title AS task_title
    FROM budgets
    LEFT JOIN clients ON clients.id = budgets.client_id
    LEFT JOIN reports ON reports.id = budgets.report_id
    LEFT JOIN tasks ON tasks.id = budgets.task_id
    WHERE budgets.id = ?
  `,
    [budgetId]
  );
  if (!budget) return null;
  budget.items = await db.all(
    "SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC",
    [budgetId]
  );
  const client = budget.client_id
    ? await db.get("SELECT * FROM clients WHERE id = ?", [budget.client_id])
    : null;
  return { budget, client };
}

async function createReportForTask(db, task) {
  if (!task || !task.id || !task.task_type_id) return null;

  const existing = await db.get(
    "SELECT id FROM reports WHERE task_id = ? AND equipment_id IS NULL ORDER BY id DESC LIMIT 1",
    [task.id]
  );
  if (existing) return existing;

  const typeRow = await db.get(
    "SELECT report_template_id FROM task_types WHERE id = ?",
    [task.task_type_id]
  );
  if (!typeRow?.report_template_id) return null;

  const template = await db.get(
    "SELECT structure FROM report_templates WHERE id = ?",
    [typeRow.report_template_id]
  );
  const structure = safeJsonParse(template?.structure) || { sections: [] };
  const content = JSON.stringify({
    sections: structure.sections || [],
    answers: {},
    photos: []
  });

  const result = await db.run(
    `
    INSERT INTO reports (title, task_id, client_id, template_id, equipment_id, content, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `,
    [
      task.title || "Relatório",
      task.id,
      task.client_id || null,
      typeRow.report_template_id,
      null,
      content,
      "rascunho",
      new Date().toISOString()
    ]
  );

  return { id: result.lastID };
}

async function syncReportForTask(db, task) {
  if (!task || !task.id) return null;
  const report = await db.get(
    "SELECT * FROM reports WHERE task_id = ? AND equipment_id IS NULL ORDER BY id DESC LIMIT 1",
    [task.id]
  );
  if (!report) {
    return createReportForTask(db, task);
  }

  const typeRow = task.task_type_id
    ? await db.get("SELECT report_template_id FROM task_types WHERE id = ?", [
        task.task_type_id
      ])
    : null;
  const parsedContent = safeJsonParse(report.content) || {};
  const hasSections = Array.isArray(parsedContent.sections) && parsedContent.sections.length > 0;

  let nextTemplateId = report.template_id;
  let nextContent = report.content;

  if (!hasSections && typeRow?.report_template_id) {
    const template = await db.get(
      "SELECT structure FROM report_templates WHERE id = ?",
      [typeRow.report_template_id]
    );
    const structure = safeJsonParse(template?.structure) || { sections: [] };
    nextTemplateId = typeRow.report_template_id;
    nextContent = JSON.stringify({
      sections: structure.sections || [],
      answers: {},
      photos: []
    });
  }

  await db.run(
    `
    UPDATE reports
    SET title = ?, client_id = ?, template_id = ?, content = ?
    WHERE id = ?
  `,
    [
      task.title || report.title,
      task.client_id || null,
      nextTemplateId,
      nextContent,
      report.id
    ]
  );

  return report;
}

async function createReportForEquipment(db, task, equipment) {
  if (!task?.id || !task.task_type_id || !equipment?.id) return null;

  const existing = await db.get(
    "SELECT id FROM reports WHERE task_id = ? AND equipment_id = ? ORDER BY id DESC LIMIT 1",
    [task.id, equipment.id]
  );
  if (existing) return existing;

  const typeRow = await db.get(
    "SELECT report_template_id FROM task_types WHERE id = ?",
    [task.task_type_id]
  );
  if (!typeRow?.report_template_id) return null;

  const template = await db.get(
    "SELECT structure FROM report_templates WHERE id = ?",
    [typeRow.report_template_id]
  );
  const structure = safeJsonParse(template?.structure) || { sections: [] };
  const content = JSON.stringify({
    sections: structure.sections || [],
    answers: {},
    photos: []
  });

  const title = equipment.name ? `Relatório - ${equipment.name}` : "Relatório - Equipamento";
  const result = await db.run(
    `
    INSERT INTO reports (title, task_id, client_id, template_id, equipment_id, content, status, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `,
    [
      title,
      task.id,
      task.client_id || equipment.client_id || null,
      typeRow.report_template_id,
      equipment.id,
      content,
      "rascunho",
      new Date().toISOString()
    ]
  );

  return { id: result.lastID };
}

function createCrudRoutes(db, config) {
  const { table, fields, jsonFields = [], orderBy = "id DESC", permissions } = config;
  const router = express.Router();

  function ensureView(req, res, next) {
    if (!permissions?.view) return next();
    if (!hasPermission(req.user, permissions.view)) {
      return res.status(403).json({ error: "Sem permissão" });
    }
    return next();
  }

  function ensureManage(req, res, next) {
    if (!permissions?.manage) return next();
    if (!hasPermission(req.user, permissions.manage)) {
      return res.status(403).json({ error: "Sem permissão" });
    }
    return next();
  }

  router.get("/", ensureView, async (req, res) => {
    try {
      const items = await db.all(`SELECT * FROM ${table} ORDER BY ${orderBy}`);
      res.json(parseJsonList(items, jsonFields));
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar registros" });
    }
  });

  router.get("/:id", ensureView, async (req, res) => {
    try {
      const item = await db.get(`SELECT * FROM ${table} WHERE id = ?`, [req.params.id]);
      if (!item) {
        return res.status(404).json({ error: "Registro não encontrado" });
      }
      res.json(parseJsonFields(item, jsonFields));
    } catch (error) {
      res.status(500).json({ error: "Falha ao carregar registro" });
    }
  });

  router.post("/", ensureManage, async (req, res) => {
    try {
      const data = buildPayload(req.body, fields, jsonFields);
      const placeholders = fields.map(() => "?").join(", ");
      const sql = `INSERT INTO ${table} (${fields.join(", ")}) VALUES (${placeholders})`;
      const result = await db.run(sql, fields.map((field) => data[field]));
      const item = await db.get(`SELECT * FROM ${table} WHERE id = ?`, [result.lastID]);
      res.status(201).json(parseJsonFields(item, jsonFields));
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar registro" });
    }
  });

  router.put("/:id", ensureManage, async (req, res) => {
    try {
      const data = buildPayload(req.body, fields, jsonFields);
      const setClause = fields.map((field) => `${field} = ?`).join(", ");
      const sql = `UPDATE ${table} SET ${setClause} WHERE id = ?`;
      const values = fields.map((field) => data[field]);
      values.push(req.params.id);
      await db.run(sql, values);
      const item = await db.get(`SELECT * FROM ${table} WHERE id = ?`, [req.params.id]);
      res.json(parseJsonFields(item, jsonFields));
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar registro" });
    }
  });

  router.delete("/:id", ensureManage, async (req, res) => {
    try {
      await db.run(`DELETE FROM ${table} WHERE id = ?`, [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover registro" });
    }
  });

  return router;
}

async function main() {
  const db = await initDb();
  await ensureAdminUser(db);
  const app = express();

  app.use(cors());
  app.use(express.json({ limit: "10mb" }));

  app.get("/api/health", (req, res) => {
    res.json({ ok: true });
  });

  app.post("/api/auth/register", async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["name", "email", "password"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const exists = await db.get("SELECT id FROM users WHERE lower(email) = lower(?)", [req.body.email]);
      if (exists) {
        return res.status(400).json({ error: "E-mail já cadastrado" });
      }
      const hash = await bcrypt.hash(req.body.password, 10);
      const result = await db.run(
        "INSERT INTO users (name, email, role, password_hash, permissions) VALUES (?, ?, ?, ?, ?)",
        [req.body.name, req.body.email, "visitante", hash, JSON.stringify([])]
      );
      const user = await db.get("SELECT id, name, email, role, permissions FROM users WHERE id = ?", [result.lastID]);
      const token = signToken(user);
      res.status(201).json({ user: normalizeUser(user), token });
    } catch (error) {
      res.status(500).json({ error: "Falha ao cadastrar" });
    }
  });

  app.post("/api/auth/login", async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["email", "password"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const user = await db.get("SELECT * FROM users WHERE lower(email) = lower(?)", [req.body.email]);
      if (!user || !user.password_hash) {
        return res.status(401).json({ error: "Credenciais inválidas" });
      }
      const valid = await bcrypt.compare(req.body.password, user.password_hash);
      if (!valid) {
        return res.status(401).json({ error: "Credenciais inválidas" });
      }
      const token = signToken(user);
      res.json({ user: normalizeUser(user), token });
    } catch (error) {
      res.status(500).json({ error: "Falha ao autenticar" });
    }
  });

  app.use("/api", createAuthMiddleware(db));

  app.get("/api/auth/me", (req, res) => {
    res.json({ user: req.user });
  });

  app.get("/api/summary", requirePermission(PERMISSIONS.VIEW_DASHBOARD), async (req, res) => {
    try {
      const tables = [
        "clients",
        "tasks",
        "reports",
        "budgets",
        "report_templates",
        "equipments"
      ];
      const summary = {};
      for (const table of tables) {
        const row = await db.get(`SELECT COUNT(*) as count FROM ${table}`);
        summary[table] = row ? row.count : 0;
      }
      res.json(summary);
    } catch (error) {
      res.status(500).json({ error: "Falha ao carregar resumo" });
    }
  });

  app.use(
    "/api/clients",
    createCrudRoutes(db, {
      table: "clients",
      fields: ["name", "cnpj", "address", "contact"],
      orderBy: "name ASC",
      permissions: { view: PERMISSIONS.VIEW_CLIENTS, manage: PERMISSIONS.MANAGE_CLIENTS }
    })
  );

  app.use(
    "/api/products",
    createCrudRoutes(db, {
      table: "products",
      fields: ["name", "sku", "price", "unit"],
      orderBy: "name ASC",
      permissions: { view: PERMISSIONS.VIEW_PRODUCTS, manage: PERMISSIONS.MANAGE_PRODUCTS }
    })
  );

  app.get("/api/users", requireAdmin, async (req, res) => {
    try {
      const users = await db.all("SELECT id, name, email, role, permissions FROM users ORDER BY name ASC");
      res.json(users.map(normalizeUser));
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar usuários" });
    }
  });

  app.post("/api/users", requireAdmin, async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["name", "email", "role", "password"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const exists = await db.get("SELECT id FROM users WHERE lower(email) = lower(?)", [req.body.email]);
      if (exists) {
        return res.status(400).json({ error: "E-mail já cadastrado" });
      }
      const hash = await bcrypt.hash(req.body.password, 10);
      const permissions = Array.isArray(req.body.permissions) ? req.body.permissions : [];
      const result = await db.run(
        "INSERT INTO users (name, email, role, password_hash, permissions) VALUES (?, ?, ?, ?, ?)",
        [req.body.name, req.body.email, req.body.role, hash, JSON.stringify(permissions)]
      );
      const user = await db.get("SELECT id, name, email, role, permissions FROM users WHERE id = ?", [result.lastID]);
      res.status(201).json(normalizeUser(user));
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar usuário" });
    }
  });

  app.put("/api/users/:id", requireAdmin, async (req, res) => {
    try {
      const targetId = Number(req.params.id);
      if (req.user?.id === targetId && req.body.role && req.body.role !== req.user.role) {
        return res.status(400).json({ error: "Não é permitido alterar o próprio cargo" });
      }
      const permissions = Array.isArray(req.body.permissions) ? req.body.permissions : [];
      const fields = ["name", "email", "role", "permissions"];
      const data = {
        name: req.body.name,
        email: req.body.email,
        role: req.body.role,
        permissions: JSON.stringify(permissions)
      };
      const setClause = fields.map((field) => `${field} = ?`).join(", ");
      const values = fields.map((field) => data[field]);
      values.push(req.params.id);
      await db.run(`UPDATE users SET ${setClause} WHERE id = ?`, values);
      if (req.body.password) {
        const hash = await bcrypt.hash(req.body.password, 10);
        await db.run("UPDATE users SET password_hash = ? WHERE id = ?", [hash, req.params.id]);
      }
      const user = await db.get("SELECT id, name, email, role, permissions FROM users WHERE id = ?", [req.params.id]);
      res.json(normalizeUser(user));
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar usuário" });
    }
  });

  app.delete("/api/users/:id", requireAdmin, async (req, res) => {
    try {
      const targetId = Number(req.params.id);
      if (req.user?.id === targetId) {
        return res.status(400).json({ error: "Não é permitido remover o próprio usuário" });
      }
      await db.run("DELETE FROM users WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover usuário" });
    }
  });

  app.get("/api/equipments", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("equipments.client_id = ?");
        params.push(req.query.clientId);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = await db.all(
        `
        SELECT
          equipments.*,
          clients.name AS client_name
        FROM equipments
        LEFT JOIN clients ON clients.id = equipments.client_id
        ${where}
        ORDER BY equipments.id DESC
      `,
        params
      );
      res.json(parseJsonList(rows, ["signature_pages"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar equipamentos" });
    }
  });

  app.get("/api/equipments/:id", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const equipment = await db.get(
        `
        SELECT
          equipments.*,
          clients.name AS client_name
        FROM equipments
        LEFT JOIN clients ON clients.id = equipments.client_id
        WHERE equipments.id = ?
      `,
        [req.params.id]
      );
      if (!equipment) {
        return res.status(404).json({ error: "Equipamento não encontrado" });
      }
      res.json(equipment);
    } catch (error) {
      res.status(500).json({ error: "Falha ao carregar equipamento" });
    }
  });

  app.post("/api/equipments", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["client_id", "name"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const fields = ["client_id", "name", "model", "serial", "description", "created_at"];
      const payload = {
        ...req.body,
        created_at: req.body.created_at || new Date().toISOString()
      };
      const data = buildPayload(payload, fields, []);
      const placeholders = fields.map(() => "?").join(", ");
      const sql = `INSERT INTO equipments (${fields.join(", ")}) VALUES (${placeholders})`;
      const result = await db.run(sql, fields.map((field) => data[field]));
      const equipment = await db.get("SELECT * FROM equipments WHERE id = ?", [result.lastID]);
      res.status(201).json(equipment);
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar equipamento" });
    }
  });

  app.put("/api/equipments/:id", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const fields = ["client_id", "name", "model", "serial", "description", "created_at"];
      const payload = {
        ...req.body,
        created_at: req.body.created_at || new Date().toISOString()
      };
      const data = buildPayload(payload, fields, []);
      const setClause = fields.map((field) => `${field} = ?`).join(", ");
      const sql = `UPDATE equipments SET ${setClause} WHERE id = ?`;
      const values = fields.map((field) => data[field]);
      values.push(req.params.id);
      await db.run(sql, values);
      const equipment = await db.get("SELECT * FROM equipments WHERE id = ?", [req.params.id]);
      res.json(equipment);
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar equipamento" });
    }
  });

  app.delete("/api/equipments/:id", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      await db.run("DELETE FROM equipments WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover equipamento" });
    }
  });

  app.get("/api/tasks/:id/equipments", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const rows = await db.all(
        `
        SELECT
          equipments.*,
          task_equipments.created_at AS linked_at
        FROM task_equipments
        INNER JOIN equipments ON equipments.id = task_equipments.equipment_id
        WHERE task_equipments.task_id = ?
        ORDER BY equipments.name ASC
      `,
        [req.params.id]
      );
      res.json(rows);
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar equipamentos da tarefa" });
    }
  });

  app.post("/api/tasks/:id/equipments", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["equipment_id"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const task = await db.get("SELECT * FROM tasks WHERE id = ?", [req.params.id]);
      if (!task) {
        return res.status(404).json({ error: "Tarefa não encontrada" });
      }
      const equipment = await db.get("SELECT * FROM equipments WHERE id = ?", [
        req.body.equipment_id
      ]);
      if (!equipment) {
        return res.status(404).json({ error: "Equipamento não encontrado" });
      }
      if (task.client_id && equipment.client_id !== task.client_id) {
        return res
          .status(400)
          .json({ error: "Equipment does not belong to task client" });
      }

      await db.run(
        `
        INSERT OR IGNORE INTO task_equipments (task_id, equipment_id, created_at)
        VALUES (?, ?, ?)
      `,
        [req.params.id, equipment.id, new Date().toISOString()]
      );

      await createReportForEquipment(db, task, equipment);

      res.status(201).json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao vincular equipamento" });
    }
  });

  app.delete("/api/tasks/:id/equipments/:equipmentId", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      await db.run(
        "DELETE FROM task_equipments WHERE task_id = ? AND equipment_id = ?",
        [req.params.id, req.params.equipmentId]
      );
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao desvincular equipamento" });
    }
  });

  app.use(
    "/api/task-types",
    createCrudRoutes(db, {
      table: "task_types",
      fields: ["name", "description", "report_template_id"],
      orderBy: "name ASC",
      permissions: { view: PERMISSIONS.VIEW_TASK_TYPES, manage: PERMISSIONS.MANAGE_TASK_TYPES }
    })
  );

  app.get("/api/tasks", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("tasks.client_id = ?");
        params.push(req.query.clientId);
      }
      if (req.query.userId) {
        filters.push("tasks.user_id = ?");
        params.push(req.query.userId);
      }
      if (req.query.status) {
        filters.push("tasks.status = ?");
        params.push(req.query.status);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = await db.all(
        `
        SELECT
          tasks.*,
          clients.name AS client_name,
          users.name AS user_name,
          task_types.name AS task_type_name,
          task_types.report_template_id AS report_template_id,
          report_templates.name AS report_template_name,
          (
            SELECT id
            FROM reports
            WHERE reports.task_id = tasks.id
              AND reports.equipment_id IS NULL
            ORDER BY reports.id DESC
            LIMIT 1
          ) AS report_id
        FROM tasks
        LEFT JOIN clients ON clients.id = tasks.client_id
        LEFT JOIN users ON users.id = tasks.user_id
        LEFT JOIN task_types ON task_types.id = tasks.task_type_id
        LEFT JOIN report_templates ON report_templates.id = task_types.report_template_id
        ${where}
        ORDER BY tasks.id DESC
      `,
        params
      );
      res.json(rows);
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar tarefas" });
    }
  });

  app.get("/api/tasks/:id", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const task = await db.get(
        `
        SELECT
          tasks.*,
          clients.name AS client_name,
          users.name AS user_name,
          task_types.name AS task_type_name,
          task_types.report_template_id AS report_template_id,
          report_templates.name AS report_template_name,
          (
            SELECT id
            FROM reports
            WHERE reports.task_id = tasks.id
              AND reports.equipment_id IS NULL
            ORDER BY reports.id DESC
            LIMIT 1
          ) AS report_id
        FROM tasks
        LEFT JOIN clients ON clients.id = tasks.client_id
        LEFT JOIN users ON users.id = tasks.user_id
        LEFT JOIN task_types ON task_types.id = tasks.task_type_id
        LEFT JOIN report_templates ON report_templates.id = task_types.report_template_id
        WHERE tasks.id = ?
      `,
        [req.params.id]
      );
      if (!task) {
        return res.status(404).json({ error: "Tarefa não encontrada" });
      }
      res.json(parseJsonFields(task, ["signature_pages"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao carregar tarefa" });
    }
  });

  app.post("/api/tasks", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["title"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const fields = [
        "title",
        "description",
        "client_id",
        "user_id",
        "task_type_id",
        "status",
        "priority",
        "start_date",
        "due_date",
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_tech",
        "signature_pages"
      ];
      const data = buildPayload(req.body, fields, ["signature_pages"]);
      const placeholders = fields.map(() => "?").join(", ");
      const sql = `INSERT INTO tasks (${fields.join(", ")}) VALUES (${placeholders})`;
      const result = await db.run(sql, fields.map((field) => data[field]));
      const task = await db.get("SELECT * FROM tasks WHERE id = ?", [result.lastID]);

      await createReportForTask(db, task);

      res.status(201).json(task);
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar tarefa" });
    }
  });

  app.put("/api/tasks/:id", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const fields = [
        "title",
        "description",
        "client_id",
        "user_id",
        "task_type_id",
        "status",
        "priority",
        "start_date",
        "due_date",
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_tech",
        "signature_pages"
      ];
      const data = buildPayload(req.body, fields, ["signature_pages"]);
      const setClause = fields.map((field) => `${field} = ?`).join(", ");
      const sql = `UPDATE tasks SET ${setClause} WHERE id = ?`;
      const values = fields.map((field) => data[field]);
      values.push(req.params.id);
      await db.run(sql, values);
      const task = await db.get("SELECT * FROM tasks WHERE id = ?", [req.params.id]);
      await syncReportForTask(db, task);
      res.json(task);
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar tarefa" });
    }
  });

  app.delete("/api/tasks/:id", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      await db.run("DELETE FROM tasks WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover tarefa" });
    }
  });

  app.get("/api/tasks/:id/pdf", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const data = await fetchTaskPdfData(db, req.params.id);
      if (!data) {
        return res.status(404).json({ error: "Tarefa não encontrada" });
      }
      const { buildTaskPdfHtml } = await loadPdfHelpers();
      const html = buildTaskPdfHtml({
        task: data.task,
        client: data.client,
        reports: data.reports,
        budgets: data.budgets,
        signatureMode: data.task.signature_mode,
        signatureScope: data.task.signature_scope,
        signatureClient: data.task.signature_client,
        signatureTech: data.task.signature_tech,
        signaturePages: data.task.signature_pages || {},
        logoUrl: getLogoDataUrl()
      });
      const pdf = await renderPdfFromHtml(html);
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `inline; filename=\"tarefa_${req.params.id}.pdf\"`);
      res.send(pdf);
    } catch (error) {
      res.status(500).json({ error: "Falha ao gerar PDF da tarefa" });
    }
  });

  app.use(
    "/api/report-templates",
    createCrudRoutes(db, {
      table: "report_templates",
      fields: ["name", "description", "structure"],
      jsonFields: ["structure"],
      orderBy: "name ASC",
      permissions: { view: PERMISSIONS.VIEW_TEMPLATES, manage: PERMISSIONS.MANAGE_TEMPLATES }
    })
  );

  app.get("/api/reports", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("reports.client_id = ?");
        params.push(req.query.clientId);
      }
      if (req.query.taskId) {
        filters.push("reports.task_id = ?");
        params.push(req.query.taskId);
      }
      if (req.query.equipmentId) {
        filters.push("reports.equipment_id = ?");
        params.push(req.query.equipmentId);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = await db.all(
        `
        SELECT
          reports.*,
          clients.name AS client_name,
          tasks.title AS task_title,
          report_templates.name AS template_name,
          equipments.name AS equipment_name
        FROM reports
        LEFT JOIN clients ON clients.id = reports.client_id
        LEFT JOIN tasks ON tasks.id = reports.task_id
        LEFT JOIN report_templates ON report_templates.id = reports.template_id
        LEFT JOIN equipments ON equipments.id = reports.equipment_id
        ${where}
        ORDER BY reports.id DESC
      `,
        params
      );
      res.json(parseJsonList(rows, ["content"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar relatórios" });
    }
  });

  app.get("/api/reports/:id", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const report = await db.get(
        `
        SELECT
          reports.*,
          clients.name AS client_name,
          tasks.title AS task_title,
          report_templates.name AS template_name,
          equipments.name AS equipment_name
        FROM reports
        LEFT JOIN clients ON clients.id = reports.client_id
        LEFT JOIN tasks ON tasks.id = reports.task_id
        LEFT JOIN report_templates ON report_templates.id = reports.template_id
        LEFT JOIN equipments ON equipments.id = reports.equipment_id
        WHERE reports.id = ?
      `,
        [req.params.id]
      );
      if (!report) {
        return res.status(404).json({ error: "Relatório não encontrado" });
      }
      res.json(parseJsonFields(report, ["content"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao carregar relatório" });
    }
  });

  app.post("/api/reports", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["client_id", "template_id"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const fields = [
        "title",
        "task_id",
        "client_id",
        "template_id",
        "equipment_id",
        "content",
        "status",
        "created_at"
      ];
      const payload = {
        ...req.body,
        created_at: req.body.created_at || new Date().toISOString()
      };
      const data = buildPayload(payload, fields, ["content"]);
      const placeholders = fields.map(() => "?").join(", ");
      const sql = `INSERT INTO reports (${fields.join(", ")}) VALUES (${placeholders})`;
      const result = await db.run(sql, fields.map((field) => data[field]));
      const report = await db.get("SELECT * FROM reports WHERE id = ?", [result.lastID]);
      res.status(201).json(parseJsonFields(report, ["content"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar relatório" });
    }
  });

  app.put("/api/reports/:id", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const fields = [
        "title",
        "task_id",
        "client_id",
        "template_id",
        "equipment_id",
        "content",
        "status",
        "created_at"
      ];
      const payload = {
        ...req.body,
        created_at: req.body.created_at || new Date().toISOString()
      };
      const data = buildPayload(payload, fields, ["content"]);
      const setClause = fields.map((field) => `${field} = ?`).join(", ");
      const sql = `UPDATE reports SET ${setClause} WHERE id = ?`;
      const values = fields.map((field) => data[field]);
      values.push(req.params.id);
      await db.run(sql, values);
      const report = await db.get("SELECT * FROM reports WHERE id = ?", [req.params.id]);
      res.json(parseJsonFields(report, ["content"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar relatório" });
    }
  });

  app.delete("/api/reports/:id", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      await db.run("DELETE FROM reports WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover relatório" });
    }
  });

  app.get("/api/budgets", requirePermission(PERMISSIONS.VIEW_BUDGETS), async (req, res) => {
    try {
      const filters = [];
      const params = [];
      if (req.query.clientId) {
        filters.push("budgets.client_id = ?");
        params.push(req.query.clientId);
      }
      if (req.query.taskId) {
        filters.push("budgets.task_id = ?");
        params.push(req.query.taskId);
      }
      if (req.query.reportId) {
        filters.push("budgets.report_id = ?");
        params.push(req.query.reportId);
      }
      const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
      const rows = await db.all(
        `
        SELECT
          budgets.*,
          clients.name AS client_name,
          reports.title AS report_title,
          tasks.title AS task_title
        FROM budgets
        LEFT JOIN clients ON clients.id = budgets.client_id
        LEFT JOIN reports ON reports.id = budgets.report_id
        LEFT JOIN tasks ON tasks.id = budgets.task_id
        ${where}
        ORDER BY budgets.id DESC
      `,
        params
      );

      const includeItems = req.query.includeItems === "1";
      if (!includeItems || rows.length === 0) {
        return res.json(rows);
      }

      const ids = rows.map((row) => row.id);
      const placeholders = ids.map(() => "?").join(", ");
      const items = await db.all(
        `SELECT * FROM budget_items WHERE budget_id IN (${placeholders})`,
        ids
      );
      const grouped = new Map();
      items.forEach((item) => {
        if (!grouped.has(item.budget_id)) {
          grouped.set(item.budget_id, []);
        }
        grouped.get(item.budget_id).push(item);
      });
      rows.forEach((row) => {
        row.items = grouped.get(row.id) || [];
      });
      res.json(rows);
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar orçamentos" });
    }
  });

  app.get("/api/budgets/:id", requirePermission(PERMISSIONS.VIEW_BUDGETS), async (req, res) => {
    try {
      const budget = await db.get(
        `
        SELECT
          budgets.*,
          clients.name AS client_name,
          reports.title AS report_title,
          tasks.title AS task_title
        FROM budgets
        LEFT JOIN clients ON clients.id = budgets.client_id
        LEFT JOIN reports ON reports.id = budgets.report_id
        LEFT JOIN tasks ON tasks.id = budgets.task_id
        WHERE budgets.id = ?
      `,
        [req.params.id]
      );
      if (!budget) {
        return res.status(404).json({ error: "Orçamento não encontrado" });
      }
      const items = await db.all(
        "SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC",
        [req.params.id]
      );
      budget.items = items;
      res.json(budget);
    } catch (error) {
      res.status(500).json({ error: "Falha ao carregar orçamento" });
    }
  });

  app.get("/api/budgets/:id/pdf", requirePermission(PERMISSIONS.VIEW_BUDGETS), async (req, res) => {
    try {
      const data = await fetchBudgetPdfData(db, req.params.id);
      if (!data) {
        return res.status(404).json({ error: "Orçamento não encontrado" });
      }
      const { buildBudgetPdfHtml } = await loadPdfHelpers();
      const html = buildBudgetPdfHtml({
        budget: data.budget,
        client: data.client,
        logoUrl: getLogoDataUrl()
      });
      const pdf = await renderPdfFromHtml(html);
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `inline; filename=\"orcamento_${req.params.id}.pdf\"`);
      res.send(pdf);
    } catch (error) {
      res.status(500).json({ error: "Falha ao gerar PDF do orçamento" });
    }
  });

  app.post("/api/budgets", requirePermission(PERMISSIONS.MANAGE_BUDGETS), async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["client_id"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }

      const rawItems = Array.isArray(req.body.items) ? req.body.items : [];
      const items = rawItems.map((item) => {
        const qty = toNumber(item.qty || 0);
        const unitPrice = toNumber(item.unit_price || 0);
        return {
          product_id: item.product_id || null,
          description: item.description || "Item",
          qty,
          unit_price: unitPrice,
          total: qty * unitPrice
        };
      });

      const totals = calcBudgetTotals(items, req.body.discount, req.body.tax);
      const fields = [
        "client_id",
        "task_id",
        "report_id",
        "notes",
        "internal_note",
        "proposal_validity",
        "payment_terms",
        "service_deadline",
        "product_validity",
        "status",
        "subtotal",
        "discount",
        "tax",
        "total",
        "created_at"
      ];
      const existing = await db.get("SELECT created_at FROM budgets WHERE id = ?", [
        req.params.id
      ]);
      const createdAt =
        req.body.created_at || existing?.created_at || new Date().toISOString();
      const payload = {
        ...req.body,
        ...totals,
        created_at: createdAt
      };
      const data = buildPayload(payload, fields, []);
      const placeholders = fields.map(() => "?").join(", ");
      const sql = `INSERT INTO budgets (${fields.join(", ")}) VALUES (${placeholders})`;
      const result = await db.run(sql, fields.map((field) => data[field]));

      for (const item of items) {
        await db.run(
          `
          INSERT INTO budget_items (budget_id, product_id, description, qty, unit_price, total)
          VALUES (?, ?, ?, ?, ?, ?)
        `,
          [
            result.lastID,
            item.product_id,
            item.description,
            item.qty,
            item.unit_price,
            item.total
          ]
        );
      }

      const budget = await db.get("SELECT * FROM budgets WHERE id = ?", [result.lastID]);
      budget.items = await db.all(
        "SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC",
        [result.lastID]
      );
      res.status(201).json(budget);
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar orçamento" });
    }
  });

  app.put("/api/budgets/:id", requirePermission(PERMISSIONS.MANAGE_BUDGETS), async (req, res) => {
    try {
      const rawItems = Array.isArray(req.body.items) ? req.body.items : [];
      const items = rawItems.map((item) => {
        const qty = toNumber(item.qty || 0);
        const unitPrice = toNumber(item.unit_price || 0);
        return {
          product_id: item.product_id || null,
          description: item.description || "Item",
          qty,
          unit_price: unitPrice,
          total: qty * unitPrice
        };
      });

      const totals = calcBudgetTotals(items, req.body.discount, req.body.tax);
      const fields = [
        "client_id",
        "task_id",
        "report_id",
        "notes",
        "internal_note",
        "proposal_validity",
        "payment_terms",
        "service_deadline",
        "product_validity",
        "status",
        "subtotal",
        "discount",
        "tax",
        "total",
        "created_at"
      ];
      const payload = {
        ...req.body,
        ...totals,
        created_at: req.body.created_at || new Date().toISOString()
      };
      const data = buildPayload(payload, fields, []);
      const setClause = fields.map((field) => `${field} = ?`).join(", ");
      const sql = `UPDATE budgets SET ${setClause} WHERE id = ?`;
      const values = fields.map((field) => data[field]);
      values.push(req.params.id);
      await db.run(sql, values);

      await db.run("DELETE FROM budget_items WHERE budget_id = ?", [req.params.id]);
      for (const item of items) {
        await db.run(
          `
          INSERT INTO budget_items (budget_id, product_id, description, qty, unit_price, total)
          VALUES (?, ?, ?, ?, ?, ?)
        `,
          [
            req.params.id,
            item.product_id,
            item.description,
            item.qty,
            item.unit_price,
            item.total
          ]
        );
      }

      const budget = await db.get("SELECT * FROM budgets WHERE id = ?", [req.params.id]);
      budget.items = await db.all(
        "SELECT * FROM budget_items WHERE budget_id = ? ORDER BY id ASC",
        [req.params.id]
      );
      res.json(budget);
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar orçamento" });
    }
  });

  app.delete("/api/budgets/:id", requirePermission(PERMISSIONS.MANAGE_BUDGETS), async (req, res) => {
    try {
      await db.run("DELETE FROM budgets WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover orçamento" });
    }
  });

  const staticDir = resolveStaticDir();
  if (staticDir) {
    app.use(express.static(staticDir));
    app.get("*", (req, res) => {
      if (req.path.startsWith("/api")) {
        return res.status(404).json({ error: "Rota não encontrada" });
      }
      res.sendFile(path.join(staticDir, "index.html"));
    });
  } else {
    app.get("/", (req, res) => {
      res
        .status(404)
        .send("Front-end não encontrado. Gere o build do web/dist.");
    });
  }

  return new Promise((resolve, reject) => {
    const server = app.listen(PORT, () => {
      console.log(`API rodando em http://localhost:${PORT}`);
      resolve(server);
    });
    server.on("error", reject);
  });
}

if (require.main === module) {
  main().catch((error) => {
    console.error("Falha ao iniciar o servidor", error);
    process.exit(1);
  });
}

module.exports = { main };

