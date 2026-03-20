# RV Sistema Empresa

Monorepo para operacao tecnica com tarefas, relatorios customizados, orcamentos vinculados, links publicos e distribuicao local Windows.

## Estrutura

- `server/`
  API Node.js + Express com persistencia dual SQLite/PostgreSQL
- `web/`
  cliente React + Vite
- `mobile/`
  aplicativo Flutter
- `packages/contracts/`
  contratos compartilhados de permissao e enums de dominio
- `launcher/` e `installer/`
  empacotamento local Windows
- `docs/`
  auditoria, arquitetura e guias operacionais

## O que mudou nesta reforma

- backend modularizado em `server/src/`
- persistencia centralizada em `server/src/infrastructure/database/` com migracoes versionadas
- jobs em background para envio de e-mail e aquecimento de PDF, removendo trabalho pesado da thread HTTP
- respostas e erros da API padronizados
- contratos de permissao e enums centralizados
- auth e cliente HTTP alinhados entre backend, web e mobile
- gestao de conta completa com cadastro, verificacao por e-mail, recuperacao de senha e refresh token
- dashboard operacional com metricas reais de operacao
- CI minima em `.github/workflows/ci.yml`
- launcher local passa a subir a API real, nao apenas arquivos estaticos
- testes adicionados nas tres frentes
- ambiente documentado com `.env.example`

## Como rodar

### Backend + web

1. `npm install`
2. `npm run install:all`
3. `npm run dev`

API: `http://localhost:3001`  
Web: `http://localhost:5173`

### Mobile

1. `cd mobile`
2. `flutter pub get`
3. `flutter run --dart-define API_URL=http://127.0.0.1:3001`

Na raiz, o atalho equivalente e `npm run dev:mobile`.

## Testes e validação

- `npm test`
- `npm run build --prefix web`
- `cd mobile && flutter analyze`
- `npm run ci:check`

## Configuração

- backend: copie `server/.env.example` para `server/.env`
- web: opcionalmente copie `web/.env.example` para `web/.env`
- launcher Windows: ajuste `launcher/default.env` ou o arquivo gerado em `%APPDATA%\\RV Sistema Empresa\\server.env`

Importante:

- em producao, `JWT_SECRET` e obrigatorio
- para fluxo completo de autenticacao, configure `EMAIL_PROVIDER`, remetente e o provider de e-mail; em Render, a API HTTP da Brevo e a opcao recomendada
- para o primeiro admin local, defina `ADMIN_PASSWORD`; se nao definir, o backend gera uma senha aleatoria e registra no log de bootstrap
- para builds mobile de release, `API_URL` deve ser informado explicitamente

## Comandos principais

- `npm run sync:contracts`
- `npm run dev`
- `npm run dev:mobile`
- `npm run migrate:server`
- `npm run seed:server`
- `npm run ci:check`
- `npm test`
- `npm run package:local`
- `npm run installer:local`

## Documentação

- `docs/architecture/audit.md`
- `docs/architecture/target-architecture.md`
- `docs/backend.md`
- `docs/web.md`
- `docs/mobile.md`
- `docs/auth-permissions.md`
- `docs/authentication.md`
- `docs/development.md`

## Roadmap tecnico recomendado

- concluir a segunda etapa da decomposicao de `TaskDetail` no web e mobile, extraindo controllers e hooks por subfluxo
- ampliar contratos compartilhados para DTOs tipados das APIs de tarefas, relatorios e monitoramento
- preparar storage externo para anexos, fotos e artefatos publicos com limpeza de orfaos
- adicionar testes E2E para fluxos criticos de tarefa, relatorio e orcamento
