# Tratamento de Erros e Auditoria

## Diagnostico

Antes desta reforma, backend, web e mobile tratavam falhas de forma inconsistente:

- o backend devolvia `AppError.message` diretamente para o cliente
- web e mobile exibiam `error.message` ou `error.toString()` sem normalizacao central
- detalhes tecnicos apareciam na interface em cenarios de timeout, falha de conexao e erro interno
- nao existia persistencia estruturada para erros nem trilha administrativa de auditoria
- a rastreabilidade de acoes relevantes dependia de leitura manual de banco e codigo

## Arquitetura adotada

### Backend

- `server/src/modules/monitoring/monitoring.service.js`
  - request ID por requisicao
  - mapeamento central de mensagens amigaveis
  - sanitizacao de payloads e contexto
  - gravacao de `error_logs` e `event_logs`
- `server/src/core/http/error-handler.js`
  - nao expõe mensagem tecnica para o usuario final
  - grava o erro no storage interno
  - responde com envelope consistente contendo `code`, `category`, `message` e `requestId`
- `server/src/app/create-app.js`
  - expõe `POST /api/monitoring/client-errors`
  - expõe area admin em `GET /api/admin/error-logs`, `GET /api/admin/error-logs/:id`, `POST /api/admin/error-logs/:id/resolve`, `GET /api/admin/event-logs`, `GET /api/admin/event-logs/:id`
- `server/db.js`
  - tabelas `error_logs` e `event_logs` em SQLite e PostgreSQL

### Web

- `web/src/shared/errors/error-normalizer.js`
  - traduz erros de API, permissao, autenticacao, conexao e erro inesperado para mensagens amigaveis
- `web/src/shared/api/http-client.js`
  - centraliza chamadas HTTP
  - sempre envia `X-Client-Platform: web`
  - reporta erros do cliente para `/api/monitoring/client-errors`
- `web/src/pages/admin/ErrorLogs.jsx`
  - listagem filtravel, detalhe tecnico e resolucao de logs
- `web/src/pages/admin/EventLogs.jsx`
  - auditoria operacional com busca e detalhe de metadata

### Mobile

- `mobile/lib/core/errors/error_mapper.dart`
  - normalizacao central das falhas para `AppException`
- `mobile/lib/core/errors/error_reporter.dart`
  - envio de erro do cliente para `/api/monitoring/client-errors`
- `mobile/lib/screens/error_logs_screen.dart`
  - acesso administrativo basico aos logs de erro
- `mobile/lib/screens/event_logs_screen.dart`
  - acesso administrativo basico ao log de eventos

## Regras de UX

- usuario comum recebe apenas mensagem amigavel
- detalhes tecnicos ficam restritos ao storage interno e ao painel admin
- autenticacao expirada mostra orientacao de relogin
- conexao e timeout nao exibem stack trace, exception nativa nem mensagem crua da biblioteca HTTP

## Seguranca

- somente administrador acessa rotas e telas de logs
- payloads passam por sanitizacao de chaves sensiveis
- tokens, segredos, cookies e senhas nao entram no log em texto puro
- o `requestId` conecta a mensagem amigavel exibida ao usuario com o detalhe tecnico no painel admin

## Eventos auditados

Padrao atual:

- `AUTH_LOGIN_SUCCESS`
- `AUTH_LOGIN_FAILURE`
- `AUTH_REGISTER_SUCCESS`
- `AUTH_REGISTER_FAILURE`
- `*_CREATED`
- `*_UPDATED`
- `*_DELETED`
- `*_PDF_EXPORTED`
- `*_PUBLIC_LINK_CREATED`
- `TASK_EQUIPMENT_ATTACHED`
- `TASK_EQUIPMENT_DETACHED`
- `ERROR_LOG_RESOLVED`

O padrao pode crescer por modulo sem quebrar o contrato central de auditoria.
