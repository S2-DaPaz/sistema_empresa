async function findUserWithRoleById(db, userId) {
  return db.get(
    `SELECT users.id,
            users.name,
            users.email,
            users.role,
            users.permissions,
            users.status,
            users.email_verified,
            users.email_verified_at,
            users.last_login_at,
            users.password_changed_at,
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
            users.status,
            users.email_verified,
            users.email_verified_at,
            users.last_login_at,
            users.password_changed_at,
            roles.name AS role_name,
            roles.permissions AS role_permissions,
            roles.is_admin AS role_is_admin
     FROM users
     LEFT JOIN roles ON roles.key = users.role
     ORDER BY users.id DESC`
  );
}

async function createUser(db, payload) {
  const fields = [
    "name",
    "email",
    "role",
    "password_hash",
    "permissions",
    "status",
    "email_verified",
    "email_verified_at",
    "last_login_at",
    "password_changed_at"
  ];
  const result = await db.run(
    `INSERT INTO users (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
    fields.map((field) => {
      if (field === "permissions") {
        return JSON.stringify(payload.permissions || []);
      }
      if (field === "email_verified") {
        return payload.email_verified ? 1 : 0;
      }
      return payload[field] ?? null;
    })
  );

  return findUserWithRoleById(db, result.lastID);
}

async function updateUser(db, id, payload) {
  const fields = [
    "name",
    "email",
    "role",
    "permissions",
    "status",
    "email_verified",
    "email_verified_at",
    "last_login_at",
    "password_changed_at"
  ];
  const values = [
    payload.name,
    payload.email,
    payload.role,
    JSON.stringify(payload.permissions || []),
    payload.status ?? null,
    payload.email_verified ? 1 : 0,
    payload.email_verified_at ?? null,
    payload.last_login_at ?? null,
    payload.password_changed_at ?? null,
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
