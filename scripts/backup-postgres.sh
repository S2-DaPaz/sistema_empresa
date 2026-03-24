#!/usr/bin/env bash
# ------------------------------------------------------------------
# backup-postgres.sh
# Gera dump PostgreSQL, valida, criptografa, gera hash e manifest.
# Projetado para rodar no runner do GitHub Actions (ubuntu-latest).
# ------------------------------------------------------------------
set -euo pipefail

# ── Configuração ──────────────────────────────────────────────────
DATABASE_URL_DIRECT="${DATABASE_URL_DIRECT:?DATABASE_URL_DIRECT é obrigatória}"
BACKUP_ENCRYPTION_PASSPHRASE="${BACKUP_ENCRYPTION_PASSPHRASE:?BACKUP_ENCRYPTION_PASSPHRASE é obrigatória}"
APP_ENVIRONMENT="${APP_ENVIRONMENT:-production}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/backup}"
RUN_ID="${GITHUB_RUN_ID:-local-$(date +%s)}"
COMMIT_SHA="${GITHUB_SHA:-unknown}"

# ── Naming ────────────────────────────────────────────────────────
TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S")
BASE_NAME="backup_${APP_ENVIRONMENT}_${TIMESTAMP}_${RUN_ID}"
DUMP_FILE="${BACKUP_DIR}/${BASE_NAME}.dump"
ENCRYPTED_FILE="${BACKUP_DIR}/${BASE_NAME}.dump.gpg"
SHA256_FILE="${BACKUP_DIR}/${BASE_NAME}.sha256"
MANIFEST_FILE="${BACKUP_DIR}/${BASE_NAME}.manifest.json"

# ── Funções auxiliares ────────────────────────────────────────────
log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
}

cleanup() {
  log "Limpando arquivos temporários..."
  rm -f "${DUMP_FILE}" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  log "ERRO: $*"
  exit 1
}

# ── Preparação ────────────────────────────────────────────────────
mkdir -p "${BACKUP_DIR}"
log "Iniciando backup do PostgreSQL (ambiente: ${APP_ENVIRONMENT})"
log "Run ID: ${RUN_ID}"
START_TIME=$(date +%s)

# ── 1. pg_dump ────────────────────────────────────────────────────
log "Executando pg_dump..."
pg_dump "${DATABASE_URL_DIRECT}" \
  -Fc \
  --no-owner \
  --no-privileges \
  --verbose \
  -f "${DUMP_FILE}" 2>&1 | tail -5

DUMP_SIZE=$(stat -c%s "${DUMP_FILE}" 2>/dev/null || stat -f%z "${DUMP_FILE}" 2>/dev/null || echo 0)

if [ "${DUMP_SIZE}" -eq 0 ]; then
  fail "Arquivo dump vazio. pg_dump falhou."
fi

log "Dump gerado: ${DUMP_FILE} (${DUMP_SIZE} bytes)"

# ── 2. Validação ──────────────────────────────────────────────────
log "Validando dump com pg_restore --list..."
TABLE_COUNT=$(pg_restore --list "${DUMP_FILE}" 2>/dev/null | grep -c "TABLE" || true)

if [ "${TABLE_COUNT}" -eq 0 ]; then
  fail "Dump inválido: nenhuma tabela encontrada no TOC."
fi

log "Dump válido: ${TABLE_COUNT} entradas TABLE no TOC."

# ── 3. Hash SHA-256 (do dump original) ───────────────────────────
log "Calculando SHA-256 do dump original..."
ORIGINAL_SHA256=$(sha256sum "${DUMP_FILE}" | awk '{print $1}')
log "SHA-256: ${ORIGINAL_SHA256}"

# ── 4. Criptografia GPG (AES-256, simétrico) ─────────────────────
log "Criptografando com GPG (AES-256)..."
echo "${BACKUP_ENCRYPTION_PASSPHRASE}" | gpg \
  --batch \
  --yes \
  --passphrase-fd 0 \
  --symmetric \
  --cipher-algo AES256 \
  --compress-algo none \
  --output "${ENCRYPTED_FILE}" \
  "${DUMP_FILE}"

ENCRYPTED_SIZE=$(stat -c%s "${ENCRYPTED_FILE}" 2>/dev/null || stat -f%z "${ENCRYPTED_FILE}" 2>/dev/null || echo 0)

if [ "${ENCRYPTED_SIZE}" -eq 0 ]; then
  fail "Arquivo criptografado vazio. Criptografia falhou."
fi

log "Arquivo criptografado: ${ENCRYPTED_FILE} (${ENCRYPTED_SIZE} bytes)"

# ── 5. Hash SHA-256 do arquivo criptografado ──────────────────────
ENCRYPTED_SHA256=$(sha256sum "${ENCRYPTED_FILE}" | awk '{print $1}')
echo "${ENCRYPTED_SHA256}  $(basename "${ENCRYPTED_FILE}")" > "${SHA256_FILE}"
log "SHA-256 (criptografado): ${ENCRYPTED_SHA256}"

# ── 6. Manifest JSON ─────────────────────────────────────────────
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

cat > "${MANIFEST_FILE}" <<MANIFEST
{
  "version": "1.0",
  "environment": "${APP_ENVIRONMENT}",
  "timestamp": "${TIMESTAMP}",
  "run_id": "${RUN_ID}",
  "commit_sha": "${COMMIT_SHA}",
  "dump_file": "$(basename "${DUMP_FILE}")",
  "encrypted_file": "$(basename "${ENCRYPTED_FILE}")",
  "dump_size_bytes": ${DUMP_SIZE},
  "encrypted_size_bytes": ${ENCRYPTED_SIZE},
  "original_sha256": "${ORIGINAL_SHA256}",
  "encrypted_sha256": "${ENCRYPTED_SHA256}",
  "table_count": ${TABLE_COUNT},
  "encryption": "gpg-aes256-symmetric",
  "format": "pg_dump-custom",
  "duration_seconds": ${DURATION},
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
MANIFEST

log "Manifest gerado: ${MANIFEST_FILE}"
log "Backup concluído com sucesso em ${DURATION}s."

# ── Output para GitHub Actions ────────────────────────────────────
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "dump_file=${DUMP_FILE}"
    echo "encrypted_file=${ENCRYPTED_FILE}"
    echo "sha256_file=${SHA256_FILE}"
    echo "manifest_file=${MANIFEST_FILE}"
    echo "base_name=${BASE_NAME}"
    echo "dump_size=${DUMP_SIZE}"
    echo "encrypted_size=${ENCRYPTED_SIZE}"
    echo "original_sha256=${ORIGINAL_SHA256}"
    echo "encrypted_sha256=${ENCRYPTED_SHA256}"
    echo "table_count=${TABLE_COUNT}"
    echo "duration=${DURATION}"
  } >> "${GITHUB_OUTPUT}"
fi
