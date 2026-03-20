# Backend

## Estrutura atual

- `server/src/config/`
  configuracao centralizada de ambiente e contratos compartilhados
- `server/src/core/`
  erros, auth, autorizacao, response envelope e utilitarios transversais
- `server/src/infrastructure/`
  ponte para a camada de persistencia atual
- `server/src/modules/`
  modulos por dominio: auth, users, roles, resources, tasks, reports, budgets, public, equipments, summary
- `server/test/`
  testes da espinha dorsal de auth, env e permissoes

## Contrato HTTP

- sucesso: `{ data: ... }`
- sucesso com metadados: `{ data: ..., meta: ... }`
- erro: `{ error: { code, message, details } }`

Isso eliminou a mistura anterior de payloads crus, strings de erro avulsas e contratos divergentes entre rotas.

## Autenticacao e autorizacao

- JWT assinado com `JWT_SECRET`
- `JWT_SECRET` e obrigatorio em producao
- em desenvolvimento, se ausente, um secret aleatorio de runtime e gerado para evitar fallback inseguro persistente
- permissao `manage_*` satisfaz a respectiva `view_*`
- defaults de papeis e permissoes vem de `packages/contracts/permissions.json`

## Persistencia

- a compatibilidade dual SQLite/PostgreSQL foi mantida por custo-beneficio
- a conexao agora vive em `server/src/infrastructure/database/connection.js`
- o schema foi extraido para migracoes versionadas em `server/src/infrastructure/database/migrations/`
- `server/db.js` virou apenas uma fachada de compatibilidade para nao quebrar os modulos antigos
- a tabela `schema_migrations` remove a evolucao manual de schema espalhada pela aplicacao

## Jobs em background

- `server/src/infrastructure/jobs/job.service.js` processa a fila local persistida
- `server/src/infrastructure/jobs/queued-email.service.js` desacopla envio de e-mail da requisicao HTTP
- aquecimento de PDF de tarefa e orcamento agora entra em fila via `background_jobs`
- cada job registra tentativas, ultimo erro, requestId e status para rastreabilidade

## Scripts operacionais

- `npm run migrate --prefix server`
- `npm run seed:base --prefix server`
- `npm test --prefix server`

## Operacao local

- `npm run dev --prefix server`
- `npm test --prefix server`
- `node server/index.js`

## Proximos cortes recomendados

- quebrar `public.service.js` em renderer, cache e public-link service
- ampliar o job runner com dashboard operacional e dead-letter handling
- adicionar testes de integracao para rotas criticas de tarefas e orcamentos
