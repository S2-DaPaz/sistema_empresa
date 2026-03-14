const { parseJsonFields } = require("../../core/utils/json");
const { buildPayload } = require("../../core/utils/validation");

const SIGNATURE_FIELDS = [
  "signature_mode",
  "signature_scope",
  "signature_client",
  "signature_tech",
  "signature_pages"
];

async function updateTaskSignatures(db, taskId, body) {
  const payload = buildPayload(body, SIGNATURE_FIELDS, ["signature_pages"]);
  await db.run(
    `UPDATE tasks
     SET ${SIGNATURE_FIELDS.map((field) => `${field} = ?`).join(", ")}
     WHERE id = ?`,
    [...SIGNATURE_FIELDS.map((field) => payload[field]), taskId]
  );

  const task = await db.get("SELECT * FROM tasks WHERE id = ?", [taskId]);
  return parseJsonFields(task, ["signature_pages"]);
}

module.exports = {
  SIGNATURE_FIELDS,
  updateTaskSignatures
};
