const { parseJsonFields, parseJsonList } = require("../../core/utils/json");
const { normalizeId } = require("../../core/utils/validation");

const ERROR_LOG_JSON_FIELDS = ["context_json", "payload_json"];
const EVENT_LOG_JSON_FIELDS = ["metadata_json", "before_json", "after_json"];

function serializeJson(value) {
  if (value === undefined || value === null) return null;
  return JSON.stringify(value);
}

function buildPagination(query = {}) {
  const page = Math.max(Number(query.page) || 1, 1);
  const pageSize = Math.min(Math.max(Number(query.pageSize) || 20, 1), 100);
  const offset = (page - 1) * pageSize;
  const sort = String(query.sort || "desc").toLowerCase() === "asc" ? "ASC" : "DESC";
  return { page, pageSize, offset, sort };
}

function buildDateFilters(filters, params, column, dateFrom, dateTo) {
  if (dateFrom) {
    filters.push(`${column} >= ?`);
    params.push(dateFrom);
  }
  if (dateTo) {
    filters.push(`${column} <= ?`);
    params.push(dateTo);
  }
}

function buildTextSearch(filters, params, search, columns) {
  const normalized = String(search || "").trim().toLowerCase();
  if (!normalized) return;
  const term = `%${normalized}%`;
  filters.push(
    `(${columns.map((column) => `LOWER(COALESCE(${column}, '')) LIKE ?`).join(" OR ")})`
  );
  columns.forEach(() => params.push(term));
}

async function insertErrorLog(db, payload) {
  const fields = [
    "created_at",
    "severity",
    "category",
    "error_code",
    "friendly_message",
    "technical_message",
    "stack_trace",
    "http_status",
    "http_method",
    "endpoint",
    "module",
    "platform",
    "screen_route",
    "operation",
    "request_id",
    "environment",
    "user_id",
    "user_name",
    "user_email",
    "context_json",
    "payload_json",
    "resolved_at",
    "resolved_by_user_id",
    "resolution_note"
  ];

  const result = await db.run(
    `INSERT INTO error_logs (${fields.join(", ")})
     VALUES (${fields.map(() => "?").join(", ")})`,
    fields.map((field) => {
      if (field === "context_json") return serializeJson(payload.context_json);
      if (field === "payload_json") return serializeJson(payload.payload_json);
      return payload[field] ?? null;
    })
  );

  return findErrorLogById(db, result.lastID);
}

async function insertEventLog(db, payload) {
  const fields = [
    "created_at",
    "action",
    "description",
    "module",
    "entity_type",
    "entity_id",
    "outcome",
    "platform",
    "ip_address",
    "route_path",
    "http_method",
    "request_id",
    "user_id",
    "user_name",
    "user_email",
    "user_role",
    "metadata_json",
    "before_json",
    "after_json"
  ];

  const result = await db.run(
    `INSERT INTO event_logs (${fields.join(", ")})
     VALUES (${fields.map(() => "?").join(", ")})`,
    fields.map((field) => {
      if (field === "metadata_json") return serializeJson(payload.metadata_json);
      if (field === "before_json") return serializeJson(payload.before_json);
      if (field === "after_json") return serializeJson(payload.after_json);
      return payload[field] ?? null;
    })
  );

  return findEventLogById(db, result.lastID);
}

async function listErrorLogs(db, query = {}) {
  const { page, pageSize, offset, sort } = buildPagination(query);
  const filters = [];
  const params = [];

  if (query.userId) {
    filters.push("user_id = ?");
    params.push(normalizeId(query.userId, "userId"));
  }
  if (query.severity) {
    filters.push("severity = ?");
    params.push(String(query.severity).toLowerCase());
  }
  if (query.module) {
    filters.push("module = ?");
    params.push(String(query.module).toLowerCase());
  }
  if (query.platform) {
    filters.push("platform = ?");
    params.push(String(query.platform).toLowerCase());
  }
  if (query.resolved === "true") {
    filters.push("resolved_at IS NOT NULL");
  } else if (query.resolved === "false") {
    filters.push("resolved_at IS NULL");
  }

  buildDateFilters(filters, params, "created_at", query.dateFrom, query.dateTo);
  buildTextSearch(filters, params, query.search, [
    "friendly_message",
    "technical_message",
    "endpoint",
    "module",
    "platform",
    "user_name",
    "user_email"
  ]);

  const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
  const countRow = await db.get(`SELECT COUNT(*) AS total FROM error_logs ${where}`, params);
  const rows = await db.all(
    `SELECT *
     FROM error_logs
     ${where}
     ORDER BY created_at ${sort}, id ${sort}
     LIMIT ? OFFSET ?`,
    [...params, pageSize, offset]
  );

  return {
    items: parseJsonList(rows, ERROR_LOG_JSON_FIELDS),
    total: Number(countRow?.total || 0),
    page,
    pageSize
  };
}

async function listEventLogs(db, query = {}) {
  const { page, pageSize, offset, sort } = buildPagination(query);
  const filters = [];
  const params = [];

  if (query.userId) {
    filters.push("user_id = ?");
    params.push(normalizeId(query.userId, "userId"));
  }
  if (query.module) {
    filters.push("module = ?");
    params.push(String(query.module).toLowerCase());
  }
  if (query.platform) {
    filters.push("platform = ?");
    params.push(String(query.platform).toLowerCase());
  }
  if (query.outcome) {
    filters.push("outcome = ?");
    params.push(String(query.outcome).toLowerCase());
  }
  if (query.action) {
    filters.push("action = ?");
    params.push(String(query.action).toUpperCase());
  }

  buildDateFilters(filters, params, "created_at", query.dateFrom, query.dateTo);
  buildTextSearch(filters, params, query.search, [
    "action",
    "description",
    "module",
    "entity_type",
    "entity_id",
    "user_name",
    "user_email"
  ]);

  const where = filters.length ? `WHERE ${filters.join(" AND ")}` : "";
  const countRow = await db.get(`SELECT COUNT(*) AS total FROM event_logs ${where}`, params);
  const rows = await db.all(
    `SELECT *
     FROM event_logs
     ${where}
     ORDER BY created_at ${sort}, id ${sort}
     LIMIT ? OFFSET ?`,
    [...params, pageSize, offset]
  );

  return {
    items: parseJsonList(rows, EVENT_LOG_JSON_FIELDS),
    total: Number(countRow?.total || 0),
    page,
    pageSize
  };
}

async function findErrorLogById(db, id) {
  const row = await db.get("SELECT * FROM error_logs WHERE id = ?", [normalizeId(id)]);
  return parseJsonFields(row, ERROR_LOG_JSON_FIELDS);
}

async function findEventLogById(db, id) {
  const row = await db.get("SELECT * FROM event_logs WHERE id = ?", [normalizeId(id)]);
  return parseJsonFields(row, EVENT_LOG_JSON_FIELDS);
}

async function resolveErrorLog(db, id, payload) {
  await db.run(
    `UPDATE error_logs
     SET resolved_at = ?, resolved_by_user_id = ?, resolution_note = ?
     WHERE id = ?`,
    [payload.resolved_at, payload.resolved_by_user_id, payload.resolution_note || null, normalizeId(id)]
  );
  return findErrorLogById(db, id);
}

module.exports = {
  insertErrorLog,
  insertEventLog,
  listErrorLogs,
  listEventLogs,
  findErrorLogById,
  findEventLogById,
  resolveErrorLog
};
