const { main } = require("./src/server");

if (require.main === module) {
  main().catch((error) => {
    console.error("Falha ao iniciar o servidor", error);
    process.exit(1);
  });
}

module.exports = { main };
