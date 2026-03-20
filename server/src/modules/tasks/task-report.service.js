const { safeJsonParse } = require("../../core/utils/json");

async function createReportForTask(db, task) {
  if (!task || !task.id || !task.task_type_id) return null;

  const existing = await db.get(
    "SELECT id FROM reports WHERE task_id = ? AND equipment_id IS NULL ORDER BY id DESC LIMIT 1",
    [task.id]
  );
  if (existing) return existing;

  const typeRow = await db.get("SELECT report_template_id FROM task_types WHERE id = ?", [
    task.task_type_id
  ]);
  if (!typeRow?.report_template_id) return null;

  const template = await db.get("SELECT structure FROM report_templates WHERE id = ?", [
    typeRow.report_template_id
  ]);
  const structure = safeJsonParse(template?.structure) || { sections: [] };
  const content = JSON.stringify({
    sections: structure.sections || [],
    answers: {},
    photos: []
  });

  const result = await db.run(
    `INSERT INTO reports (title, task_id, client_id, template_id, equipment_id, content, status, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      task.title || "Relatorio",
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
    return null;
  }

  const typeRow = task.task_type_id
    ? await db.get("SELECT report_template_id FROM task_types WHERE id = ?", [task.task_type_id])
    : null;
  const parsedContent = safeJsonParse(report.content) || {};
  const hasSections = Array.isArray(parsedContent.sections) && parsedContent.sections.length > 0;

  let nextTemplateId = report.template_id;
  let nextContent = report.content;

  if (!hasSections && typeRow?.report_template_id) {
    const template = await db.get("SELECT structure FROM report_templates WHERE id = ?", [
      typeRow.report_template_id
    ]);
    const structure = safeJsonParse(template?.structure) || { sections: [] };
    nextTemplateId = typeRow.report_template_id;
    nextContent = JSON.stringify({
      sections: structure.sections || [],
      answers: {},
      photos: []
    });
  }

  await db.run(
    `UPDATE reports
     SET title = ?, client_id = ?, template_id = ?, content = ?
     WHERE id = ?`,
    [task.title || report.title, task.client_id || null, nextTemplateId, nextContent, report.id]
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

  const typeRow = await db.get("SELECT report_template_id FROM task_types WHERE id = ?", [
    task.task_type_id
  ]);
  if (!typeRow?.report_template_id) return null;

  const template = await db.get("SELECT structure FROM report_templates WHERE id = ?", [
    typeRow.report_template_id
  ]);
  const structure = safeJsonParse(template?.structure) || { sections: [] };
  const content = JSON.stringify({
    sections: structure.sections || [],
    answers: {},
    photos: []
  });

  const result = await db.run(
    `INSERT INTO reports (title, task_id, client_id, template_id, equipment_id, content, status, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      equipment.name ? `Relatorio - ${equipment.name}` : "Relatorio - Equipamento",
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

module.exports = {
  createReportForTask,
  syncReportForTask,
  createReportForEquipment
};
