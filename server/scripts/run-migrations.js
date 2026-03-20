const { initDb } = require("../db");

async function main() {
  await initDb();
  console.log("Migrações aplicadas com sucesso.");
}

main().catch((error) => {
  console.error("Falha ao aplicar migrações.", error);
  process.exit(1);
});
