async function listRoles(db) {
  return db.all("SELECT id, key, name, permissions, is_admin FROM roles ORDER BY name ASC");
}

async function findRoleById(db, roleId) {
  return db.get("SELECT id, key, name, permissions, is_admin FROM roles WHERE id = ?", [roleId]);
}

async function findRoleByKey(db, roleKey) {
  return db.get("SELECT id, key, name, permissions, is_admin FROM roles WHERE key = ?", [roleKey]);
}

async function createRole(db, payload) {
  const result = await db.run(
    "INSERT INTO roles (key, name, permissions, is_admin) VALUES (?, ?, ?, ?)",
    [
      payload.key,
      payload.name,
      JSON.stringify(payload.permissions || []),
      payload.is_admin ? 1 : 0
    ]
  );

  return findRoleById(db, result.lastID);
}

async function updateRole(db, roleId, payload) {
  await db.run(
    "UPDATE roles SET name = ?, permissions = ?, is_admin = ? WHERE id = ?",
    [
      payload.name,
      JSON.stringify(payload.permissions || []),
      payload.is_admin ? 1 : 0,
      roleId
    ]
  );

  return findRoleById(db, roleId);
}

async function deleteRole(db, roleId) {
  return db.run("DELETE FROM roles WHERE id = ?", [roleId]);
}

module.exports = {
  listRoles,
  findRoleById,
  findRoleByKey,
  createRole,
  updateRole,
  deleteRole
};
