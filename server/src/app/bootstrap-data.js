const bcrypt = require("bcryptjs");

const { ALL_PERMISSIONS, ROLE_DEFAULTS } = require("../config/contracts");
const { logger } = require("../core/utils/logger");

async function ensureDefaultRoles(db) {
  const defaults = [
    { key: "administracao", name: "Administracao", permissions: ALL_PERMISSIONS, is_admin: 1 },
    { key: "gestor", name: "Gestor", permissions: ROLE_DEFAULTS.gestor, is_admin: 0 },
    { key: "tecnico", name: "Tecnico", permissions: ROLE_DEFAULTS.tecnico, is_admin: 0 },
    { key: "visitante", name: "Visitante", permissions: ROLE_DEFAULTS.visitante, is_admin: 0 }
  ];

  for (const role of defaults) {
    const existing = await db.get("SELECT id, name, is_admin FROM roles WHERE key = ?", [role.key]);
    if (!existing) {
      await db.run(
        "INSERT INTO roles (key, name, permissions, is_admin) VALUES (?, ?, ?, ?)",
        [role.key, role.name, JSON.stringify(role.permissions || []), role.is_admin ? 1 : 0]
      );
      continue;
    }

    const nextName = existing.name || role.name;
    const nextAdmin = role.is_admin ? 1 : Number(existing.is_admin) ? 1 : 0;
    if (nextName !== existing.name || nextAdmin !== Number(existing.is_admin)) {
      await db.run("UPDATE roles SET name = ?, is_admin = ? WHERE id = ?", [
        nextName,
        nextAdmin,
        existing.id
      ]);
    }
  }
}

async function ensureAdminUser(db, env) {
  if (!env.autoBootstrapAdmin || !env.adminBootstrapPassword) return;

  const existing = await db.get("SELECT id FROM users WHERE lower(email) = lower(?)", [env.adminEmail]);
  if (existing) return;

  const hash = await bcrypt.hash(env.adminBootstrapPassword, 10);
  await db.run(
    `INSERT INTO users (
      name,
      email,
      role,
      password_hash,
      permissions,
      status,
      email_verified,
      email_verified_at,
      password_changed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      env.adminName,
      env.adminEmail,
      "administracao",
      hash,
      JSON.stringify([]),
      "active",
      1,
      new Date().toISOString(),
      new Date().toISOString()
    ]
  );

  logger.warn("bootstrap_admin_created", {
    email: env.adminEmail,
    generatedPassword: process.env.ADMIN_PASSWORD ? undefined : env.adminBootstrapPassword
  });
}

module.exports = { ensureDefaultRoles, ensureAdminUser };
