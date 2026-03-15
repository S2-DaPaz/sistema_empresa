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
  return String(req.headers?.["user-agent"] || "").slice(0, 500) || null;
}

module.exports = {
  ACCOUNT_STATUS,
  AUTH_CODE_PURPOSES,
  addDays,
  addMinutes,
  compareHashedValue,
  generateNumericCode,
  generateRefreshToken,
  getClientIp,
  getClientPlatform,
  getDeviceInfo,
  hashValue,
  isExpired,
  maskEmail,
  normalizeEmail,
  normalizeName,
  nowIso,
  secondsUntil
};
