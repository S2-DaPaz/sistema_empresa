const path = require("path");

require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const bcrypt = require("bcryptjs");
const { initDb } = require("../db");

async function resetAdmin() {
  const name = process.env.ADMIN_NAME || "Administrador";
  const email = process.env.ADMIN_EMAIL || "admin@local";
  const password = process.env.ADMIN_PASSWORD || "admin123";
  const hash = await bcrypt.hash(password, 10);
  const db = await initDb();

  const existing = await db.get("SELECT id FROM users WHERE lower(email) = lower(?)", [email]);
  if (existing) {
    await db.run(
      "UPDATE users SET name = ?, role = ?, password_hash = ? WHERE id = ?",
      [name, "administracao", hash, existing.id]
    );
    console.log(`Admin atualizado: ${email}`);
    return;
  }

  await db.run(
    "INSERT INTO users (name, email, role, password_hash, permissions) VALUES (?, ?, ?, ?, ?)",
    [name, email, "administracao", hash, JSON.stringify([])]
  );
  console.log(`Admin criado: ${email}`);
}

resetAdmin()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Falha ao atualizar admin:", error.message);
    process.exit(1);
  });
