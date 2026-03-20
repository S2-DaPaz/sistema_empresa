const test = require("node:test");
const assert = require("node:assert/strict");

const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const {
  createReportForTask,
  syncReportForTask
} = require("../src/modules/tasks/task-report.service");

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });

  await db.exec(`
    CREATE TABLE report_templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      structure TEXT NOT NULL
    );

    CREATE TABLE task_types (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      report_template_id INTEGER
    );

    CREATE TABLE reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      task_id INTEGER,
      client_id INTEGER,
      template_id INTEGER,
      equipment_id INTEGER,
      content TEXT,
      status TEXT,
      created_at TEXT NOT NULL
    );
  `);

  await db.run(
    "INSERT INTO report_templates (name, structure) VALUES (?, ?)",
    [
      "Padrão",
      JSON.stringify({
        sections: [{ id: "summary", title: "Resumo", fields: [] }]
      })
    ]
  );

  await db.run(
    "INSERT INTO task_types (name, report_template_id) VALUES (?, ?)",
    ["Instalação", 1]
  );

  return db;
}

test("createReportForTask creates the initial general report only once", async () => {
  const db = await createDb();
  const task = {
    id: 10,
    title: "Visita técnica",
    client_id: 5,
    task_type_id: 1
  };

  const first = await createReportForTask(db, task);
  const second = await createReportForTask(db, task);
  const count = await db.get(
    "SELECT COUNT(*) AS total FROM reports WHERE task_id = ? AND equipment_id IS NULL",
    [task.id]
  );

  assert.ok(first?.id);
  assert.equal(second.id, first.id);
  assert.equal(count.total, 1);
});

test("syncReportForTask does not recreate a deleted general report during task update", async () => {
  const db = await createDb();
  const task = {
    id: 12,
    title: "Manutenção preventiva",
    client_id: 8,
    task_type_id: 1
  };

  const result = await syncReportForTask(db, task);
  const count = await db.get(
    "SELECT COUNT(*) AS total FROM reports WHERE task_id = ? AND equipment_id IS NULL",
    [task.id]
  );

  assert.equal(result, null);
  assert.equal(count.total, 0);
});

test("syncReportForTask updates the existing general report without duplicating it", async () => {
  const db = await createDb();

  await db.run(
    `INSERT INTO reports (
      title,
      task_id,
      client_id,
      template_id,
      equipment_id,
      content,
      status,
      created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      "Relatório original",
      20,
      2,
      1,
      null,
      JSON.stringify({
        sections: [{ id: "summary", title: "Resumo", fields: [] }],
        answers: { notes: "ok" },
        photos: []
      }),
      "rascunho",
      new Date().toISOString()
    ]
  );

  const synced = await syncReportForTask(db, {
    id: 20,
    title: "Tarefa atualizada",
    client_id: 9,
    task_type_id: 1
  });

  const report = await db.get(
    "SELECT title, client_id, template_id, content FROM reports WHERE task_id = ? AND equipment_id IS NULL",
    [20]
  );
  const count = await db.get(
    "SELECT COUNT(*) AS total FROM reports WHERE task_id = ? AND equipment_id IS NULL",
    [20]
  );

  assert.equal(synced.id, 1);
  assert.equal(report.title, "Tarefa atualizada");
  assert.equal(report.client_id, 9);
  assert.equal(report.template_id, 1);
  assert.equal(count.total, 1);
  assert.match(report.content, /notes/);
});
