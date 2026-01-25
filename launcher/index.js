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

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".map": "application/json"
};

function getContentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return MIME_TYPES[ext] || "application/octet-stream";
}

function serveFile(res, filePath) {
  res.writeHead(200, { "Content-Type": getContentType(filePath) });
  fs.createReadStream(filePath).pipe(res);
}

function startStaticServer(staticDir) {
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      if (!staticDir) {
        res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Front-end nao encontrado.");
        return;
      }

      if (req.method !== "GET" && req.method !== "HEAD") {
        res.writeHead(405, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Metodo nao permitido.");
        return;
      }

      const url = new URL(req.url, `http://localhost:${PORT}`);
      let pathname = decodeURIComponent(url.pathname || "/");
      if (pathname === "/") pathname = "/index.html";

      const filePath = path.join(staticDir, pathname);
      if (!filePath.startsWith(staticDir)) {
        res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Acesso negado.");
        return;
      }

      fs.stat(filePath, (err, stats) => {
        if (!err && stats.isFile()) {
          serveFile(res, filePath);
          return;
        }
        const indexPath = path.join(staticDir, "index.html");
        if (fs.existsSync(indexPath)) {
          serveFile(res, indexPath);
          return;
        }
        res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Front-end nao encontrado.");
      });
    });

    server.on("error", reject);
    server.listen(PORT, () => resolve(server));
  });
}

function openBrowser() {
  exec(`start \"\" \"http://localhost:${PORT}\"`);
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

  await startStaticServer(staticDir);
  openBrowser();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
