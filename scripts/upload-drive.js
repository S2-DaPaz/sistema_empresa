#!/usr/bin/env node
// ------------------------------------------------------------------
// upload-drive.js
// Faz upload de arquivos para o Google Drive.
// Suporta dois modos de autenticação:
//   1. OAuth2 Refresh Token (recomendado para Google Drive pessoal)
//   2. Service Account (requer Shared Drive / Google Workspace)
// Sem dependências externas além do Node.js built-in.
// ------------------------------------------------------------------
"use strict";

const fs = require("fs");
const https = require("https");
const crypto = require("crypto");
const path = require("path");

// ── Configuração ─────────────────────────────────────────────────
const GDRIVE_FOLDER_ID = process.env.GDRIVE_FOLDER_ID;
const MAX_BACKUPS = Number(process.env.BACKUP_RETENTION_COUNT) || 30;

// Modo OAuth2 (pessoal)
const GDRIVE_CLIENT_ID = process.env.GDRIVE_CLIENT_ID || "";
const GDRIVE_CLIENT_SECRET = process.env.GDRIVE_CLIENT_SECRET || "";
const GDRIVE_REFRESH_TOKEN = process.env.GDRIVE_REFRESH_TOKEN || "";

// Modo Service Account (Workspace/Shared Drive)
const SA_JSON_RAW = process.env.GDRIVE_SERVICE_ACCOUNT_JSON || "";
const SA_JSON_B64 = process.env.GDRIVE_SERVICE_ACCOUNT_JSON_B64 || "";

// ── HTTP helpers ─────────────────────────────────────────────────
function httpRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const data = Buffer.concat(chunks).toString();
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on("error", reject);
    if (body) req.end(body);
    else req.end();
  });
}

// ── Modo 1: OAuth2 com Refresh Token ─────────────────────────────
async function getAccessTokenOAuth2() {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: GDRIVE_CLIENT_ID,
    client_secret: GDRIVE_CLIENT_SECRET,
    refresh_token: GDRIVE_REFRESH_TOKEN
  }).toString();

  const data = await httpRequest(
    {
      hostname: "oauth2.googleapis.com",
      port: 443,
      path: "/token",
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Content-Length": Buffer.byteLength(body)
      }
    },
    body
  );
  return JSON.parse(data).access_token;
}

// ── Modo 2: Service Account JWT ───────────────────────────────────
function base64url(input) {
  const buf = typeof input === "string" ? Buffer.from(input) : input;
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function createServiceAccountJwt(sa) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/drive.file",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600
    })
  );
  const signingInput = `${header}.${payload}`;
  const sign = crypto.createSign("RSA-SHA256");
  sign.update(signingInput);
  return `${signingInput}.${base64url(sign.sign(sa.private_key))}`;
}

async function getAccessTokenServiceAccount() {
  let raw = SA_JSON_RAW;
  if (!raw && SA_JSON_B64) raw = Buffer.from(SA_JSON_B64, "base64").toString("utf-8");
  if (!raw) throw new Error("Service account JSON não encontrado.");
  const sa = JSON.parse(raw);
  const jwt = createServiceAccountJwt(sa);
  const body = `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`;
  const data = await httpRequest(
    {
      hostname: "oauth2.googleapis.com",
      port: 443,
      path: "/token",
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Content-Length": Buffer.byteLength(body)
      }
    },
    body
  );
  return JSON.parse(data).access_token;
}

async function getAccessToken() {
  if (GDRIVE_REFRESH_TOKEN && GDRIVE_CLIENT_ID && GDRIVE_CLIENT_SECRET) {
    console.log("Modo: OAuth2 Refresh Token (Drive pessoal)");
    return getAccessTokenOAuth2();
  }
  console.log("Modo: Service Account");
  return getAccessTokenServiceAccount();
}

// ── Upload multipart ──────────────────────────────────────────────
async function uploadFile(accessToken, filePath, folderId) {
  const fileName = path.basename(filePath);
  const fileContent = fs.readFileSync(filePath);
  const mimeType = fileName.endsWith(".json")
    ? "application/json"
    : "application/octet-stream";

  const metadata = JSON.stringify({ name: fileName, parents: [folderId] });
  const boundary = `----BackupBoundary${Date.now()}`;

  const body = Buffer.concat([
    Buffer.from(
      `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n` +
      `--${boundary}\r\nContent-Type: ${mimeType}\r\n\r\n`
    ),
    fileContent,
    Buffer.from(`\r\n--${boundary}--`)
  ]);

  const data = await httpRequest(
    {
      hostname: "www.googleapis.com",
      port: 443,
      path: "/upload/drive/v3/files?uploadType=multipart&fields=id,name,size&supportsAllDrives=true",
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": `multipart/related; boundary=${boundary}`,
        "Content-Length": body.length
      }
    },
    body
  );
  return JSON.parse(data);
}

// ── Retenção ──────────────────────────────────────────────────────
async function applyRetention(accessToken, folderId, maxFiles) {
  const query = encodeURIComponent(`'${folderId}' in parents and trashed = false`);
  const url = `/drive/v3/files?q=${query}&orderBy=createdTime+desc&fields=files(id,name,createdTime)&pageSize=1000&supportsAllDrives=true&includeItemsFromAllDrives=true`;

  const data = await httpRequest(
    { hostname: "www.googleapis.com", port: 443, path: url, method: "GET",
      headers: { Authorization: `Bearer ${accessToken}` } }
  );
  const files = JSON.parse(data).files || [];
  const gpgFiles = files.filter((f) => f.name.endsWith(".dump.gpg"));

  if (gpgFiles.length <= maxFiles) {
    console.log(`Retenção: ${gpgFiles.length}/${maxFiles} backups. Nada a remover.`);
    return;
  }

  const toDelete = gpgFiles.slice(maxFiles);
  for (const file of toDelete) {
    const prefix = file.name.replace(".dump.gpg", "");
    const related = files.filter((f) => f.name.startsWith(prefix));
    for (const rel of related) {
      try {
        await httpRequest(
          { hostname: "www.googleapis.com", port: 443,
            path: `/drive/v3/files/${rel.id}?supportsAllDrives=true`, method: "DELETE",
            headers: { Authorization: `Bearer ${accessToken}` } }
        );
        console.log(`Removido: ${rel.name}`);
      } catch (err) {
        console.error(`Erro ao remover ${rel.name}: ${err.message}`);
      }
    }
  }
}

// ── Main ─────────────────────────────────────────────────────────
async function main() {
  if (!GDRIVE_FOLDER_ID) throw new Error("GDRIVE_FOLDER_ID é obrigatória.");

  const filePaths = process.argv.slice(2);
  if (filePaths.length === 0) throw new Error("Uso: node upload-drive.js <arquivo1> ...");

  for (const fp of filePaths) {
    if (!fs.existsSync(fp)) throw new Error(`Arquivo não encontrado: ${fp}`);
  }

  console.log("Obtendo access token...");
  const accessToken = await getAccessToken();

  const uploaded = [];
  for (const fp of filePaths) {
    console.log(`Fazendo upload: ${path.basename(fp)}...`);
    const result = await uploadFile(accessToken, fp, GDRIVE_FOLDER_ID);
    console.log(`  -> ID: ${result.id}, Nome: ${result.name}`);
    uploaded.push(result);
  }

  console.log("Aplicando política de retenção...");
  await applyRetention(accessToken, GDRIVE_FOLDER_ID, MAX_BACKUPS);

  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(
      process.env.GITHUB_OUTPUT,
      `drive_file_ids=${uploaded.map((u) => u.id).join(",")}\n`
    );
  }

  console.log("Upload concluído com sucesso.");
}

main().catch((err) => {
  console.error(`ERRO: ${err.message}`);
  process.exit(1);
});
