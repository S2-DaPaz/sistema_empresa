const crypto = require("crypto");
const path = require("path");

require("dotenv").config({ path: path.join(__dirname, "..", "..", ".env") });

let generatedJwtSecret;

function getJwtSecret() {
  if (process.env.JWT_SECRET) {
    return process.env.JWT_SECRET;
  }

  if (process.env.NODE_ENV === "production") {
    throw new Error("JWT_SECRET is required in production.");
  }

  if (!generatedJwtSecret) {
    generatedJwtSecret = crypto.randomBytes(48).toString("hex");
  }

  return generatedJwtSecret;
}

function getAllowedOrigins() {
  const raw = process.env.ALLOWED_ORIGINS || "";
  return raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

function getAdminBootstrapPassword() {
  if (process.env.ADMIN_PASSWORD) {
    return process.env.ADMIN_PASSWORD;
  }

  if (process.env.AUTO_BOOTSTRAP_ADMIN === "false") {
    return null;
  }

  return crypto.randomBytes(12).toString("base64url");
}

function getEnv() {
  return {
    nodeEnv: process.env.NODE_ENV || "development",
    port: Number(process.env.PORT || 3001),
    staticDir: process.env.STATIC_DIR || "",
    publicBaseUrl: process.env.PUBLIC_BASE_URL || "",
    jwtSecret: getJwtSecret(),
    jwtTtl: process.env.JWT_TTL || "7d",
    allowedOrigins: getAllowedOrigins(),
    adminName: process.env.ADMIN_NAME || "Administrador",
    adminEmail: process.env.ADMIN_EMAIL || "admin@local",
    adminBootstrapPassword: getAdminBootstrapPassword(),
    autoBootstrapAdmin: process.env.AUTO_BOOTSTRAP_ADMIN !== "false",
    pdfCacheEnabled: String(process.env.PDF_CACHE_ENABLED || "true").toLowerCase() !== "false",
    pdfWarmDebounceMs: Math.max(0, Number(process.env.PDF_WARM_DEBOUNCE_MS || 1500)),
    publicLinkDefaultDays: Math.max(1, Number(process.env.PUBLIC_LINK_DEFAULT_DAYS || 30)),
    puppeteerExecutablePath: process.env.PUPPETEER_EXECUTABLE_PATH || "",
    puppeteerArgs: (process.env.PUPPETEER_ARGS || "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
    mobileUpdate: {
      versionCode: Number(process.env.MOBILE_APP_VERSION_CODE || 0),
      versionName: (process.env.MOBILE_APP_VERSION_NAME || "").trim(),
      apkUrl: (process.env.MOBILE_APP_APK_URL || "").trim(),
      notes: (process.env.MOBILE_APP_NOTES || "").trim(),
      mandatory: String(process.env.MOBILE_APP_MANDATORY || "").toLowerCase() === "true"
    }
  };
}

module.exports = { getEnv };
