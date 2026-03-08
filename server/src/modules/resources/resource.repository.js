async function listRows(db, table, orderBy) {
  return db.all(`SELECT * FROM ${table} ORDER BY ${orderBy}`);
}

async function findRowById(db, table, id) {
  return db.get(`SELECT * FROM ${table} WHERE id = ?`, [id]);
}

async function createRow(db, table, fields, data) {
  const sql = `INSERT INTO ${table} (${fields.join(", ")}) VALUES (${fields
    .map(() => "?")
    .join(", ")})`;
  const result = await db.run(sql, fields.map((field) => data[field]));
  return findRowById(db, table, result.lastID);
}

async function updateRow(db, table, id, fields, data) {
  const sql = `UPDATE ${table} SET ${fields.map((field) => `${field} = ?`).join(", ")} WHERE id = ?`;
  await db.run(sql, [...fields.map((field) => data[field]), id]);
  return findRowById(db, table, id);
}

async function deleteRow(db, table, id) {
  return db.run(`DELETE FROM ${table} WHERE id = ?`, [id]);
}

module.exports = {
  listRows,
  findRowById,
  createRow,
  updateRow,
  deleteRow
};
