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

function toPositiveNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
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

function getEmailConfig() {
  return {
    provider: (process.env.EMAIL_PROVIDER || "console").trim().toLowerCase(),
    fromName: (process.env.EMAIL_FROM_NAME || "RV Sistema Empresa").trim(),
    fromAddress: (process.env.EMAIL_FROM_ADDRESS || "noreply@local.dev").trim(),
    replyTo: (process.env.EMAIL_REPLY_TO || "").trim(),
    smtp: {
      host: (process.env.SMTP_HOST || "").trim(),
      port: toPositiveNumber(process.env.SMTP_PORT, 587),
      secure: String(process.env.SMTP_SECURE || "false").toLowerCase() === "true",
      user: (process.env.SMTP_USER || "").trim(),
      password: process.env.SMTP_PASSWORD || ""
    }
  };
}

function getEnv() {
  const jwtSecret = getJwtSecret();
  const accessTokenTtl = process.env.ACCESS_TOKEN_TTL || process.env.JWT_TTL || "15m";

  return {
    nodeEnv: process.env.NODE_ENV || "development",
    port: Number(process.env.PORT || 3001),
    staticDir: process.env.STATIC_DIR || "",
    publicBaseUrl: process.env.PUBLIC_BASE_URL || "",
    jwtSecret,
    jwtTtl: accessTokenTtl,
    accessTokenTtl,
    refreshTokenTtlDays: toPositiveNumber(process.env.REFRESH_TOKEN_TTL_DAYS, 30),
    authCodeSecret: process.env.AUTH_CODE_SECRET || jwtSecret,
    auth: {
      codeDigits: toPositiveNumber(process.env.AUTH_CODE_DIGITS, 6),
      verificationCodeTtlMinutes: toPositiveNumber(
        process.env.AUTH_VERIFICATION_CODE_TTL_MINUTES,
        15
      ),
      passwordResetCodeTtlMinutes: toPositiveNumber(
        process.env.AUTH_PASSWORD_RESET_CODE_TTL_MINUTES,
        15
      ),
      resendCooldownSeconds: toPositiveNumber(process.env.AUTH_RESEND_COOLDOWN_SECONDS, 60),
      maxCodeAttempts: toPositiveNumber(process.env.AUTH_MAX_CODE_ATTEMPTS, 5),
      loginRateLimit: {
        maxAttempts: toPositiveNumber(process.env.AUTH_LOGIN_MAX_ATTEMPTS, 5),
        windowMinutes: toPositiveNumber(process.env.AUTH_LOGIN_WINDOW_MINUTES, 15),
        blockMinutes: toPositiveNumber(process.env.AUTH_LOGIN_BLOCK_MINUTES, 15)
      },
      emailRateLimit: {
        maxAttempts: toPositiveNumber(process.env.AUTH_EMAIL_MAX_ATTEMPTS, 5),
        windowMinutes: toPositiveNumber(process.env.AUTH_EMAIL_WINDOW_MINUTES, 60),
        blockMinutes: toPositiveNumber(process.env.AUTH_EMAIL_BLOCK_MINUTES, 60)
      },
      passwordPolicy: {
        minLength: toPositiveNumber(process.env.AUTH_PASSWORD_MIN_LENGTH, 8)
      }
    },
    allowedOrigins: getAllowedOrigins(),
    adminName: process.env.ADMIN_NAME || "Administrador",
    adminEmail: process.env.ADMIN_EMAIL || "admin@local",
    adminBootstrapPassword: getAdminBootstrapPassword(),
    autoBootstrapAdmin: process.env.AUTO_BOOTSTRAP_ADMIN !== "false",
    email: getEmailConfig(),
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
