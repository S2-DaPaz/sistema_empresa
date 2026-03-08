const fs = require("fs");
const path = require("path");

function resolveStaticDir(staticDir) {
  const candidates = [
    staticDir,
    path.join(__dirname, "..", "..", "..", "web", "dist"),
    path.join(process.cwd(), "web", "dist")
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (fs.existsSync(path.join(candidate, "index.html"))) {
      return candidate;
    }
  }

  return null;
}

module.exports = { resolveStaticDir };
