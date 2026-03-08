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
- o adapter existente em `server/db.js` ainda e a base da persistencia
- a reforma atual moveu bootstrap HTTP, auth, contratos e modulos para `server/src/`, reduzindo o acoplamento do antigo `server/index.js`

## Operacao local

- `npm run dev --prefix server`
- `npm test --prefix server`
- `node server/index.js`

## Proximos cortes recomendados

- extrair `server/db.js` em adapters/repositorios menores com migracoes formais
- quebrar `public.service.js` em renderer, cache e public-link service
- adicionar testes de integracao para rotas criticas de tarefas e orcamentos
