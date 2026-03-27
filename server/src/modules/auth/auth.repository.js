const { normalizeId } = require("../../core/utils/validation");

const USER_SELECT = `SELECT users.*,
                            roles.name AS role_name,
                            roles.permissions AS role_permissions,
                            roles.is_admin AS role_is_admin
                     FROM users
                     LEFT JOIN roles ON roles.key = users.role`;

async function findAuthUserByEmail(db, email) {
  return db.get(`${USER_SELECT} WHERE lower(users.email) = lower(?)`, [email]);
}

async function findAuthUserById(db, userId) {
  return db.get(`${USER_SELECT} WHERE users.id = ?`, [normalizeId(userId)]);
}

async function createPendingUser(db, payload) {
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

  return findAuthUserById(db, result.lastID);
}

async function markUserEmailVerified(db, userId, payload) {
  await db.run(
    `UPDATE users
     SET email_verified = ?, email_verified_at = ?, status = ?
     WHERE id = ?`,
    [1, payload.email_verified_at, payload.status, normalizeId(userId)]
  );
  return findAuthUserById(db, userId);
}

async function touchUserLogin(db, userId, loggedAt) {
  await db.run("UPDATE users SET last_login_at = ? WHERE id = ?", [
    loggedAt,
    normalizeId(userId)
  ]);
}

async function updateUserPassword(db, userId, payload) {
  await db.run(
    `UPDATE users
     SET password_hash = ?, password_changed_at = ?
     WHERE id = ?`,
    [payload.password_hash, payload.password_changed_at, normalizeId(userId)]
  );
  return findAuthUserById(db, userId);
}

async function invalidateAuthCodes(db, userId, purpose, consumedAt) {
  await db.run(
    `UPDATE auth_codes
     SET consumed_at = ?
     WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL`,
    [consumedAt, normalizeId(userId), purpose]
  );
}

async function createAuthCode(db, payload) {
  const fields = [
    "user_id",
    "purpose",
    "code_hash",
    "expires_at",
    "consumed_at",
    "created_at",
    "last_sent_at",
    "resend_count",
    "attempt_count"
  ];
  const result = await db.run(
    `INSERT INTO auth_codes (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
    fields.map((field) => payload[field] ?? null)
  );
  return findAuthCodeById(db, result.lastID);
}

async function findAuthCodeById(db, id) {
  return db.get("SELECT * FROM auth_codes WHERE id = ?", [normalizeId(id)]);
}

async function findLatestActiveAuthCode(db, userId, purpose) {
  return db.get(
    `SELECT *
     FROM auth_codes
     WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL
     ORDER BY created_at DESC, id DESC
     LIMIT 1`,
    [normalizeId(userId), purpose]
  );
}

async function incrementAuthCodeAttempt(db, id, attemptCount) {
  await db.run("UPDATE auth_codes SET attempt_count = ? WHERE id = ?", [
    attemptCount,
    normalizeId(id)
  ]);
}

async function consumeAuthCode(db, id, consumedAt) {
  await db.run("UPDATE auth_codes SET consumed_at = ? WHERE id = ?", [
    consumedAt,
    normalizeId(id)
  ]);
}

async function createSession(db, payload) {
  const fields = [
    "user_id",
    "token_hash",
    "created_at",
    "expires_at",
    "revoked_at",
    "last_used_at",
    "device_info",
    "ip_address",
    "platform"
  ];
  const result = await db.run(
    `INSERT INTO auth_sessions (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
    fields.map((field) => payload[field] ?? null)
  );
  return findSessionById(db, result.lastID);
}

async function findSessionById(db, sessionId) {
  return db.get("SELECT * FROM auth_sessions WHERE id = ?", [normalizeId(sessionId)]);
}

async function listUserSessions(db, userId) {
  return db.all(
    `SELECT id,
            user_id,
            created_at,
            expires_at,
            revoked_at,
            last_used_at,
            device_info,
            ip_address,
            platform
     FROM auth_sessions
     WHERE user_id = ?
     ORDER BY COALESCE(last_used_at, created_at) DESC, id DESC`,
    [normalizeId(userId)]
  );
}

async function findSessionByTokenHash(db, tokenHash) {
  return db.get(
    "SELECT * FROM auth_sessions WHERE token_hash = ? ORDER BY id DESC LIMIT 1",
    [tokenHash]
  );
}

async function rotateSessionToken(db, sessionId, payload) {
  await db.run(
    `UPDATE auth_sessions
     SET token_hash = ?, expires_at = ?, last_used_at = ?, revoked_at = NULL, device_info = ?, ip_address = ?, platform = ?
     WHERE id = ?`,
    [
      payload.token_hash,
      payload.expires_at,
      payload.last_used_at,
      payload.device_info,
      payload.ip_address,
      payload.platform,
      normalizeId(sessionId)
    ]
  );
  return findSessionById(db, sessionId);
}

async function revokeSession(db, sessionId, revokedAt) {
  await db.run("UPDATE auth_sessions SET revoked_at = ? WHERE id = ?", [
    revokedAt,
    normalizeId(sessionId)
  ]);
}

async function revokeUserSessions(db, userId, revokedAt, exceptSessionId = null) {
  const params = [revokedAt, normalizeId(userId)];
  let sql = "UPDATE auth_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL";
  if (exceptSessionId) {
    sql += " AND id <> ?";
    params.push(normalizeId(exceptSessionId));
  }
  await db.run(sql, params);
}

async function touchSession(db, sessionId, lastUsedAt) {
  await touchSessionActivity(db, sessionId, {
    last_used_at: lastUsedAt
  });
}

async function touchSessionActivity(db, sessionId, payload) {
  await db.run(
    `UPDATE auth_sessions
     SET last_used_at = ?,
         device_info = COALESCE(?, device_info),
         ip_address = COALESCE(?, ip_address),
         platform = COALESCE(?, platform)
     WHERE id = ?`,
    [
      payload.last_used_at ?? null,
      payload.device_info ?? null,
      payload.ip_address ?? null,
      payload.platform ?? null,
      normalizeId(sessionId)
    ]
  );
}

async function findRateLimit(db, actionKey, scopeKey) {
  return db.get(
    `SELECT *
     FROM auth_rate_limits
     WHERE action_key = ? AND scope_key = ?`,
    [actionKey, scopeKey]
  );
}

async function saveRateLimit(db, payload) {
  const existing = await findRateLimit(db, payload.action_key, payload.scope_key);
  if (!existing) {
    const fields = [
      "action_key",
      "scope_key",
      "attempts",
      "window_started_at",
      "blocked_until",
      "created_at",
      "updated_at"
    ];
    await db.run(
      `INSERT INTO auth_rate_limits (${fields.join(", ")}) VALUES (${fields.map(() => "?").join(", ")})`,
      fields.map((field) => payload[field] ?? null)
    );
    return findRateLimit(db, payload.action_key, payload.scope_key);
  }

  await db.run(
    `UPDATE auth_rate_limits
     SET attempts = ?, window_started_at = ?, blocked_until = ?, updated_at = ?
     WHERE action_key = ? AND scope_key = ?`,
    [
      payload.attempts,
      payload.window_started_at,
      payload.blocked_until,
      payload.updated_at,
      payload.action_key,
      payload.scope_key
    ]
  );
  return findRateLimit(db, payload.action_key, payload.scope_key);
}

async function clearRateLimit(db, actionKey, scopeKey) {
  await db.run(
    "DELETE FROM auth_rate_limits WHERE action_key = ? AND scope_key = ?",
    [actionKey, scopeKey]
  );
}

module.exports = {
  clearRateLimit,
  consumeAuthCode,
  createAuthCode,
  createPendingUser,
  createSession,
  findAuthCodeById,
  findAuthUserByEmail,
  findAuthUserById,
  findLatestActiveAuthCode,
  findRateLimit,
  findSessionById,
  findSessionByTokenHash,
  listUserSessions,
  incrementAuthCodeAttempt,
  invalidateAuthCodes,
  markUserEmailVerified,
  revokeSession,
  revokeUserSessions,
  rotateSessionToken,
  saveRateLimit,
  touchSession,
  touchSessionActivity,
  touchUserLogin,
  updateUserPassword
};
