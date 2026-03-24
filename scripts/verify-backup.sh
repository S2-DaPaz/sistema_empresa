#!/usr/bin/env bash
# ------------------------------------------------------------------
# verify-backup.sh
# Verifica integridade de um backup criptografado sem restaurar.
#
# Uso:
#   ./verify-backup.sh <arquivo.dump.gpg>
#
# Requer: gpg, pg_restore, variável BACKUP_ENCRYPTION_PASSPHRASE
# ------------------------------------------------------------------
set -euo pipefail

ENCRYPTED_FILE="${1:?Uso: ./verify-backup.sh <arquivo.dump.gpg>}"
PASSPHRASE="${BACKUP_ENCRYPTION_PASSPHRASE:?Defina BACKUP_ENCRYPTION_PASSPHRASE}"
TEMP_DUMP="/tmp/verify_$(date +%s).dump"

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
}

cleanup() {
  rm -f "${TEMP_DUMP}" 2>/dev/null || true
}
trap cleanup EXIT

if [ ! -f "${ENCRYPTED_FILE}" ]; then
  echo "ERRO: Arquivo não encontrado: ${ENCRYPTED_FILE}"
  exit 1
fi

# ── SHA-256 ───────────────────────────────────────────────────────
SHA_FILE="${ENCRYPTED_FILE%.dump.gpg}.sha256"
if [ -f "${SHA_FILE}" ]; then
  log "Verificando SHA-256..."
  EXPECTED=$(awk '{print $1}' "${SHA_FILE}")
  ACTUAL=$(sha256sum "${ENCRYPTED_FILE}" | awk '{print $1}')
  if [ "${EXPECTED}" = "${ACTUAL}" ]; then
    log "✓ SHA-256 OK"
  else
    log "✗ SHA-256 FALHOU"
    exit 1
  fi
else
  log "⚠ Arquivo .sha256 não encontrado"
fi

# ── Descriptografar ──────────────────────────────────────────────
log "Descriptografando para verificação..."
echo "${PASSPHRASE}" | gpg \
  --batch \
  --yes \
  --passphrase-fd 0 \
  --decrypt \
  --output "${TEMP_DUMP}" \
  "${ENCRYPTED_FILE}"

DUMP_SIZE=$(stat -c%s "${TEMP_DUMP}" 2>/dev/null || stat -f%z "${TEMP_DUMP}" 2>/dev/null || echo 0)
log "Tamanho do dump: ${DUMP_SIZE} bytes"

# ── Validar TOC ──────────────────────────────────────────────────
log "Listando conteúdo do dump..."
TOC=$(pg_restore --list "${TEMP_DUMP}" 2>/dev/null)
TABLE_COUNT=$(echo "${TOC}" | grep -c "TABLE" || true)
INDEX_COUNT=$(echo "${TOC}" | grep -c "INDEX" || true)
TOTAL=$(echo "${TOC}" | wc -l)

echo ""
echo "═══════════════════════════════════════"
echo "  Resultado da Verificação"
echo "═══════════════════════════════════════"
echo "  Arquivo:    $(basename "${ENCRYPTED_FILE}")"
echo "  Tamanho:    ${DUMP_SIZE} bytes"
echo "  Tabelas:    ${TABLE_COUNT}"
echo "  Índices:    ${INDEX_COUNT}"
echo "  Total TOC:  ${TOTAL} entradas"
echo "  Status:     ✓ VÁLIDO"
echo "═══════════════════════════════════════"
