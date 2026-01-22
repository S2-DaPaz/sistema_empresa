const path = require("path");
const fs = require("fs");
const http = require("http");
const { exec } = require("child_process");

const APP_NAME = "RV Sistema Empresa";
const PORT = Number(process.env.PORT || 3001);

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
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  });
}

function ensureDatabaseUrl() {
  const envPath = ensureEnvFile();
  const hasUrl = process.env.DATABASE_URL && process.env.DATABASE_URL.trim().length > 0;
  if (hasUrl) return true;

  const instructionsPath = path.join(__dirname, "missing-env.html");
  exec(`start \"\" \"${instructionsPath}\"`);
  exec(`notepad \"${envPath}\"`);
  return false;
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
      // ignore
    }
  }
  return null;
}

function copyDir(source, destination) {
  fs.mkdirSync(destination, { recursive: true });
  const entries = fs.readdirSync(source, { withFileTypes: true });
  entries.forEach((entry) => {
    const sourcePath = path.join(source, entry.name);
    const destPath = path.join(destination, entry.name);
    if (entry.isDirectory()) {
      copyDir(sourcePath, destPath);
      return;
    }
    fs.copyFileSync(sourcePath, destPath);
  });
}

function ensureStaticDir() {
  const appDir = path.join(getAppDataDir(), APP_NAME, "web", "dist");
  const indexPath = path.join(appDir, "index.html");
  if (fs.existsSync(indexPath)) {
    return appDir;
  }

  const sourceDir = process.pkg
    ? path.join(path.dirname(process.execPath), "web", "dist")
    : path.join(__dirname, "..", "web", "dist");
  if (fs.existsSync(sourceDir)) {
    try {
      copyDir(sourceDir, appDir);
      return appDir;
    } catch (error) {
      // fallback to snapshot path
      return sourceDir;
    }
  }

  return resolveStaticDir();
}

function waitForServer(timeoutMs = 30000) {
  const start = Date.now();
  const url = `http://localhost:${PORT}/api/health`;

  return new Promise((resolve, reject) => {
    const check = () => {
      http
        .get(url, (res) => {
          res.resume();
          if (res.statusCode && res.statusCode >= 200) {
            resolve();
            return;
          }
          retry();
        })
        .on("error", retry);
    };

    const retry = () => {
      if (Date.now() - start > timeoutMs) {
        reject(new Error("Servidor nao respondeu a tempo."));
        return;
      }
      setTimeout(check, 500);
    };

    check();
  });
}

function openBrowser() {
  exec(`start \"\" \"http://localhost:${PORT}\"`);
}

async function isServerRunning() {
  try {
    await waitForServer(1500);
    return true;
  } catch (error) {
    return false;
  }
}

async function main() {
  loadEnv();
  if (!ensureDatabaseUrl()) {
    process.exit(1);
  }
  const staticDir = ensureStaticDir();
  if (staticDir && !process.env.STATIC_DIR) {
    process.env.STATIC_DIR = staticDir;
  }

  if (!(await isServerRunning())) {
    const { main: startServer } = require("../server/index.js");
    await startServer();
  }
  await waitForServer();
  openBrowser();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
