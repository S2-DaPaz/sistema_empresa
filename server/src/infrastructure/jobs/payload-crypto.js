const crypto = require("crypto");

function createKey(secret) {
  return crypto.createHash("sha256").update(String(secret || "rv-jobs")).digest();
}

function encryptPayload(secret, payload) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", createKey(secret), iv);
  const plaintext = Buffer.from(JSON.stringify(payload ?? {}), "utf8");
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return Buffer.concat([iv, authTag, encrypted]).toString("base64");
}

function decryptPayload(secret, encryptedPayload) {
  const raw = Buffer.from(String(encryptedPayload || ""), "base64");
  const iv = raw.subarray(0, 12);
  const authTag = raw.subarray(12, 28);
  const encrypted = raw.subarray(28);
  const decipher = crypto.createDecipheriv("aes-256-gcm", createKey(secret), iv);
  decipher.setAuthTag(authTag);
  const plaintext = Buffer.concat([decipher.update(encrypted), decipher.final()]).toString("utf8");
  return JSON.parse(plaintext);
}

module.exports = { encryptPayload, decryptPayload };
