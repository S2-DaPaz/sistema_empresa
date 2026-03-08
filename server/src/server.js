const { createApp } = require("./app/create-app");
const { ensureAdminUser, ensureDefaultRoles } = require("./app/bootstrap-data");
const { getEnv } = require("./config/env");
const { initDb } = require("./infrastructure/database");
const { createPublicService } = require("./modules/public/public.service");
const { logger } = require("./core/utils/logger");

async function main() {
  const env = getEnv();
  const db = await initDb();
  await ensureDefaultRoles(db);
  await ensureAdminUser(db, env);

  const publicService = createPublicService({ env, logger });
  const app = createApp({ db, env, logger, publicService });

  return new Promise((resolve, reject) => {
    const server = app.listen(env.port, () => {
      logger.info("server_started", { port: env.port });
      resolve(server);
    });
    server.on("error", reject);
  });
}

module.exports = { main };
