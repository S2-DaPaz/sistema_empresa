#!/usr/bin/env node
// ------------------------------------------------------------------
// upload-drive.js
// Faz upload de arquivos para o Google Drive usando Service Account.
// Sem dependências externas além do Node.js built-in.
// ------------------------------------------------------------------
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const https = require("https");
const path = require("path");

// ── Configuração ─────────────────────────────────────────────────
const GDRIVE_FOLDER_ID = process.env.GDRIVE_FOLDER_ID;
const SA_JSON_RAW = process.env.GDRIVE_SERVICE_ACCOUNT_JSON || "";
const SA_JSON_B64 = process.env.GDRIVE_SERVICE_ACCOUNT_JSON_B64 || "";
const MAX_BACKUPS = Number(process.env.BACKUP_RETENTION_COUNT) || 30;

function loadServiceAccount() {
  let raw = SA_JSON_RAW;
  if (!raw && SA_JSON_B64) {
    raw = Buffer.from(SA_JSON_B64, "base64").toString("utf-8");
  }
  if (!raw) {
    throw new Error(
      "GDRIVE_SERVICE_ACCOUNT_JSON ou GDRIVE_SERVICE_ACCOUNT_JSON_B64 é obrigatória."
    );
  }
  return JSON.parse(raw);
}

// ── JWT para Google OAuth2 ───────────────────────────────────────
function createJwt(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/drive.file",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600
  };

  const segments = [
    base64url(JSON.stringify(header)),
    base64url(JSON.stringify(payload))
  ];
  const signingInput = segments.join(".");

  const sign = crypto.createSign("RSA-SHA256");
  sign.update(signingInput);
  const signature = sign.sign(serviceAccount.private_key);

  segments.push(base64url(signature));
  return segments.join(".");
}

function base64url(input) {
  const buf = typeof input === "string" ? Buffer.from(input) : input;
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getAccessToken(serviceAccount) {
  const jwt = createJwt(serviceAccount);
  const body = `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`;

  const data = await httpPost("oauth2.googleapis.com", "/token", body, {
    "Content-Type": "application/x-www-form-urlencoded"
  });
  return JSON.parse(data).access_token;
}

// ── HTTP helpers ─────────────────────────────────────────────────
function httpPost(host, path, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      { hostname: host, port: 443, path, method: "POST", headers: { ...headers } },
      (res) => {
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
      }
    );
    req.on("error", reject);
    req.end(body);
  });
}

function httpGet(host, pathStr, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      { hostname: host, port: 443, path: pathStr, method: "GET", headers },
      (res) => {
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
      }
    );
    req.on("error", reject);
    req.end();
  });
}

function httpDelete(host, pathStr, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      { hostname: host, port: 443, path: pathStr, method: "DELETE", headers },
      (res) => {
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
      }
    );
    req.on("error", reject);
    req.end();
  });
}

// ── Upload multipart para Google Drive ───────────────────────────
async function uploadFile(accessToken, filePath, folderId) {
  const fileName = path.basename(filePath);
  const fileContent = fs.readFileSync(filePath);
  const mimeType = fileName.endsWith(".json")
    ? "application/json"
    : "application/octet-stream";

  const metadata = JSON.stringify({
    name: fileName,
    parents: [folderId]
  });

  const boundary = `----BackupBoundary${Date.now()}`;
  const body = Buffer.concat([
    Buffer.from(
      `--${boundary}\r\n` +
        `Content-Type: application/json; charset=UTF-8\r\n\r\n` +
        `${metadata}\r\n` +
        `--${boundary}\r\n` +
        `Content-Type: ${mimeType}\r\n\r\n`
    ),
    fileContent,
    Buffer.from(`\r\n--${boundary}--`)
  ]);

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: "www.googleapis.com",
        port: 443,
        path: "/upload/drive/v3/files?uploadType=multipart&fields=id,name,size",
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": `multipart/related; boundary=${boundary}`,
          "Content-Length": body.length
        }
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const data = Buffer.concat(chunks).toString();
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(JSON.parse(data));
          } else {
            reject(new Error(`Upload falhou (HTTP ${res.statusCode}): ${data}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.end(body);
  });
}

// ── Retenção: listar e remover backups antigos ───────────────────
async function applyRetention(accessToken, folderId, maxFiles) {
  const query = encodeURIComponent(`'${folderId}' in parents and trashed = false`);
  const url = `/drive/v3/files?q=${query}&orderBy=createdTime+desc&fields=files(id,name,createdTime)&pageSize=1000`;

  const data = await httpGet("www.googleapis.com", url, {
    Authorization: `Bearer ${accessToken}`
  });
  const files = JSON.parse(data).files || [];

  // Agrupar por tipo: .gpg são os backups principais
  const gpgFiles = files.filter((f) => f.name.endsWith(".dump.gpg"));

  if (gpgFiles.length <= maxFiles) {
    console.log(`Retenção: ${gpgFiles.length}/${maxFiles} backups. Nada a remover.`);
    return [];
  }

  const toDelete = gpgFiles.slice(maxFiles);
  const deleted = [];

  for (const file of toDelete) {
    // Encontrar arquivos relacionados (sha256, manifest) pelo prefixo
    const prefix = file.name.replace(".dump.gpg", "");
    const related = files.filter(
      (f) => f.name.startsWith(prefix) && f.id !== file.id
    );

    for (const rel of [file, ...related]) {
      try {
        await httpDelete("www.googleapis.com", `/drive/v3/files/${rel.id}`, {
          Authorization: `Bearer ${accessToken}`
        });
        deleted.push(rel.name);
        console.log(`Removido: ${rel.name}`);
      } catch (err) {
        console.error(`Erro ao remover ${rel.name}: ${err.message}`);
      }
    }
  }

  console.log(`Retenção: ${deleted.length} arquivos removidos.`);
  return deleted;
}

// ── Main ─────────────────────────────────────────────────────────
async function main() {
  if (!GDRIVE_FOLDER_ID) {
    throw new Error("GDRIVE_FOLDER_ID é obrigatória.");
  }

  const filePaths = process.argv.slice(2);
  if (filePaths.length === 0) {
    throw new Error("Uso: node upload-drive.js <arquivo1> [arquivo2] ...");
  }

  for (const fp of filePaths) {
    if (!fs.existsSync(fp)) {
      throw new Error(`Arquivo não encontrado: ${fp}`);
    }
  }

  console.log("Carregando service account...");
  const sa = loadServiceAccount();

  console.log("Obtendo access token...");
  const accessToken = await getAccessToken(sa);

  const uploaded = [];
  for (const fp of filePaths) {
    console.log(`Fazendo upload: ${path.basename(fp)}...`);
    const result = await uploadFile(accessToken, fp, GDRIVE_FOLDER_ID);
    console.log(`  -> ID: ${result.id}, Nome: ${result.name}, Tamanho: ${result.size}`);
    uploaded.push(result);
  }

  console.log("Aplicando política de retenção...");
  await applyRetention(accessToken, GDRIVE_FOLDER_ID, MAX_BACKUPS);

  // Output para GitHub Actions
  if (process.env.GITHUB_OUTPUT) {
    const ids = uploaded.map((u) => u.id).join(",");
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `drive_file_ids=${ids}\n`);
  }

  console.log("Upload concluído com sucesso.");
}

main().catch((err) => {
  console.error(`ERRO: ${err.message}`);
  process.exit(1);
});
