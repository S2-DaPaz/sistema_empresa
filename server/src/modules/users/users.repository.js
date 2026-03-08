async function findUserWithRoleById(db, userId) {
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

async function findUserByEmail(db, email) {
  return db.get("SELECT * FROM users WHERE lower(email) = lower(?)", [email]);
}

async function listUsers(db) {
  return db.all(
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
     ORDER BY users.id DESC`
  );
}

async function createUser(db, payload) {
  const result = await db.run(
    "INSERT INTO users (name, email, role, password_hash, permissions) VALUES (?, ?, ?, ?, ?)",
    [
      payload.name,
      payload.email,
      payload.role,
      payload.password_hash,
      JSON.stringify(payload.permissions || [])
    ]
  );

  return findUserWithRoleById(db, result.lastID);
}

async function updateUser(db, id, payload) {
  const fields = ["name", "email", "role", "permissions"];
  const values = [
    payload.name,
    payload.email,
    payload.role,
    JSON.stringify(payload.permissions || []),
    id
  ];

  await db.run(
    `UPDATE users
     SET ${fields.map((field) => `${field} = ?`).join(", ")}
     WHERE id = ?`,
    values
  );

  if (payload.password_hash) {
    await db.run("UPDATE users SET password_hash = ? WHERE id = ?", [payload.password_hash, id]);
  }

  return findUserWithRoleById(db, id);
}

async function deleteUser(db, id) {
  return db.run("DELETE FROM users WHERE id = ?", [id]);
}

module.exports = {
  findUserWithRoleById,
  findUserByEmail,
  listUsers,
  createUser,
  updateUser,
  deleteUser
};
