# Backup e Restore — PostgreSQL (Neon)

## Visão Geral da Arquitetura

```
┌─────────────────────┐     ┌──────────────────┐     ┌──────────────┐
│   GitHub Actions     │────>│  pg_dump (Neon)   │────>│  .dump file  │
│   (cron diário       │     │  conexão direta   │     │              │
│    03:00 UTC)        │     └──────────────────┘     └──────┬───────┘
│                      │                                      │
│   ou workflow_dispatch│     ┌──────────────────┐            │
│   (manual)           │     │  GPG AES-256      │<───────────┘
│                      │     │  (criptografia)   │
│                      │     └───────┬──────────┘
│                      │             │
│                      │     ┌───────▼──────────┐
│                      │────>│  Google Drive     │
│                      │     │  (upload + ret.)  │
└─────────┬────────────┘     └──────────────────┘
          │ webhook (opcional)
          ▼
┌─────────────────────┐
│   API do Sistema     │
│   (histórico/obs.)   │
└─────────────────────┘
```

### Por que o agendamento fica no GitHub Actions e não na API?

1. **Hospedagens gratuitas dormem** — o processo da API pode estar inativo quando o backup precisa rodar.
2. **Independência** — o backup roda mesmo com a API fora do ar.
3. **Previsibilidade** — GitHub Actions tem SLA e monitoramento de execução próprio.
4. **Segurança** — as credenciais do banco ficam apenas nos Secrets do GitHub, não no runtime da aplicação.

---

## Configuração Completa

### 1. Obter DATABASE_URL_DIRECT no Neon

No painel do Neon:
1. Acesse seu projeto > **Dashboard**.
2. Em **Connection Details**, selecione **Direct Connection** (não Pooled).
3. Copie a connection string. Ela terá formato:
   ```
   postgresql://user:pass@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require
   ```
   > A URL **direta** NÃO contém `-pooler` no hostname.

### 2. Criar Service Account no Google Cloud

1. Acesse [Google Cloud Console](https://console.cloud.google.com/).
2. Crie um projeto (ou use existente).
3. Ative a **Google Drive API** em APIs & Services > Library.
4. Vá em **IAM & Admin > Service Accounts** > **Create Service Account**.
5. Dê um nome (ex: `backup-drive`), avance.
6. Em **Keys** > **Add Key** > **Create new key** > **JSON**. Salve o arquivo.
7. Converta o JSON para Base64:
   ```bash
   base64 -w 0 service-account.json
   ```

### 3. Configurar pasta no Google Drive

1. Crie uma pasta no Google Drive (ex: `backups-sistema-empresa`).
2. Copie o **ID da pasta** da URL: `https://drive.google.com/drive/folders/<ESTE_ID>`.
3. **Compartilhe** a pasta com o email da service account (campo `client_email` do JSON), com permissão de **Editor**.

### 4. Configurar Secrets no GitHub

No repositório > **Settings** > **Secrets and variables** > **Actions**:

| Secret | Descrição |
|--------|-----------|
| `DATABASE_URL_DIRECT` | Connection string direta do Neon (sem pooler) |
| `BACKUP_ENCRYPTION_PASSPHRASE` | Senha forte para criptografia GPG AES-256 |
| `GDRIVE_FOLDER_ID` | ID da pasta no Google Drive |
| `GDRIVE_SERVICE_ACCOUNT_JSON_B64` | JSON da service account em Base64 |
| `BACKUP_WEBHOOK_SECRET` | Segredo para o webhook (opcional) |

**Variables** (Settings > Variables > Actions):

| Variable | Descrição | Padrão |
|----------|-----------|--------|
| `APP_BASE_URL` | URL base da API para webhook | (vazio = desativado) |
| `BACKUP_RETENTION_COUNT` | Máximo de backups no Drive | `30` |

### 5. Gerar senha de criptografia

```bash
openssl rand -base64 32
```
Use essa saída como `BACKUP_ENCRYPTION_PASSPHRASE`. **Guarde em local seguro** — sem ela, os backups são irrecuperáveis.

---

## Como Executar Backup

### Automático (diário)
Já configurado. O workflow roda diariamente às 03:00 UTC (00:00 BRT).

### Manual via GitHub Actions
1. Vá em **Actions** > **Backup PostgreSQL (Neon)**.
2. Clique em **Run workflow**.
3. Opcionalmente, altere o ambiente.
4. Clique em **Run workflow**.

### Manual via API (admin)
```bash
curl -X POST https://seu-app.com/api/backups/trigger \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json"
```
> Isto registra a intenção de backup no histórico. O backup real precisa ser disparado no GitHub Actions.

### Consultar histórico
```bash
curl https://seu-app.com/api/backups \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

---

## Como Restaurar um Backup

### Pré-requisitos
- `gpg` instalado
- `pg_restore` instalado (PostgreSQL client)
- Senha de criptografia (`BACKUP_ENCRYPTION_PASSPHRASE`)
- Arquivo `.dump.gpg` baixado do Google Drive

### Passo a passo

#### 1. Baixar o arquivo do Google Drive
Acesse a pasta de backups no Google Drive e baixe:
- `backup_production_YYYY-MM-DD_HH-MM-SS_<runid>.dump.gpg`
- `backup_production_YYYY-MM-DD_HH-MM-SS_<runid>.sha256` (opcional, para verificação)

#### 2. Verificar integridade (opcional)
```bash
export BACKUP_ENCRYPTION_PASSPHRASE="sua-senha"
bash scripts/verify-backup.sh backup_production_2026-03-24_03-00-00_123.dump.gpg
```

#### 3. Restaurar
```bash
export BACKUP_ENCRYPTION_PASSPHRASE="sua-senha"
bash scripts/restore-backup.sh \
  backup_production_2026-03-24_03-00-00_123.dump.gpg \
  "postgresql://user:pass@host/banco_destino?sslmode=require"
```

O script irá:
1. Verificar SHA-256 (se `.sha256` estiver presente).
2. Descriptografar com GPG.
3. Validar o dump com `pg_restore --list`.
4. Pedir confirmação (modo interativo).
5. Restaurar no banco de destino com `--clean --if-exists`.

#### 4. Restaurar para branch Neon separado
No Neon, crie um branch a partir do projeto:
1. Dashboard > **Branches** > **Create Branch**.
2. Use a connection string do novo branch como destino no `restore-backup.sh`.

### Restauração manual (sem script)
```bash
# Descriptografar
echo "SUA_SENHA" | gpg --batch --passphrase-fd 0 --decrypt \
  --output backup.dump backup.dump.gpg

# Validar
pg_restore --list backup.dump

# Restaurar
pg_restore --dbname="postgresql://..." --no-owner --no-privileges \
  --clean --if-exists backup.dump
```

---

## Política de Retenção

- **Implementada**: retenção por quantidade total configurável.
- **Padrão**: 30 backups (1 mês de backups diários).
- **Configurável** via variável `BACKUP_RETENTION_COUNT` no GitHub Actions.
- Quando excede o limite, os backups mais antigos são removidos do Google Drive junto com seus arquivos associados (.sha256, .manifest.json).

### Evolução futura (não implementada)
- Retenção por classe temporal: 7 diários + 4 semanais + 3 mensais.
- Requer lógica adicional para classificar backups por período.

---

## Riscos e Limitações

| Risco | Mitigação |
|-------|-----------|
| Neon Free pode ter janelas de manutenção | O dump falha e o workflow reporta erro visível no GitHub |
| Perda da senha de criptografia | **Irrecuperável**. Mantenha a senha em cofre seguro (1Password, Bitwarden, etc.) |
| Service account do Google comprometida | Revogue as credenciais imediatamente no GCP e gere novas |
| GitHub Actions indisponível | Backup pode ser executado manualmente com os scripts locais |
| Backup grande demais para Drive gratuito | Google Drive gratuito oferece 15GB; monitore o uso |
| Webhook falha | O webhook é `continue-on-error`; não impede o backup |

---

## Checklist Operacional

- [ ] `DATABASE_URL_DIRECT` configurado (conexão direta, sem pooler)
- [ ] `BACKUP_ENCRYPTION_PASSPHRASE` gerada e guardada em cofre seguro
- [ ] Service account do Google criada com Drive API ativada
- [ ] Pasta do Drive compartilhada com a service account
- [ ] `GDRIVE_FOLDER_ID` configurado
- [ ] `GDRIVE_SERVICE_ACCOUNT_JSON_B64` configurado
- [ ] Primeiro backup executado manualmente e verificado
- [ ] Teste de restore realizado em banco de teste
- [ ] Equipe sabe onde encontrar a senha de criptografia
