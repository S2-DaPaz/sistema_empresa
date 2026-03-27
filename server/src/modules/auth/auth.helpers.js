const crypto = require("crypto");

const AUTH_CODE_PURPOSES = {
  EMAIL_VERIFICATION: "EMAIL_VERIFICATION",
  PASSWORD_RESET: "PASSWORD_RESET"
};

const ACCOUNT_STATUS = {
  PENDING_VERIFICATION: "pending_verification",
  ACTIVE: "active",
  BLOCKED: "blocked"
};

function nowIso() {
  return new Date().toISOString();
}

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function normalizeName(value) {
  return String(value || "")
    .trim()
    .replace(/\s+/g, " ");
}

function maskEmail(value) {
  const email = normalizeEmail(value);
  const [localPart, domain] = email.split("@");
  if (!localPart || !domain) return email;
  if (localPart.length <= 2) {
    return `${localPart[0] || "*"}***@${domain}`;
  }
  return `${localPart.slice(0, 2)}***@${domain}`;
}

function hashValue(value, secret) {
  return crypto.createHmac("sha256", secret).update(String(value)).digest("hex");
}

function compareHashedValue(rawValue, hashedValue, secret) {
  const expected = hashValue(rawValue, secret);
  const expectedBuffer = Buffer.from(expected);
  const hashedBuffer = Buffer.from(String(hashedValue || ""));
  if (expectedBuffer.length !== hashedBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(expectedBuffer, hashedBuffer);
}

function generateNumericCode(digits = 6) {
  let value = "";
  while (value.length < digits) {
    value += crypto.randomInt(0, 10).toString();
  }
  return value.slice(0, digits);
}

function generateRefreshToken() {
  return crypto.randomBytes(48).toString("base64url");
}

function isExpired(value) {
  return !value || new Date(value).getTime() <= Date.now();
}

function secondsUntil(value) {
  const delta = new Date(value).getTime() - Date.now();
  return Math.max(Math.ceil(delta / 1000), 0);
}

function getClientIp(req = {}) {
  const forwarded = req.headers?.["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.trim()) {
    return forwarded.split(",")[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || null;
}

function getClientPlatform(req = {}) {
  return String(req.headers?.["x-client-platform"] || "backend")
    .trim()
    .toLowerCase();
}

function getDeviceInfo(req = {}) {
  const explicitDevice = String(req.headers?.["x-client-device-name"] || "").trim();
  if (explicitDevice) {
    return explicitDevice.slice(0, 120);
  }
  return String(req.headers?.["user-agent"] || "").slice(0, 500) || null;
}

function parseDurationToMs(value, fallbackMs) {
  const match = /^\s*(\d+)\s*([smhd])\s*$/i.exec(String(value || ""));
  if (!match) return fallbackMs;

  const amount = Number(match[1]);
  const unit = match[2].toLowerCase();
  const factor = {
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000
  }[unit];

  return Number.isFinite(amount) && factor ? amount * factor : fallbackMs;
}

function isSessionOnline(session, onlineWindowMs, nowMs = Date.now()) {
  if (!session || session.revoked_at || isExpired(session.expires_at)) {
    return false;
  }

  const lastActivityMs = new Date(session.last_used_at || session.created_at || 0).getTime();
  if (!Number.isFinite(lastActivityMs)) {
    return false;
  }

  return nowMs - lastActivityMs <= onlineWindowMs;
}

function inferSessionDeviceName(session = {}) {
  const rawInfo = String(session.device_info || "").trim();
  const platform = String(session.platform || "").trim().toLowerCase();

  if (rawInfo && !looksLikeRuntimeLabel(rawInfo) && !looksLikeBrowserUserAgent(rawInfo)) {
    return rawInfo;
  }

  if (looksLikeBrowserUserAgent(rawInfo)) {
    const browser = inferBrowserName(rawInfo);
    const operatingSystem = inferOperatingSystem(rawInfo);
    if (browser && operatingSystem) {
      return `${browser} no ${operatingSystem}`;
    }
    if (browser || operatingSystem) {
      return browser || operatingSystem;
    }
  }

  switch (platform) {
    case "mobile":
      return "Aplicativo móvel";
    case "web":
      return "Navegador web";
    default:
      return "Sessão ativa";
  }
}

function buildSessionDeviceKey(session = {}) {
  const platform = String(session.platform || "unknown").trim().toLowerCase();
  const deviceName = inferSessionDeviceName(session);
  const rawInfo = String(session.device_info || "").trim().toLowerCase();
  const ipAddress = String(session.ip_address || "").trim().toLowerCase();
  const genericNames = new Set([
    "aplicativo móvel",
    "navegador web",
    "sessão ativa"
  ]);

  const identitySeed = genericNames.has(deviceName.toLowerCase())
    ? [rawInfo || deviceName.toLowerCase(), ipAddress].filter(Boolean).join(":")
    : deviceName.toLowerCase();

  return `${platform}:${identitySeed || deviceName.toLowerCase()}`;
}

function looksLikeRuntimeLabel(value) {
  const normalized = String(value || "").toLowerCase();
  return normalized.startsWith("dart/") || normalized.includes("(dart:io)");
}

function looksLikeBrowserUserAgent(value) {
  const normalized = String(value || "");
  return (
    normalized.includes("Mozilla/") ||
    normalized.includes("AppleWebKit/") ||
    normalized.includes("Chrome/") ||
    normalized.includes("Firefox/") ||
    normalized.includes("Safari/")
  );
}

function inferBrowserName(userAgent) {
  const normalized = String(userAgent || "");
  if (/edg\//i.test(normalized)) return "Edge";
  if (/chrome\//i.test(normalized) && !/edg\//i.test(normalized)) return "Chrome";
  if (/firefox\//i.test(normalized)) return "Firefox";
  if (/safari\//i.test(normalized) && !/chrome\//i.test(normalized)) return "Safari";
  return null;
}

function inferOperatingSystem(userAgent) {
  const normalized = String(userAgent || "");
  if (/windows/i.test(normalized)) return "Windows";
  if (/android/i.test(normalized)) return "Android";
  if (/iphone|ipad|ios/i.test(normalized)) return "iPhone";
  if (/mac os x/i.test(normalized)) return "macOS";
  if (/linux/i.test(normalized)) return "Linux";
  return null;
}

module.exports = {
  ACCOUNT_STATUS,
  AUTH_CODE_PURPOSES,
  addDays,
  addMinutes,
  buildSessionDeviceKey,
  compareHashedValue,
  generateNumericCode,
  generateRefreshToken,
  getClientIp,
  getClientPlatform,
  getDeviceInfo,
  hashValue,
  inferSessionDeviceName,
  isExpired,
  isSessionOnline,
  maskEmail,
  normalizeEmail,
  normalizeName,
  nowIso,
  parseDurationToMs,
  secondsUntil
};
