require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { initDb } = require("./db");

const PORT = process.env.PORT || 3001;

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

function safeJsonParse(value) {
  if (!value || typeof value !== "string") return null;
  try {
    return JSON.parse(value);
  } catch (error) {
    return null;
  }
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
  const { table, fields, jsonFields = [], orderBy = "id DESC" } = config;
  const router = express.Router();

  router.get("/", async (req, res) => {
    try {
      const items = await db.all(`SELECT * FROM ${table} ORDER BY ${orderBy}`);
      res.json(parseJsonList(items, jsonFields));
    } catch (error) {
      res.status(500).json({ error: "Falha ao listar registros" });
    }
  });

  router.get("/:id", async (req, res) => {
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

  router.post("/", async (req, res) => {
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

  router.put("/:id", async (req, res) => {
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

  router.delete("/:id", async (req, res) => {
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
  const app = express();

  app.use(cors());
  app.use(express.json({ limit: "10mb" }));

  app.get("/api/health", (req, res) => {
    res.json({ ok: true });
  });

  app.get("/api/summary", async (req, res) => {
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
      orderBy: "name ASC"
    })
  );

  app.use(
    "/api/users",
    createCrudRoutes(db, {
      table: "users",
      fields: ["name", "email", "role"],
      orderBy: "name ASC"
    })
  );

  app.use(
    "/api/products",
    createCrudRoutes(db, {
      table: "products",
      fields: ["name", "sku", "price", "unit"],
      orderBy: "name ASC"
    })
  );

  app.get("/api/equipments", async (req, res) => {
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

  app.get("/api/equipments/:id", async (req, res) => {
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

  app.post("/api/equipments", async (req, res) => {
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

  app.put("/api/equipments/:id", async (req, res) => {
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

  app.delete("/api/equipments/:id", async (req, res) => {
    try {
      await db.run("DELETE FROM equipments WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover equipamento" });
    }
  });

  app.get("/api/tasks/:id/equipments", async (req, res) => {
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

  app.post("/api/tasks/:id/equipments", async (req, res) => {
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

  app.delete("/api/tasks/:id/equipments/:equipmentId", async (req, res) => {
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
      orderBy: "name ASC"
    })
  );

  app.get("/api/tasks", async (req, res) => {
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

  app.get("/api/tasks/:id", async (req, res) => {
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

  app.post("/api/tasks", async (req, res) => {
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

  app.put("/api/tasks/:id", async (req, res) => {
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

  app.delete("/api/tasks/:id", async (req, res) => {
    try {
      await db.run("DELETE FROM tasks WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover tarefa" });
    }
  });

  app.use(
    "/api/report-templates",
    createCrudRoutes(db, {
      table: "report_templates",
      fields: ["name", "description", "structure"],
      jsonFields: ["structure"],
      orderBy: "name ASC"
    })
  );

  app.get("/api/reports", async (req, res) => {
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

  app.get("/api/reports/:id", async (req, res) => {
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

  app.post("/api/reports", async (req, res) => {
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

  app.put("/api/reports/:id", async (req, res) => {
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

  app.delete("/api/reports/:id", async (req, res) => {
    try {
      await db.run("DELETE FROM reports WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover relatório" });
    }
  });

  app.get("/api/budgets", async (req, res) => {
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

  app.get("/api/budgets/:id", async (req, res) => {
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

  app.post("/api/budgets", async (req, res) => {
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

  app.put("/api/budgets/:id", async (req, res) => {
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

  app.delete("/api/budgets/:id", async (req, res) => {
    try {
      await db.run("DELETE FROM budgets WHERE id = ?", [req.params.id]);
      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ error: "Falha ao remover orçamento" });
    }
  });

  app.listen(PORT, () => {
    console.log(`API rodando em http://localhost:${PORT}`);
  });
}

main().catch((error) => {
  console.error("Falha ao iniciar o servidor", error);
  process.exit(1);
});

