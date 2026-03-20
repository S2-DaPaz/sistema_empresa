# Desenvolvimento

## Setup

1. `npm install`
2. `npm run install:all`
3. `cd mobile && flutter pub get`
4. copie `server/.env.example` para `server/.env` quando precisar de configuracao persistente

## Scripts da raiz

- `npm run dev`
  sobe backend e web
- `npm run dev:mobile`
  inicia o Flutter apontando para a API local
- `npm run migrate:server`
  aplica as migracoes versionadas do backend
- `npm run seed:server`
  executa o seed controlado do backend
- `npm run analyze:mobile`
  roda analise estatica do Flutter
- `npm run ci:check`
  replica localmente o conjunto minimo validado pela pipeline
- `npm run sync:contracts`
  regenera contratos Dart consumidos no mobile
- `npm test`
  roda testes de backend, web e mobile
- `npm run package:local`
  build do web + executavel local

## Banco e migracoes

- as migracoes vivem em `server/src/infrastructure/database/migrations/`
- a tabela `schema_migrations` registra quais versoes ja foram aplicadas
- `npm run migrate:server` pode ser usado em desenvolvimento, homologacao e producao
- `npm run seed:server` aplica apenas o seed base e deve ser executado conscientemente

## Jobs em background

- o job runner roda junto com a API quando `JOBS_ENABLED=true`
- jobs atuais: envio de e-mail e aquecimento de cache de PDF
- configuracao principal:
  - `JOBS_POLL_MS`
  - `JOBS_BATCH_SIZE`
  - `JOBS_MAX_ATTEMPTS`
  - `JOBS_RETRY_DELAY_SECONDS`
  - `JOBS_ENCRYPTION_SECRET`

## Pipeline minima

- servidor: `npm test --prefix server`
- web: `npm run build --prefix web`
- mobile: `flutter analyze` e `flutter test`
- workflow: `.github/workflows/ci.yml`

## Smoke checks recomendados

- `npm test`
- `npm run build --prefix web`
- `cd mobile && flutter analyze`
- subir o backend e validar `/api/health`
