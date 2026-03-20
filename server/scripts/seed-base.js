const { initDb } = require("../db");
const { getEnv } = require("../src/config/env");
const { ensureAdminUser, ensureDefaultRoles } = require("../src/app/bootstrap-data");

async function main() {
  const db = await initDb();
  const env = getEnv();

  await ensureDefaultRoles(db);
  await ensureAdminUser(db, env);

  console.log("Seed base concluído com sucesso.");
}

main().catch((error) => {
  console.error("Falha ao executar seed base.", error);
  process.exit(1);
});
