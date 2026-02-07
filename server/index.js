const path = require("path");
const { pathToFileURL } = require("url");
require("dotenv").config({ path: path.join(__dirname, ".env") });
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const crypto = require("crypto");
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

const RESERVED_ROLE_KEYS = ["administracao", "gestor", "tecnico", "visitante"];

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
  if (user.role_is_admin || user.role === "administracao") return ALL_PERMISSIONS;
  const base =
    user.role_permissions !== undefined
      ? parsePermissions(user.role_permissions)
      : ROLE_DEFAULTS[user.role] || ROLE_DEFAULTS.visitante;
  return Array.from(new Set(base));
}

function hasPermission(user, permission) {
  if (!user) return false;
  if (user.role_is_admin || user.role === "administracao") return true;
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
    role_name: user.role_name || user.role,
    role_is_admin: Boolean(user.role_is_admin),
    role_permissions: parsePermissions(user.role_permissions),
    permissions: parsePermissions(user.permissions)
  };
}

function normalizeRole(role) {
  if (!role) return null;
  return {
    id: role.id,
    key: role.key,
    name: role.name,
    permissions: parsePermissions(role.permissions),
    is_admin: Boolean(role.is_admin)
  };
}

function slugifyRoleKey(value) {
  return value
    .toString()
    .trim()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .toLowerCase();
}

async function getUserWithRole(db, userId) {
  return db.get(
    `SELECT users.id,
            users.name,
            users.email,
            users.role,
            users.permissions,
            roles.name AS role_name,
            roles.permissions AS role_permissions,
            roles.is_admin AS role_is_admin
     FROM users
     LEFT JOIN roles ON roles.key = users.role
     WHERE users.id = ?`,
    [userId]
  );
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
    if (req.path.startsWith("/public/")) {
      return next();
    }
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) {
      return res.status(401).json({ error: "Não autorizado" });
    }
    try {
      const payload = jwt.verify(token, JWT_SECRET);
      const user = await getUserWithRole(db, payload.id);
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
  if (!req.user || !req.user.role_is_admin) {
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


async function ensureDefaultRoles(db) {
  const defaults = [
    { key: "administracao", name: "Administração", permissions: ALL_PERMISSIONS, is_admin: 1 },
    { key: "gestor", name: "Gestor", permissions: ROLE_DEFAULTS.gestor, is_admin: 0 },
    { key: "tecnico", name: "Técnico", permissions: ROLE_DEFAULTS.tecnico, is_admin: 0 },
    { key: "visitante", name: "Visitante", permissions: ROLE_DEFAULTS.visitante, is_admin: 0 }
  ];

  for (const role of defaults) {
    const exists = await db.get("SELECT id, name, is_admin FROM roles WHERE key = ?", [role.key]);
    if (!exists) {
      await db.run(
        "INSERT INTO roles (key, name, permissions, is_admin) VALUES (?, ?, ?, ?)",
        [role.key, role.name, JSON.stringify(role.permissions || []), role.is_admin ? 1 : 0]
      );
      continue;
    }
    const shouldFixName = !exists.name || exists.name.includes("?");
    const shouldFixAdmin = role.is_admin && !Number(exists.is_admin);
    const nextName = shouldFixName ? role.name : exists.name;
    const nextAdmin = shouldFixAdmin ? 1 : Number(exists.is_admin) ? 1 : 0;
    if (nextName !== exists.name || nextAdmin !== Number(exists.is_admin)) {
      await db.run("UPDATE roles SET name = ?, is_admin = ? WHERE id = ?", [
        nextName,
        nextAdmin,
        exists.id
      ]);
    }
  }
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
const PDF_CACHE_ENABLED = String(process.env.PDF_CACHE_ENABLED || "true").toLowerCase() !== "false";
const PDF_CACHE_ROOT = path.join(__dirname, ".cache", "pdfs");
const PDF_WARM_DEBOUNCE_MS = Math.max(0, Number(process.env.PDF_WARM_DEBOUNCE_MS || 1500));
const pdfInFlight = {
  tasks: new Map(),
  budgets: new Map()
};
const taskWarmTimers = new Map();
const budgetWarmTimers = new Map();
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL || "";
const PUBLIC_LINK_DEFAULT_DAYS = Math.max(1, Number(process.env.PUBLIC_LINK_DEFAULT_DAYS || 30));

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function getPdfCacheDir(type) {
  ensureDir(PDF_CACHE_ROOT);
  const dir = path.join(PDF_CACHE_ROOT, type);
  ensureDir(dir);
  return dir;
}

function getPdfCachePath(type, id, hash) {
  const dir = getPdfCacheDir(type);
  return path.join(dir, `${id}-${hash}.pdf`);
}

function removeOldPdfCaches(type, id, keepHash) {
  try {
    const dir = getPdfCacheDir(type);
    const prefix = `${id}-`;
    const files = fs.readdirSync(dir);
    for (const file of files) {
      if (!file.startsWith(prefix) || !file.endsWith(".pdf")) continue;
      if (keepHash && file.includes(keepHash)) continue;
      fs.rmSync(path.join(dir, file), { force: true });
    }
  } catch (error) {
    // Falhas de limpeza não devem interromper a geração.
  }
}

function hashUpdate(hash, value) {
  if (value === undefined) {
    hash.update("undefined");
    return;
  }
  if (value === null) {
    hash.update("null");
    return;
  }
  if (typeof value === "string") {
    hash.update(value);
    return;
  }
  try {
    hash.update(JSON.stringify(value));
  } catch (error) {
    hash.update(String(value));
  }
}

function sortById(list) {
  return [...(list || [])].sort((a, b) => {
    const aId = Number(a?.id || 0);
    const bId = Number(b?.id || 0);
    return aId - bId;
  });
}

function computeTaskPdfHash(data, logoUrl) {
  const hash = crypto.createHash("sha256");

  hashUpdate(hash, "task");
  hashUpdate(hash, data?.task);
  hashUpdate(hash, "client");
  hashUpdate(hash, data?.client);
  hashUpdate(hash, "logo");
  hashUpdate(hash, logoUrl || "");

  for (const report of sortById(data?.reports)) {
    hashUpdate(hash, "report");
    hashUpdate(hash, {
      id: report.id,
      title: report.title,
      status: report.status,
      equipment_id: report.equipment_id,
      equipment_name: report.equipment_name,
      template_id: report.template_id,
      client_id: report.client_id,
      task_id: report.task_id,
      created_at: report.created_at
    });

    const content = report.content || {};
    hashUpdate(hash, content.layout);
    hashUpdate(hash, content.sections);
    hashUpdate(hash, content.answers);

    const photos = sortById(content.photos || []);
    hashUpdate(hash, photos.length);
    for (const photo of photos) {
      hashUpdate(hash, photo.id);
      hashUpdate(hash, photo.name);
      hashUpdate(hash, photo.dataUrl);
    }
  }

  for (const budget of sortById(data?.budgets)) {
    hashUpdate(hash, "budget");
    hashUpdate(hash, {
      id: budget.id,
      client_id: budget.client_id,
      task_id: budget.task_id,
      report_id: budget.report_id,
      notes: budget.notes,
      internal_note: budget.internal_note,
      proposal_validity: budget.proposal_validity,
      payment_terms: budget.payment_terms,
      service_deadline: budget.service_deadline,
      product_validity: budget.product_validity,
      status: budget.status,
      subtotal: budget.subtotal,
      discount: budget.discount,
      tax: budget.tax,
      total: budget.total,
      created_at: budget.created_at
    });

    const items = sortById(budget.items || []);
    hashUpdate(hash, items.length);
    for (const item of items) {
      hashUpdate(hash, {
        id: item.id,
        budget_id: item.budget_id,
        product_id: item.product_id,
        description: item.description,
        qty: item.qty,
        unit_price: item.unit_price,
        total: item.total
      });
    }
  }

  return hash.digest("hex");
}

function computeBudgetPdfHash(data, logoUrl) {
  const hash = crypto.createHash("sha256");

  hashUpdate(hash, "budget");
  hashUpdate(hash, data?.budget);
  hashUpdate(hash, "client");
  hashUpdate(hash, data?.client);
  hashUpdate(hash, "logo");
  hashUpdate(hash, logoUrl || "");

  const items = sortById(data?.budget?.items || []);
  hashUpdate(hash, items.length);
  for (const item of items) {
    hashUpdate(hash, {
      id: item.id,
      budget_id: item.budget_id,
      product_id: item.product_id,
      description: item.description,
      qty: item.qty,
      unit_price: item.unit_price,
      total: item.total
    });
  }

  return hash.digest("hex");
}

async function getCachedPdf({ type, id, hash, forceRefresh, render }) {
  if (!PDF_CACHE_ENABLED) {
    return render();
  }

  const cachePath = getPdfCachePath(type, id, hash);
  if (!forceRefresh && fs.existsSync(cachePath)) {
    return fs.readFileSync(cachePath);
  }

  const inFlightKey = `${id}:${hash}`;
  const inFlightMap = pdfInFlight[type];
  if (inFlightMap.has(inFlightKey)) {
    return inFlightMap.get(inFlightKey);
  }

  const promise = (async () => {
    const pdfBuffer = await render();
    try {
      removeOldPdfCaches(type, id, hash);
      fs.writeFileSync(cachePath, pdfBuffer);
    } catch (error) {
      // Falhas de cache não devem impedir a resposta.
    }
    return pdfBuffer;
  })();

  inFlightMap.set(inFlightKey, promise);
  try {
    return await promise;
  } finally {
    inFlightMap.delete(inFlightKey);
  }
}

async function warmTaskPdfCache(db, taskId, forceRefresh = true) {
  if (!PDF_CACHE_ENABLED) return;
  const numericTaskId = Number(taskId);
  if (!Number.isFinite(numericTaskId) || numericTaskId <= 0) return;

  const data = await fetchTaskPdfData(db, numericTaskId);
  if (!data) return;

  const logoUrl = getLogoDataUrl();
  const cacheHash = computeTaskPdfHash(data, logoUrl);
  const { buildTaskPdfHtml } = await loadPdfHelpers();

  await getCachedPdf({
    type: "tasks",
    id: numericTaskId,
    hash: cacheHash,
    forceRefresh,
    render: async () => {
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
        logoUrl
      });
      return renderPdfFromHtml(html);
    }
  });
}

async function warmBudgetPdfCache(db, budgetId, forceRefresh = true) {
  if (!PDF_CACHE_ENABLED) return;
  const numericBudgetId = Number(budgetId);
  if (!Number.isFinite(numericBudgetId) || numericBudgetId <= 0) return;

  const data = await fetchBudgetPdfData(db, numericBudgetId);
  if (!data) return;

  const logoUrl = getLogoDataUrl();
  const cacheHash = computeBudgetPdfHash(data, logoUrl);
  const { buildBudgetPdfHtml } = await loadPdfHelpers();

  await getCachedPdf({
    type: "budgets",
    id: numericBudgetId,
    hash: cacheHash,
    forceRefresh,
    render: async () => {
      const html = buildBudgetPdfHtml({
        budget: data.budget,
        client: data.client,
        signatureMode: data.budget?.signature_mode,
        signatureScope: data.budget?.signature_scope,
        signatureClient: data.budget?.signature_client,
        signatureTech: data.budget?.signature_tech,
        signaturePages: data.budget?.signature_pages || {},
        logoUrl
      });
      return renderPdfFromHtml(html);
    }
  });
}

function scheduleWarmTaskPdfCache(db, taskId, forceRefresh = true) {
  if (!PDF_CACHE_ENABLED) return;
  const numericTaskId = Number(taskId);
  if (!Number.isFinite(numericTaskId) || numericTaskId <= 0) return;

  const existing = taskWarmTimers.get(numericTaskId);
  if (existing) clearTimeout(existing);

  const timer = setTimeout(() => {
    taskWarmTimers.delete(numericTaskId);
    warmTaskPdfCache(db, numericTaskId, forceRefresh).catch(() => {});
  }, PDF_WARM_DEBOUNCE_MS);

  taskWarmTimers.set(numericTaskId, timer);
}

function scheduleWarmBudgetPdfCache(db, budgetId, forceRefresh = true) {
  if (!PDF_CACHE_ENABLED) return;
  const numericBudgetId = Number(budgetId);
  if (!Number.isFinite(numericBudgetId) || numericBudgetId <= 0) return;

  const existing = budgetWarmTimers.get(numericBudgetId);
  if (existing) clearTimeout(existing);

  const timer = setTimeout(() => {
    budgetWarmTimers.delete(numericBudgetId);
    warmBudgetPdfCache(db, numericBudgetId, forceRefresh).catch(() => {});
  }, PDF_WARM_DEBOUNCE_MS);

  budgetWarmTimers.set(numericBudgetId, timer);
}

function isCachedPdfReady(type, id, hash) {
  if (!PDF_CACHE_ENABLED) return false;
  try {
    const cachePath = getPdfCachePath(type, id, hash);
    return fs.existsSync(cachePath);
  } catch (_) {
    return false;
  }
}

async function getTaskPdfCacheStatus(db, taskId) {
  const numericTaskId = Number(taskId);
  if (!Number.isFinite(numericTaskId) || numericTaskId <= 0) return null;
  const data = await fetchTaskPdfData(db, numericTaskId);
  if (!data) return null;
  const logoUrl = getLogoDataUrl();
  const hash = computeTaskPdfHash(data, logoUrl);
  const ready = isCachedPdfReady("tasks", numericTaskId, hash);
  return { ready, hash };
}

async function getBudgetPdfCacheStatus(db, budgetId) {
  const numericBudgetId = Number(budgetId);
  if (!Number.isFinite(numericBudgetId) || numericBudgetId <= 0) return null;
  const data = await fetchBudgetPdfData(db, numericBudgetId);
  if (!data) return null;
  const logoUrl = getLogoDataUrl();
  const hash = computeBudgetPdfHash(data, logoUrl);
  const ready = isCachedPdfReady("budgets", numericBudgetId, hash);
  return { ready, hash, taskId: data.budget?.task_id };
}

function toBase64Url(buffer) {
  return buffer
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function generatePublicToken() {
  return toBase64Url(crypto.randomBytes(24));
}

function nowIso() {
  return new Date().toISOString();
}

function addDaysIso(days) {
  const numeric = Number(days);
  if (!Number.isFinite(numeric) || numeric <= 0) return null;
  const date = new Date();
  date.setDate(date.getDate() + numeric);
  return date.toISOString();
}

function getPublicBaseUrl(req) {
  if (PUBLIC_BASE_URL) {
    return PUBLIC_BASE_URL.replace(/\/+$/g, "");
  }
  const protocol = req.headers["x-forwarded-proto"] || req.protocol || "https";
  const host = req.get("host");
  return `${protocol}://${host}`;
}

function buildPublicTaskUrl(req, taskId, token) {
  const base = getPublicBaseUrl(req);
  const encodedToken = encodeURIComponent(token);
  return `${base}/public/tasks/${taskId}?token=${encodedToken}`;
}

function buildPublicBudgetUrl(req, budgetId, token) {
  const base = getPublicBaseUrl(req);
  const encodedToken = encodeURIComponent(token);
  return `${base}/public/budgets/${budgetId}?token=${encodedToken}`;
}

async function getActivePublicLink(db, taskId) {
  const current = nowIso();
  return db.get(
    `
    SELECT *
    FROM task_public_links
    WHERE task_id = ?
      AND revoked_at IS NULL
      AND (expires_at IS NULL OR expires_at > ?)
    ORDER BY id DESC
    LIMIT 1
  `,
    [taskId, current]
  );
}

async function createPublicLink(db, taskId, userId, expiresAt) {
  const createdAt = nowIso();
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const token = generatePublicToken();
    try {
      const result = await db.run(
        `
        INSERT INTO task_public_links (task_id, token, created_at, created_by_user_id, expires_at)
        VALUES (?, ?, ?, ?, ?)
      `,
        [taskId, token, createdAt, userId || null, expiresAt]
      );
      const row = await db.get("SELECT * FROM task_public_links WHERE id = ?", [
        result.lastID
      ]);
      return row;
    } catch (error) {
      const message = String(error?.message || "").toLowerCase();
      const isUniqueError = message.includes("unique") || message.includes("duplicate");
      if (!isUniqueError) {
        throw error;
      }
    }
  }
  throw new Error("Falha ao gerar token publico");
}

async function getActiveBudgetPublicLink(db, budgetId) {
  const current = nowIso();
  return db.get(
    `
    SELECT *
    FROM budget_public_links
    WHERE budget_id = ?
      AND revoked_at IS NULL
      AND (expires_at IS NULL OR expires_at > ?)
    ORDER BY id DESC
    LIMIT 1
  `,
    [budgetId, current]
  );
}

async function createBudgetPublicLink(db, budgetId, userId, expiresAt) {
  const createdAt = nowIso();
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const token = generatePublicToken();
    try {
      const result = await db.run(
        `
        INSERT INTO budget_public_links (budget_id, token, created_at, created_by_user_id, expires_at)
        VALUES (?, ?, ?, ?, ?)
      `,
        [budgetId, token, createdAt, userId || null, expiresAt]
      );
      const row = await db.get("SELECT * FROM budget_public_links WHERE id = ?", [
        result.lastID
      ]);
      return row;
    } catch (error) {
      const message = String(error?.message || "").toLowerCase();
      const isUniqueError = message.includes("unique") || message.includes("duplicate");
      if (!isUniqueError) {
        throw error;
      }
    }
  }
  throw new Error("Falha ao gerar token publico");
}

async function findValidPublicLink(db, taskId, token) {
  if (!token) return null;
  const current = nowIso();
  const link = await db.get(
    `
    SELECT *
    FROM task_public_links
    WHERE task_id = ?
      AND token = ?
      AND revoked_at IS NULL
      AND (expires_at IS NULL OR expires_at > ?)
    LIMIT 1
  `,
    [taskId, token, current]
  );
  if (!link) return null;
  await db.run("UPDATE task_public_links SET last_used_at = ? WHERE id = ?", [
    current,
    link.id
  ]);
  return link;
}

async function findValidBudgetPublicLink(db, budgetId, token) {
  if (!token) return null;
  const current = nowIso();
  const link = await db.get(
    `
    SELECT *
    FROM budget_public_links
    WHERE budget_id = ?
      AND token = ?
      AND revoked_at IS NULL
      AND (expires_at IS NULL OR expires_at > ?)
    LIMIT 1
  `,
    [budgetId, token, current]
  );
  if (!link) return null;
  await db.run("UPDATE budget_public_links SET last_used_at = ? WHERE id = ?", [
    current,
    link.id
  ]);
  return link;
}


function normalizePublicStatusLabel(status) {
  if (!status) return null;
  const value = String(status).toLowerCase();
  switch (value) {
    case "aprovado":
      return { text: "Aprovado", variant: "success" };
    case "em_andamento":
      return { text: "Em andamento", variant: "warning" };
    case "recusado":
      return { text: "Recusado", variant: "danger" };
    case "enviado":
      return { text: "Enviado", variant: "info" };
    case "rascunho":
      return { text: "Rascunho", variant: "neutral" };
    default:
      return { text: value ? value.charAt(0).toUpperCase() + value.slice(1) : "-", variant: "neutral" };
  }
}

function injectPublicToolbar(
  html,
  {
    taskId,
    title,
    token,
    pdfUrl,
    refreshUrl,
    approveBudget = null,
    approveReport = null,
    statusLabel = null
  }
) {
  const headExtra = `
<style>
  body { margin: 0; background: #f2f6fb; }
  .public-shell { min-height: 100vh; padding: 0 0 40px; }
  .public-toolbar {
    position: sticky;
    top: 0;
    z-index: 50;
    display: flex;
    gap: 8px;
    align-items: center;
    justify-content: center;
    padding: 10px 16px;
    background: rgba(9, 28, 52, 0.94);
    color: #ffffff;
    box-shadow: 0 6px 18px rgba(12, 27, 42, 0.18);
  }
  .public-toolbar .title {
      font-weight: 700;
      margin-right: 8px;
      letter-spacing: 0.02em;
    }
  .public-toolbar .warning {
      font-size: 12px;
      opacity: 0.85;
      margin-left: 6px;
    }
  .public-toolbar button,
  .public-toolbar a {
    border: 1px solid rgba(255, 255, 255, 0.24);
    background: rgba(255, 255, 255, 0.12);
    color: #ffffff;
    padding: 8px 12px;
    border-radius: 10px;
    font-weight: 600;
    cursor: pointer;
    text-decoration: none;
    transition: all 120ms ease;
  }
  .public-toolbar button:hover,
  .public-toolbar a:hover {
    background: rgba(255, 255, 255, 0.2);
    border-color: rgba(255, 255, 255, 0.4);
  }
  .public-toolbar .status-badge {
    padding: 6px 10px;
    border-radius: 999px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    border: 1px solid rgba(255, 255, 255, 0.3);
    background: rgba(255, 255, 255, 0.16);
  }
  .public-toolbar .status-badge.success { background: rgba(34, 197, 94, 0.2); }
  .public-toolbar .status-badge.warning { background: rgba(245, 158, 11, 0.2); }
  .public-toolbar .status-badge.danger { background: rgba(239, 68, 68, 0.25); }
  .public-toolbar .status-badge.info { background: rgba(56, 189, 248, 0.2); }
  .public-content {
    width: min(1100px, 96vw);
    margin: 16px auto 0;
    display: grid;
    gap: 18px;
  }
  .public-content .page {
    box-shadow: 0 18px 38px rgba(17, 52, 86, 0.12);
    border-radius: 18px;
    background: #ffffff;
  }
  .public-approve-overlay {
    position: fixed;
    inset: 0;
    background: rgba(10, 21, 35, 0.68);
    display: none;
    align-items: center;
    justify-content: center;
    z-index: 80;
    padding: 20px;
  }
  .public-approve-overlay.active { display: flex; }
  .public-approve-card,
  .public-signature-screen {
    width: min(680px, 96vw);
    background: #ffffff;
    border-radius: 18px;
    box-shadow: 0 24px 60px rgba(10, 30, 60, 0.25);
  }
  .public-approve-card {
    padding: 20px;
    display: grid;
    gap: 16px;
  }
  .public-approve-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }
  .public-approve-header button {
    border: none;
    background: transparent;
    font-size: 18px;
    cursor: pointer;
    color: #64748b;
  }
  .public-approve-card h3 { margin: 0; }
  .public-approve-card .headline { font-weight: 700; font-size: 18px; }
  .public-approve-fields { display: grid; gap: 10px; }
  .public-approve-fields label {
    font-size: 12px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #1f2a37;
  }
  .public-approve-fields input {
    width: 100%;
    padding: 12px 14px;
    border-radius: 12px;
    border: 1px solid #d7e0ec;
    background: #f4f7fb;
    font-size: 15px;
  }
  .public-approve-actions {
    display: flex;
    gap: 8px;
    justify-content: center;
  }
  .public-signature-screen {
    display: none;
    padding: 16px;
    width: min(880px, 96vw);
    height: min(560px, 92vh);
  }
  body.public-signing { overflow: hidden; }
  body.public-signing .public-signature-screen {
    width: 100vw;
    height: 100vh;
    border-radius: 0;
  }
  body.public-signing .public-approve-signature {
    height: calc(100vh - 210px);
  }
  .public-signature-hint {
    font-size: 12px;
    color: #64748b;
    text-align: center;
    margin-top: 6px;
  }
  @media (orientation: landscape) {
    body.public-signing .public-approve-signature {
      height: calc(100vh - 180px);
    }
  }
  .public-signature-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: 10px;
    border-bottom: 1px solid #e6edf6;
  }
  .public-signature-header button {
    border: none;
    background: transparent;
    font-size: 14px;
    font-weight: 600;
    color: #0f172a;
    cursor: pointer;
  }
  .public-signature-title {
    font-weight: 700;
    font-size: 16px;
  }
  .public-signature-meta {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    font-size: 14px;
    color: #475569;
    margin: 12px 0 6px;
  }
  .public-approve-signature {
    border: 1px solid #d7e0ec;
    border-radius: 14px;
    padding: 12px;
    background: #ffffff;
    display: flex;
    flex-direction: column;
    gap: 8px;
    flex: 1;
  }
  .public-approve-signature canvas {
    width: 100%;
    height: 100%;
    background: #ffffff;
    border-radius: 10px;
    touch-action: none;
  }
  .public-signature-footer {
    padding-top: 12px;
    display: flex;
    justify-content: center;
  }
  @media print {
    body { background: #ffffff !important; }
    .public-toolbar { display: none !important; }
    .public-shell { padding: 0 !important; }
    .public-content { width: 100% !important; margin: 0 !important; gap: 0 !important; }
    .public-content .page { box-shadow: none !important; border-radius: 0 !important; }
  }
</style>
<script>
  function publicPrint() {
      window.print();
    }
  async function publicSharePdf(url) {
      if (!url) return;
      try {
        const response = await fetch(url);
        const blob = await response.blob();
        const fileName = (document.title || "relatorio").replace(/[^a-z0-9-_]+/gi, "_") + ".pdf";
        const file = new File([blob], fileName, { type: "application/pdf" });

        if (navigator.share && navigator.canShare && navigator.canShare({ files: [file] })) {
          await navigator.share({ title: document.title, files: [file] });
          return;
        }
      } catch (error) {
        // fallback below
      }
      const link = document.createElement("a");
      link.href = url;
      link.target = "_blank";
      link.rel = "noopener";
      link.click();
    }
  let approveCanvas;
  let approveCtx;
  let approveDrawing = false;
  function openBudgetApproval() {
      const overlay = document.getElementById("budget-approve-overlay");
      if (!overlay) return;
      overlay.classList.add("active");
      showApproveInfo();
    }
  function closeBudgetApproval() {
      const overlay = document.getElementById("budget-approve-overlay");
      if (!overlay) return;
      overlay.classList.remove("active");
      document.body.classList.remove("public-signing");
    }
  function showApproveInfo() {
      const info = document.getElementById("budget-approve-info");
      const signature = document.getElementById("budget-approve-signature");
      document.body.classList.remove("public-signing");
      if (info) info.style.display = "grid";
      if (signature) signature.style.display = "none";
    }
  function showApproveSignature() {
      const info = document.getElementById("budget-approve-info");
      const signature = document.getElementById("budget-approve-signature");
      if (info) info.style.display = "none";
      if (signature) signature.style.display = "flex";
      document.body.classList.add("public-signing");
      const name = document.getElementById("budget-approve-name").value.trim();
      const documentValue = document.getElementById("budget-approve-document").value.trim();
      const nameTarget = document.getElementById("budget-approve-signer-name");
      const docTarget = document.getElementById("budget-approve-signer-document");
      if (nameTarget) nameTarget.textContent = name || "";
      if (docTarget) docTarget.textContent = documentValue || "";
      setupApproveCanvas();
    }
  function setupApproveCanvas() {
      approveCanvas = document.getElementById("budget-approve-canvas");
      if (!approveCanvas) return;
      const ratio = window.devicePixelRatio || 1;
      const rect = approveCanvas.getBoundingClientRect();
      approveCanvas.width = rect.width * ratio;
      approveCanvas.height = rect.height * ratio;
      approveCtx = approveCanvas.getContext("2d");
      approveCtx.scale(ratio, ratio);
      approveCtx.lineWidth = 2;
      approveCtx.lineCap = "round";
      approveCtx.strokeStyle = "#0f172a";
      approveCanvas.onpointerdown = (event) => {
        approveDrawing = true;
        const pos = getApprovePoint(event);
        approveCtx.beginPath();
        approveCtx.moveTo(pos.x, pos.y);
      };
      approveCanvas.onpointermove = (event) => {
        if (!approveDrawing) return;
        const pos = getApprovePoint(event);
        approveCtx.lineTo(pos.x, pos.y);
        approveCtx.stroke();
      };
      approveCanvas.onpointerup = () => (approveDrawing = false);
      approveCanvas.onpointerleave = () => (approveDrawing = false);
    }
  function getApprovePoint(event) {
      const rect = approveCanvas.getBoundingClientRect();
      return {
        x: event.clientX - rect.left,
        y: event.clientY - rect.top
      };
    }
  function clearApproveCanvas() {
      if (!approveCtx || !approveCanvas) return;
      approveCtx.clearRect(0, 0, approveCanvas.width, approveCanvas.height);
    }
  async function submitBudgetApproval() {
      if (!approveCanvas) return;
      const name = document.getElementById("budget-approve-name").value.trim();
      const documentValue = document.getElementById("budget-approve-document").value.trim();
      const signature = approveCanvas.toDataURL("image/png");
      const budgetId = document.body.dataset.publicBudgetId;
      const taskId = document.body.dataset.publicTaskId;
      const token = document.body.dataset.publicToken;
      try {
        const endpoint = budgetId
          ? '/public/budgets/' + budgetId + '/approve?token=' + encodeURIComponent(token)
          : '/public/tasks/' + taskId + '/approve?token=' + encodeURIComponent(token);
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ signature, name, document: documentValue })
        });
        if (!response.ok) {
          throw new Error(await response.text());
        }
        window.location.reload();
      } catch (error) {
        alert("Falha ao enviar assinatura. Tente novamente.");
      }
    }
  </script>`;

  const displayTitle = title || `Relatorio da tarefa #${taskId}`;
  const shareButton = pdfUrl
    ? `<button type="button" onclick="publicSharePdf('${pdfUrl}')">Compartilhar PDF</button>`
    : "";
  const approveButton = approveBudget
    ? `<button type="button" onclick="openBudgetApproval()">Aprovar orçamento</button>`
    : approveReport
      ? `<button type="button" onclick="openBudgetApproval()">Assinar relatório</button>`
      : "";
  const normalizedStatus = normalizePublicStatusLabel(statusLabel);
  const statusBadge = normalizedStatus
    ? `<span class="status-badge ${normalizedStatus.variant}">${normalizedStatus.text}</span>`
    : "";
  const approveModal = approveBudget || approveReport
    ? `
    <div class="public-approve-overlay" id="budget-approve-overlay">
      <div class="public-approve-card" id="budget-approve-info">
        <div class="public-approve-header">
          <h3>Assinatura</h3>
          <button type="button" aria-label="Fechar" onclick="closeBudgetApproval()">×</button>
        </div>
        <div>
          <div class="headline">Quem está assinando?</div>
        </div>
        <div class="public-approve-fields">
          <label for="budget-approve-name">Nome</label>
          <input id="budget-approve-name" type="text" placeholder="Nome" />
          <label for="budget-approve-document">CPF (opcional)</label>
          <input id="budget-approve-document" type="text" placeholder="CPF" />
        </div>
        <div class="public-approve-actions">
          <button type="button" onclick="showApproveSignature()">Continuar</button>
        </div>
      </div>
      <div class="public-signature-screen" id="budget-approve-signature">
        <div class="public-signature-header">
          <button type="button" onclick="closeBudgetApproval()">Fechar</button>
          <div class="public-signature-title">Assinatura</div>
          <button type="button" onclick="clearApproveCanvas()">Limpar</button>
        </div>
        <div class="public-signature-meta">
          <div id="budget-approve-signer-name"></div>
          <div id="budget-approve-signer-document"></div>
        </div>
        <div class="public-signature-hint">Gire o celular para assinar na horizontal.</div>
        <div class="public-approve-signature">
          <canvas id="budget-approve-canvas"></canvas>
        </div>
        <div class="public-signature-footer">
          <button type="button" onclick="submitBudgetApproval()">Salvar assinatura</button>
        </div>
      </div>
    </div>
  `
    : "";

const toolbarHtml = `
<div class="public-toolbar">
    <div class="title">${displayTitle}</div>
    ${statusBadge}
    <button type="button" onclick="publicPrint()">Imprimir/Salvar PDF</button>
    ${shareButton}
    ${approveButton}
    <a href="${refreshUrl}">Atualizar</a>
    <span class="warning">Recomendamos baixar o PDF: o link expira em 30 dias.</span>
  </div>`;

  let updated = html.replace("</head>", `${headExtra}</head>`);
  updated = updated.replace(
    "<body>",
    `<body data-public-token="${token}" ${
      approveBudget ? `data-public-budget-id="${approveBudget.budgetId}"` : ""
    } ${
      approveReport ? `data-public-task-id="${approveReport.taskId}"` : ""
    }><div class="public-shell">${toolbarHtml}${approveModal}<main class="public-content">`
  );
  updated = updated.replace("</body>", "</main></div></body>");
  return updated;
}

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
    const modulePath =
      process.env.PDF_TEMPLATE_PATH ||
      path.join(__dirname, "..", "web", "src", "utils", "pdf.js");
    if (!fs.existsSync(modulePath)) {
      throw new Error("Template de PDF não encontrado.");
    }
    pdfHelpersPromise = import(pathToFileURL(modulePath).href);
  }
  return pdfHelpersPromise;
}

async function getPdfBrowser() {
  if (!pdfBrowserPromise) {
    const launchOptions = {
      headless: "new",
      args: ["--no-sandbox", "--disable-setuid-sandbox"]
    };
    if (process.env.PUPPETEER_EXECUTABLE_PATH) {
      launchOptions.executablePath = process.env.PUPPETEER_EXECUTABLE_PATH;
    }
    if (process.env.PUPPETEER_ARGS) {
      const extraArgs = process.env.PUPPETEER_ARGS.split(",")
        .map((arg) => arg.trim())
        .filter(Boolean);
      launchOptions.args = [...launchOptions.args, ...extraArgs];
    }
    pdfBrowserPromise = puppeteer.launch(launchOptions);
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
  const budget = parseJsonFields(
    await db.get(
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
    ),
    ["signature_pages"]
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
  await ensureDefaultRoles(db);
  await ensureAdminUser(db);
  const app = express();

  app.use(cors());
  app.use(express.json({ limit: "10mb" }));

  app.get("/api/health", (req, res) => {
    res.json({ ok: true });
  });

  app.get("/api/app/mobile-update", (req, res) => {
    const versionCode = Number(process.env.MOBILE_APP_VERSION_CODE || 0);
    const versionName = (process.env.MOBILE_APP_VERSION_NAME || "").trim();
    const apkUrl = (process.env.MOBILE_APP_APK_URL || "").trim();
    const notes = (process.env.MOBILE_APP_NOTES || "").trim();
    const mandatory = String(process.env.MOBILE_APP_MANDATORY || "").toLowerCase() === "true";

    if (!apkUrl || !versionCode) {
      return res.status(204).end();
    }

    return res.json({
      versionCode,
      versionName,
      apkUrl,
      notes,
      mandatory
    });
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
      const user = await getUserWithRole(db, result.lastID);
      const token = signToken(user);
      res.status(201).json({ user: { ...normalizeUser(user), permissions: getUserPermissions(user) }, token });
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
      const rawUser = await db.get("SELECT * FROM users WHERE lower(email) = lower(?)", [req.body.email]);
      if (!rawUser || !rawUser.password_hash) {
        return res.status(401).json({ error: "Credenciais inválidas" });
      }
      const valid = await bcrypt.compare(req.body.password, rawUser.password_hash);
      if (!valid) {
        return res.status(401).json({ error: "Credenciais inválidas" });
      }
      const user = await getUserWithRole(db, rawUser.id);
      const token = signToken(user);
      res.json({ user: { ...normalizeUser(user), permissions: getUserPermissions(user) }, token });
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

  app.get("/api/users", requirePermission(PERMISSIONS.VIEW_USERS), async (req, res) => {
    try {
      const users = await db.all(
        `SELECT users.id,
                users.name,
                users.email,
                users.role,
                users.permissions,
                roles.name AS role_name,
                roles.permissions AS role_permissions,
                roles.is_admin AS role_is_admin
         FROM users
         LEFT JOIN roles ON roles.key = users.role
         ORDER BY users.name ASC`
      );
      res.json(users.map(normalizeUser));
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar usuários" });
    }
  });

  app.post("/api/users", requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
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
      const user = await getUserWithRole(db, result.lastID);
      res.status(201).json(normalizeUser(user));
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar usuário" });
    }
  });

  app.put("/api/users/:id", requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
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
      const user = await getUserWithRole(db, req.params.id);
      res.json(normalizeUser(user));
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar usuário" });
    }
  });

  app.delete("/api/users/:id", requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
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

  app.get("/api/roles", requirePermission(PERMISSIONS.VIEW_USERS), async (req, res) => {
    try {
      const roles = await db.all("SELECT id, key, name, permissions, is_admin FROM roles ORDER BY name ASC");
      res.json(roles.map(normalizeRole));
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar cargos" });
    }
  });

  app.post("/api/roles", requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
    try {
      const missing = ensureFields(req.body, ["name"]);
      if (missing.length) {
        return res.status(400).json({ error: "Campos obrigatórios ausentes", missing });
      }
      const name = req.body.name.toString().trim();
      const key = req.body.key ? slugifyRoleKey(req.body.key) : slugifyRoleKey(name);
      if (!key) {
        return res.status(400).json({ error: "Código do cargo inválido" });
      }
      const exists = await db.get("SELECT id FROM roles WHERE key = ?", [key]);
      if (exists) {
        return res.status(400).json({ error: "Já existe um cargo com este código" });
      }
      const permissions = Array.isArray(req.body.permissions) ? req.body.permissions : [];
      const isAdmin = req.body.is_admin ? 1 : 0;
      const result = await db.run("INSERT INTO roles (key, name, permissions, is_admin) VALUES (?, ?, ?, ?)", [key, name, JSON.stringify(permissions), isAdmin]);
      const role = await db.get("SELECT id, key, name, permissions, is_admin FROM roles WHERE id = ?", [result.lastID]);
      res.status(201).json(normalizeRole(role));
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar cargo" });
    }
  });

  app.put("/api/roles/:id", requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
    try {
      const roleId = Number(req.params.id);
      const role = await db.get("SELECT id, key FROM roles WHERE id = ?", [roleId]);
      if (!role) {
        return res.status(404).json({ error: "Cargo não encontrado" });
      }
      const name = req.body.name ? req.body.name.toString().trim() : null;
      const permissions = Array.isArray(req.body.permissions) ? req.body.permissions : [];
      const isAdmin = req.body.is_admin ? 1 : 0;
      await db.run("UPDATE roles SET name = ?, permissions = ?, is_admin = ? WHERE id = ?", [name || role.key, JSON.stringify(permissions), isAdmin, roleId]);
      const updated = await db.get("SELECT id, key, name, permissions, is_admin FROM roles WHERE id = ?", [roleId]);
      res.json(normalizeRole(updated));
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar cargo" });
    }
  });

  app.delete("/api/roles/:id", requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
    try {
      const roleId = Number(req.params.id);
      const role = await db.get("SELECT id, key FROM roles WHERE id = ?", [roleId]);
      if (!role) {
        return res.status(404).json({ error: "Cargo não encontrado" });
      }
      if (RESERVED_ROLE_KEYS.includes(role.key)) {
        return res.status(400).json({ error: "Não é permitido remover este cargo" });
      }
      const inUse = await db.get("SELECT COUNT(*) AS count FROM users WHERE role = ?", [role.key]);
      if (Number(inUse?.count || 0) > 0) {
        return res.status(400).json({ error: "Este cargo está vinculado a usuários" });
      }
      await db.run("DELETE FROM roles WHERE id = ?", [roleId]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover cargo" });
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
      scheduleWarmTaskPdfCache(db, task.id);

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
      scheduleWarmTaskPdfCache(db, req.params.id);
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

  app.post("/api/tasks/:id/public-link", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const task = await db.get("SELECT id FROM tasks WHERE id = ?", [req.params.id]);
      if (!task) {
        return res.status(404).json({ error: "Tarefa nao encontrada" });
      }

      const forceNew = req.body?.force_new === true || req.body?.forceNew === true;
      let link = forceNew ? null : await getActivePublicLink(db, task.id);
      if (!link) {
        const requestedDays = req.body?.expires_in_days ?? req.body?.expiresInDays;
        const expiresAt = addDaysIso(requestedDays ?? PUBLIC_LINK_DEFAULT_DAYS);
        link = await createPublicLink(db, task.id, req.user?.id, expiresAt);
      }

      const url = buildPublicTaskUrl(req, task.id, link.token);
      scheduleWarmTaskPdfCache(db, task.id);
      res.json({
        id: link.id,
        token: link.token,
        url,
        created_at: link.created_at,
        expires_at: link.expires_at,
        reused: !forceNew
      });
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar link publico" });
    }
  });

  app.post("/api/budgets/:id/public-link", requirePermission(PERMISSIONS.VIEW_BUDGETS), async (req, res) => {
    try {
      const budget = await db.get("SELECT id FROM budgets WHERE id = ?", [req.params.id]);
      if (!budget) {
        return res.status(404).json({ error: "Orcamento nao encontrado" });
      }

      const forceNew = req.body?.force_new === true || req.body?.forceNew === true;
      let link = forceNew ? null : await getActiveBudgetPublicLink(db, budget.id);
      if (!link) {
        const requestedDays = req.body?.expires_in_days ?? req.body?.expiresInDays;
        const expiresAt = addDaysIso(requestedDays ?? PUBLIC_LINK_DEFAULT_DAYS);
        link = await createBudgetPublicLink(db, budget.id, req.user?.id, expiresAt);
      }

      const url = buildPublicBudgetUrl(req, budget.id, link.token);
      scheduleWarmBudgetPdfCache(db, budget.id);
      res.json({
        id: link.id,
        token: link.token,
        url,
        created_at: link.created_at,
        expires_at: link.expires_at,
        reused: !forceNew
      });
    } catch (error) {
      res.status(500).json({ error: "Falha ao criar link publico" });
    }
  });

  app.delete(
    "/api/tasks/:id/public-link/:linkId",
    requirePermission(PERMISSIONS.MANAGE_TASKS),
    async (req, res) => {
      try {
        const link = await db.get(
          "SELECT id FROM task_public_links WHERE id = ? AND task_id = ?",
          [req.params.linkId, req.params.id]
        );
        if (!link) {
          return res.status(404).json({ error: "Link publico nao encontrado" });
        }
        await db.run("UPDATE task_public_links SET revoked_at = ? WHERE id = ?", [
          nowIso(),
          link.id
        ]);
        res.json({ ok: true });
      } catch (error) {
        res.status(500).json({ error: "Falha ao revogar link publico" });
      }
    }
  );

  app.get("/api/tasks/:id/pdf/status", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const status = await getTaskPdfCacheStatus(db, req.params.id);
      if (!status) {
        return res.status(404).json({ error: "Tarefa nao encontrada" });
      }
      res.json(status);
    } catch (error) {
      res.status(500).json({ error: "Falha ao verificar status do PDF" });
    }
  });

  app.post("/api/tasks/:id/pdf/warm", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const status = await getTaskPdfCacheStatus(db, req.params.id);
      if (!status) {
        return res.status(404).json({ error: "Tarefa nao encontrada" });
      }
      setImmediate(() => {
        warmTaskPdfCache(db, req.params.id, true).catch(() => {});
      });
      res.json({ ...status, warming: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao iniciar aquecimento do PDF" });
    }
  });

  app.get("/api/tasks/:id/pdf", requirePermission(PERMISSIONS.VIEW_TASKS), async (req, res) => {
    try {
      const data = await fetchTaskPdfData(db, req.params.id);
      if (!data) {
        return res.status(404).json({ error: "Tarefa não encontrada" });
      }
      const logoUrl = getLogoDataUrl();
      const forceRefresh = req.query.nocache === "1" || req.query.refresh === "1";
      const cacheHash = computeTaskPdfHash(data, logoUrl);
      const { buildTaskPdfHtml } = await loadPdfHelpers();
      const pdf = await getCachedPdf({
        type: "tasks",
        id: req.params.id,
        hash: cacheHash,
        forceRefresh,
        render: async () => {
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
            logoUrl
          });
          return renderPdfFromHtml(html);
        }
      });
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
      scheduleWarmTaskPdfCache(db, report?.task_id);
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
      scheduleWarmTaskPdfCache(db, report?.task_id);
      res.json(parseJsonFields(report, ["content"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar relatório" });
    }
  });

  app.delete("/api/reports/:id", requirePermission(PERMISSIONS.MANAGE_TASKS), async (req, res) => {
    try {
      const existing = await db.get("SELECT task_id FROM reports WHERE id = ?", [req.params.id]);
      await db.run("DELETE FROM reports WHERE id = ?", [req.params.id]);
      scheduleWarmTaskPdfCache(db, existing?.task_id);
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
        return res.json(parseJsonList(rows, ["signature_pages"]));
      }

      parseJsonList(rows, ["signature_pages"]);
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
      const budget = parseJsonFields(
        await db.get(
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
        ),
        ["signature_pages"]
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

  app.get("/api/budgets/:id/pdf/status", requirePermission(PERMISSIONS.VIEW_BUDGETS), async (req, res) => {
    try {
      const status = await getBudgetPdfCacheStatus(db, req.params.id);
      if (!status) {
        return res.status(404).json({ error: "Orcamento nao encontrado" });
      }
      res.json(status);
    } catch (error) {
      res.status(500).json({ error: "Falha ao verificar status do PDF" });
    }
  });

  app.post("/api/budgets/:id/pdf/warm", requirePermission(PERMISSIONS.VIEW_BUDGETS), async (req, res) => {
    try {
      const status = await getBudgetPdfCacheStatus(db, req.params.id);
      if (!status) {
        return res.status(404).json({ error: "Orcamento nao encontrado" });
      }
      setImmediate(() => {
        warmBudgetPdfCache(db, req.params.id, true).catch(() => {});
        if (status.taskId) {
          warmTaskPdfCache(db, status.taskId, true).catch(() => {});
        }
      });
      res.json({ ...status, warming: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao iniciar aquecimento do PDF" });
    }
  });

  app.get("/api/budgets/:id/pdf", requirePermission(PERMISSIONS.VIEW_BUDGETS), async (req, res) => {
    try {
      const data = await fetchBudgetPdfData(db, req.params.id);
      if (!data) {
        return res.status(404).json({ error: "Orçamento não encontrado" });
      }
      const logoUrl = getLogoDataUrl();
      const forceRefresh = req.query.nocache === "1" || req.query.refresh === "1";
      const cacheHash = computeBudgetPdfHash(data, logoUrl);
      const { buildBudgetPdfHtml } = await loadPdfHelpers();
      const pdf = await getCachedPdf({
        type: "budgets",
        id: req.params.id,
        hash: cacheHash,
        forceRefresh,
        render: async () => {
          const html = buildBudgetPdfHtml({
            budget: data.budget,
            client: data.client,
            signatureMode: data.budget?.signature_mode,
            signatureScope: data.budget?.signature_scope,
            signatureClient: data.budget?.signature_client,
            signatureTech: data.budget?.signature_tech,
            signaturePages: data.budget?.signature_pages || {},
            logoUrl
          });
          return renderPdfFromHtml(html);
        }
      });
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
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_client_name",
        "signature_client_document",
        "signature_tech",
        "signature_pages",
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
      const data = buildPayload(payload, fields, ["signature_pages"]);
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
      scheduleWarmBudgetPdfCache(db, budget?.id);
      scheduleWarmTaskPdfCache(db, budget?.task_id);
      res.status(201).json(parseJsonFields(budget, ["signature_pages"]));
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
        "signature_mode",
        "signature_scope",
        "signature_client",
        "signature_client_name",
        "signature_client_document",
        "signature_tech",
        "signature_pages",
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
      const data = buildPayload(payload, fields, ["signature_pages"]);
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
      scheduleWarmBudgetPdfCache(db, budget?.id);
      scheduleWarmTaskPdfCache(db, budget?.task_id);
      res.json(parseJsonFields(budget, ["signature_pages"]));
    } catch (error) {
      res.status(500).json({ error: "Falha ao atualizar orçamento" });
    }
  });

  app.delete("/api/budgets/:id", requirePermission(PERMISSIONS.MANAGE_BUDGETS), async (req, res) => {
    try {
      const existing = await db.get("SELECT task_id FROM budgets WHERE id = ?", [req.params.id]);
      await db.run("DELETE FROM budgets WHERE id = ?", [req.params.id]);
      scheduleWarmTaskPdfCache(db, existing?.task_id);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover orçamento" });
    }
  });

  app.get("/public/tasks/:id", async (req, res) => {
    try {
      const token = String(req.query.token || "");
      if (!token) {
        return res.status(401).send("Token publico ausente.");
      }
      const link = await findValidPublicLink(db, req.params.id, token);
      if (!link) {
        return res.status(403).send("Link publico invalido ou expirado.");
      }
      const data = await fetchTaskPdfData(db, req.params.id);
      if (!data) {
        return res.status(404).send("Tarefa nao encontrada.");
      }
      const logoUrl = getLogoDataUrl();
      const { buildTaskPdfHtml } = await loadPdfHelpers();
      const baseHtml = buildTaskPdfHtml({
        task: data.task,
        client: data.client,
        reports: data.reports,
        budgets: data.budgets,
        signatureMode: data.task.signature_mode,
        signatureScope: data.task.signature_scope,
        signatureClient: data.task.signature_client,
        signatureTech: data.task.signature_tech,
        signaturePages: data.task.signature_pages || {},
        logoUrl
      });

      const baseUrl = getPublicBaseUrl(req);
      const encodedToken = encodeURIComponent(token);
      const refreshUrl = `${baseUrl}/public/tasks/${req.params.id}?token=${encodedToken}`;
      const pdfUrl = `${baseUrl}/public/tasks/${req.params.id}/pdf?token=${encodedToken}`;
      const html = injectPublicToolbar(baseHtml, {
        taskId: req.params.id,
        title: `Relatorio da tarefa #${req.params.id}`,
        token,
        pdfUrl,
        refreshUrl,
        approveReport: { taskId: req.params.id }
      });

      res.setHeader("Content-Type", "text/html; charset=utf-8");
      res.setHeader("Cache-Control", "no-store");
      res.send(html);
    } catch (error) {
      res.status(500).send("Falha ao carregar relatorio publico.");
    }
  });

  app.post("/public/tasks/:id/approve", async (req, res) => {
    try {
      const token = String(req.query.token || req.body?.token || "");
      if (!token) {
        return res.status(401).send("Token publico ausente.");
      }
      const link = await findValidPublicLink(db, req.params.id, token);
      if (!link) {
        return res.status(403).send("Link publico invalido ou expirado.");
      }
      const signature = req.body?.signature || "";
      if (!signature || !String(signature).startsWith("data:image")) {
        return res.status(400).send("Assinatura invalida.");
      }
      const name = req.body?.name ? String(req.body.name).trim() : "";
      const documentValue = req.body?.document ? String(req.body.document).trim() : "";
      const task = await db.get("SELECT signature_mode, signature_scope FROM tasks WHERE id = ?", [
        req.params.id
      ]);
      let nextMode = task?.signature_mode || "client";
      if (nextMode === "none") nextMode = "client";
      if (nextMode === "tech") nextMode = "both";
      const nextScope = task?.signature_scope || "last_page";
      await db.run(
        `
        UPDATE tasks
        SET signature_client = ?,
            signature_client_name = ?,
            signature_client_document = ?,
            signature_mode = ?,
            signature_scope = ?
        WHERE id = ?
      `,
        [
          signature,
          name || null,
          documentValue || null,
          nextMode,
          nextScope,
          req.params.id
        ]
      );
      scheduleWarmTaskPdfCache(db, req.params.id);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).send("Falha ao assinar o relatorio.");
    }
  });

  app.get("/public/budgets/:id", async (req, res) => {
    try {
      const token = String(req.query.token || "");
      if (!token) {
        return res.status(401).send("Token publico ausente.");
      }
      const link = await findValidBudgetPublicLink(db, req.params.id, token);
      if (!link) {
        return res.status(403).send("Link publico invalido ou expirado.");
      }
      const data = await fetchBudgetPdfData(db, req.params.id);
      if (!data) {
        return res.status(404).send("Orcamento nao encontrado.");
      }
      const logoUrl = getLogoDataUrl();
      const { buildBudgetPdfHtml } = await loadPdfHelpers();
      const baseHtml = buildBudgetPdfHtml({
        budget: data.budget,
        client: data.client,
        signatureMode: data.budget?.signature_mode,
        signatureScope: data.budget?.signature_scope,
        signatureClient: data.budget?.signature_client,
        signatureTech: data.budget?.signature_tech,
        signaturePages: data.budget?.signature_pages || {},
        logoUrl
      });

      const baseUrl = getPublicBaseUrl(req);
      const encodedToken = encodeURIComponent(token);
      const refreshUrl = `${baseUrl}/public/budgets/${req.params.id}?token=${encodedToken}`;
      const html = injectPublicToolbar(baseHtml, {
        taskId: `orcamento-${req.params.id}`,
        title: `Orcamento #${req.params.id}`,
        token,
        pdfUrl: "",
        refreshUrl,
        approveBudget: { budgetId: req.params.id },
        statusLabel: data.budget?.status
      });

      res.setHeader("Content-Type", "text/html; charset=utf-8");
      res.setHeader("Cache-Control", "no-store");
      res.send(html);
    } catch (error) {
      res.status(500).send("Falha ao carregar orcamento publico.");
    }
  });

  app.post("/public/budgets/:id/approve", async (req, res) => {
    try {
      const token = String(req.query.token || req.body?.token || "");
      if (!token) {
        return res.status(401).send("Token publico ausente.");
      }
      const link = await findValidBudgetPublicLink(db, req.params.id, token);
      if (!link) {
        return res.status(403).send("Link publico invalido ou expirado.");
      }
      const signature = req.body?.signature || "";
      if (!signature || !String(signature).startsWith("data:image")) {
        return res.status(400).send("Assinatura invalida.");
      }
      const name = req.body?.name ? String(req.body.name).trim() : "";
      const documentValue = req.body?.document ? String(req.body.document).trim() : "";
      const budget = await db.get(
        "SELECT signature_mode, signature_scope, task_id FROM budgets WHERE id = ?",
        [req.params.id]
      );
      let nextMode = budget?.signature_mode || "client";
      if (nextMode === "none") nextMode = "client";
      if (nextMode === "tech") nextMode = "both";
      const nextScope = budget?.signature_scope || "last_page";
      await db.run(
        `
        UPDATE budgets
        SET signature_client = ?,
            signature_client_name = ?,
            signature_client_document = ?,
            signature_mode = ?,
            signature_scope = ?,
            status = 'aprovado'
        WHERE id = ?
      `,
        [
          signature,
          name || null,
          documentValue || null,
          nextMode,
          nextScope,
          req.params.id
        ]
      );
      scheduleWarmBudgetPdfCache(db, req.params.id);
      scheduleWarmTaskPdfCache(db, budget?.task_id);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).send("Falha ao aprovar o orcamento.");
    }
  });

  app.get("/public/tasks/:id/pdf", async (req, res) => {
    try {
      const token = String(req.query.token || "");
      if (!token) {
        return res.status(401).send("Token publico ausente.");
      }
      const link = await findValidPublicLink(db, req.params.id, token);
      if (!link) {
        return res.status(403).send("Link publico invalido ou expirado.");
      }
      const data = await fetchTaskPdfData(db, req.params.id);
      if (!data) {
        return res.status(404).send("Tarefa nao encontrada.");
      }
      const logoUrl = getLogoDataUrl();
      const forceRefresh = req.query.nocache === "1" || req.query.refresh === "1";
      const cacheHash = computeTaskPdfHash(data, logoUrl);
      const { buildTaskPdfHtml } = await loadPdfHelpers();
      const pdf = await getCachedPdf({
        type: "tasks",
        id: req.params.id,
        hash: cacheHash,
        forceRefresh,
        render: async () => {
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
            logoUrl
          });
          return renderPdfFromHtml(html);
        }
      });
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `inline; filename=\"tarefa_${req.params.id}.pdf\"`);
      res.send(pdf);
    } catch (error) {
      res.status(500).send("Falha ao gerar PDF publico.");
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



