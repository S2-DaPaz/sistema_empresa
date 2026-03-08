function safeJsonParse(value) {
  if (!value || typeof value !== "string") return null;
  try {
    return JSON.parse(value);
  } catch (error) {
    return null;
  }
}

function parseJsonFields(row, jsonFields = []) {
  if (!row) return row;

  const next = { ...row };
  jsonFields.forEach((field) => {
    if (next[field] && typeof next[field] === "string") {
      try {
        next[field] = JSON.parse(next[field]);
      } catch (error) {
        next[field] = null;
      }
    }
  });

  return next;
}

function parseJsonList(rows, jsonFields = []) {
  return rows.map((row) => parseJsonFields(row, jsonFields));
}

module.exports = {
  safeJsonParse,
  parseJsonFields,
  parseJsonList
};
