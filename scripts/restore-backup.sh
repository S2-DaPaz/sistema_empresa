#!/usr/bin/env bash
# ------------------------------------------------------------------
# restore-backup.sh
# Descriptografa e restaura um backup PostgreSQL a partir do .dump.gpg
#
# Uso:
#   ./restore-backup.sh <arquivo.dump.gpg> <DATABASE_URL_DESTINO>
#
# Requer: gpg, pg_restore, variável BACKUP_ENCRYPTION_PASSPHRASE
# ------------------------------------------------------------------
set -euo pipefail

ENCRYPTED_FILE="${1:?Uso: ./restore-backup.sh <arquivo.dump.gpg> <DATABASE_URL>}"
TARGET_DB="${2:?Segundo argumento obrigatório: DATABASE_URL do banco de destino}"
PASSPHRASE="${BACKUP_ENCRYPTION_PASSPHRASE:?Defina BACKUP_ENCRYPTION_PASSPHRASE}"

DUMP_FILE="${ENCRYPTED_FILE%.gpg}"

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
}

cleanup() {
  rm -f "${DUMP_FILE}" 2>/dev/null || true
}
trap cleanup EXIT

# ── 1. Verificar arquivo ──────────────────────────────────────────
if [ ! -f "${ENCRYPTED_FILE}" ]; then
  echo "ERRO: Arquivo não encontrado: ${ENCRYPTED_FILE}"
  exit 1
fi

log "Arquivo de entrada: ${ENCRYPTED_FILE}"
log "Banco de destino: (omitido por segurança)"

# ── 2. Verificar SHA-256 (opcional) ───────────────────────────────
SHA_FILE="${ENCRYPTED_FILE%.dump.gpg}.sha256"
if [ -f "${SHA_FILE}" ]; then
  log "Verificando SHA-256..."
  EXPECTED=$(awk '{print $1}' "${SHA_FILE}")
  ACTUAL=$(sha256sum "${ENCRYPTED_FILE}" | awk '{print $1}')
  if [ "${EXPECTED}" != "${ACTUAL}" ]; then
    echo "ERRO: SHA-256 não confere!"
    echo "  Esperado: ${EXPECTED}"
    echo "  Obtido:   ${ACTUAL}"
    exit 1
  fi
  log "SHA-256 OK."
else
  log "Aviso: arquivo .sha256 não encontrado. Pulando verificação de integridade."
fi

# ── 3. Descriptografar ───────────────────────────────────────────
log "Descriptografando..."
echo "${PASSPHRASE}" | gpg \
  --batch \
  --yes \
  --passphrase-fd 0 \
  --decrypt \
  --output "${DUMP_FILE}" \
  "${ENCRYPTED_FILE}"

DUMP_SIZE=$(stat -c%s "${DUMP_FILE}" 2>/dev/null || stat -f%z "${DUMP_FILE}" 2>/dev/null || echo 0)
if [ "${DUMP_SIZE}" -eq 0 ]; then
  echo "ERRO: Arquivo descriptografado vazio."
  exit 1
fi
log "Descriptografado: ${DUMP_FILE} (${DUMP_SIZE} bytes)"

# ── 4. Validar dump ──────────────────────────────────────────────
log "Validando dump..."
TABLE_COUNT=$(pg_restore --list "${DUMP_FILE}" 2>/dev/null | grep -c "TABLE" || true)
if [ "${TABLE_COUNT}" -eq 0 ]; then
  echo "ERRO: Dump inválido."
  exit 1
fi
log "Dump válido: ${TABLE_COUNT} tabelas."

# ── 5. Confirmar restauração ─────────────────────────────────────
echo ""
echo "====================================="
echo "  ATENÇÃO: OPERAÇÃO DESTRUTIVA"
echo "====================================="
echo ""
echo "Este comando vai restaurar ${TABLE_COUNT} tabelas no banco de destino."
echo "Dados existentes nas tabelas restauradas serão SOBRESCRITOS."
echo ""

if [ -t 0 ]; then
  read -r -p "Deseja continuar? (digite 'sim' para confirmar): " CONFIRM
  if [ "${CONFIRM}" != "sim" ]; then
    echo "Cancelado pelo usuário."
    exit 0
  fi
else
  log "Modo não-interativo: executando sem confirmação."
fi

# ── 6. Restaurar ─────────────────────────────────────────────────
log "Iniciando pg_restore..."
pg_restore \
  --dbname="${TARGET_DB}" \
  --no-owner \
  --no-privileges \
  --clean \
  --if-exists \
  --verbose \
  "${DUMP_FILE}" 2>&1 | tail -20

log "Restauração concluída com sucesso."
