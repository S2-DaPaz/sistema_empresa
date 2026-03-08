const path = require("path");
const fs = require("fs");
const { exec } = require("child_process");

const { main: startServer } = require("../server");

const APP_NAME = "RV Sistema Empresa";

function getAppDataDir() {
  return (
    process.env.APPDATA ||
    process.env.LOCALAPPDATA ||
    path.join(process.cwd(), "data")
  );
}

function ensureEnvFile() {
  const appDir = path.join(getAppDataDir(), APP_NAME);
  const envPath = path.join(appDir, "server.env");
  const defaultEnv = path.join(__dirname, "default.env");
  fs.mkdirSync(appDir, { recursive: true });

  if (!fs.existsSync(envPath)) {
    if (fs.existsSync(defaultEnv)) {
      fs.copyFileSync(defaultEnv, envPath);
    } else {
      fs.writeFileSync(envPath, "");
    }
  }

  return envPath;
}

function loadEnv() {
  const envPath = ensureEnvFile();
  const content = fs.readFileSync(envPath, "utf8");

  content.split(/\r?\n/).forEach((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) return;

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) return;

    const key = trimmed.slice(0, separatorIndex).trim();
    let value = trimmed.slice(separatorIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  });
}

function resolveStaticDir() {
  const candidates = [
    process.env.STATIC_DIR,
    path.join(__dirname, "..", "web", "dist"),
    path.join(process.cwd(), "web", "dist")
  ].filter(Boolean);

  for (const candidate of candidates) {
    try {
      const indexPath = path.join(candidate, "index.html");
      if (fs.existsSync(indexPath)) {
        return candidate;
      }
    } catch (error) {
      // ignore invalid candidate
    }
  }

  return null;
}

function resolveBundledStaticDir() {
  const sourceDir = process.pkg
    ? path.join(path.dirname(process.execPath), "web", "dist")
    : path.join(__dirname, "..", "web", "dist");
  const indexPath = path.join(sourceDir, "index.html");

  if (fs.existsSync(indexPath)) {
    return sourceDir;
  }

  return null;
}

function ensureStaticDir() {
  const bundledDir = resolveBundledStaticDir();
  if (bundledDir) {
    return bundledDir;
  }

  const appDir = path.join(getAppDataDir(), APP_NAME, "web", "dist");
  const indexPath = path.join(appDir, "index.html");
  if (fs.existsSync(indexPath)) {
    return appDir;
  }

  return resolveStaticDir();
}

function openBrowser(port) {
  exec(`start "" "http://localhost:${port}"`);
}

async function main() {
  loadEnv();

  const staticDir = ensureStaticDir();
  if (staticDir && !process.env.STATIC_DIR) {
    process.env.STATIC_DIR = staticDir;
  }

  if (!staticDir) {
    console.error("Front-end nao encontrado. Gere o build do web/dist.");
    process.exit(1);
  }

  const server = await startServer();
  const port = server.address()?.port || Number(process.env.PORT || 3001);
  openBrowser(port);

  const shutdown = () => {
    server.close(() => process.exit(0));
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
