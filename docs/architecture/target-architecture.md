# Arquitetura-Alvo

## Principios

- modularidade por dominio, nao por tipo de arquivo apenas
- contratos explicitos e padrao de resposta consistente
- infraestrutura isolada de regra de negocio
- configuracao centralizada e segura
- dual database mantido por custo-beneficio, mas encapsulado
- shared contracts como fonte unica para permissoes e enums de negocio

## Monorepo

### Estrutura alvo

- `packages/contracts/`
  Fonte unica de permissoes, papeis reservados e enums de negocio.
- `server/src/`
  Aplicacao backend modular.
- `web/src/`
  Front modular por feature/dominio.
- `mobile/lib/`
  Base mobile separada entre `core/` e `features/`.
- `docs/`
  Arquitetura, ADRs, runbooks e convencoes.

### Orquestracao do monorepo

- scripts da raiz orquestram `server`, `web` e `mobile` sem esconder o fato de que sao stacks diferentes
- `packages/contracts` e a fonte unica de contratos compartilhados
- mobile continua gerenciado por Flutter, mas consome contratos Dart gerados a partir da camada compartilhada

## Backend

### Camadas

- `config/`
  leitura e validacao de ambiente, portas, CORS, JWT, PDF e URLs publicas
- `core/`
  erros, resposta HTTP, auth, autorizacao, validacao, logging
- `infrastructure/`
  banco, adapter SQLite/Postgres, PDF renderer/cache
- `modules/`
  auth, summary, users, roles, clients, products, task-types, templates, equipments, tasks, reports, budgets, public

### Padroes

- routers finos
- services contendo orquestracao de caso de uso
- repositories encapsulando SQL
- mappers para normalizacao de payload/row
- policies para autorizacao
- responses padronizadas em envelope: `{ data, meta }`
- erros padronizados em envelope: `{ error: { code, message, details } }`

### Persistencia

- manter SQLite para execucao local/offline e Postgres para banco remoto
- nao introduzir ORM agora
- encapsular adapter atual como infraestrutura e remover conhecimento de SQL do bootstrap HTTP

Racional:

- o sistema ja depende fortemente do fluxo local/empacotado
- introduzir ORM agora aumenta custo e risco sem eliminar a necessidade de compatibilidade dual
- repository + adapter atual bem isolado entrega melhor custo-beneficio

## Web

### Estrutura alvo

- `app/`
  providers, router, layout, boot
- `features/auth/`
- `features/dashboard/`
- `features/resources/`
  telas CRUD simples reaproveitaveis
- `features/tasks/`
  controller, services, tabs e componentes do fluxo de tarefa
- `features/users/`
- `shared/`
  http client, form controls, async states, utils, styles, contracts

### Regras

- logica de carregamento/orquestracao em hooks/controllers de feature
- componentes visuais sem fetch direto
- auth centralizada no app
- guards de rota baseados em permissoes do contrato compartilhado
- estados de loading/error/empty reutilizaveis

## Mobile

### Estrutura alvo

- `core/config/`
- `core/network/`
- `core/auth/`
- `core/contracts/generated/`
- `features/<dominio>/data/`
- `features/<dominio>/presentation/`
- `shared/widgets/`

### Regras

- IO HTTP fora de widgets
- auth e session isoladas no core
- controllers/view-models para fluxos criticos
- componentes reutilizaveis para loading/error/form
- configuracao da API por `dart-define`, com heuristicas de debug local e sem URL de producao hardcoded

## Contratos Compartilhados

- permissao e role defaults centralizados em JSON na raiz compartilhada
- enums de negocio centralizados: status de tarefa, prioridade, status de relatorio, status de orcamento, modos de assinatura
- geracao automatica de contrato Dart para mobile
- backend e web consomem a mesma origem compartilhada

## Convencoes

### Naming

- arquivos backend em `kebab-case`
- modulos por dominio com nomes explicitos (`tasks`, `budgets`, `report-templates`)
- DTOs com sufixos `Payload`, `Dto` ou `Response` apenas quando agregam valor real
- repositorios com sufixo `repository`
- servicos com sufixo `service`

### Responses da API

- sucesso:
  `{ "data": ... }`
- sucesso com metadata:
  `{ "data": ..., "meta": { ... } }`
- erro:
  `{ "error": { "code": "validation_error", "message": "...", "details": [...] } }`

### Auth

- JWT com secret obrigatorio em producao
- middleware de autenticacao separado do middleware de autorizacao
- autorizacao por permissao, com fallback `manage_* => view_*`
- usuario autenticado normalizado em uma shape unica

### Logs

- logger central com niveis basicos
- erros inesperados com stack apenas no servidor
- HTTP errors sem vazar detalhes internos ao cliente

## Estrategia de Reforma

1. Criar shared contracts e infraestrutura central.
2. Desmontar o backend monolitico sem quebrar os contratos usados pelos clientes.
3. Reorganizar o web em torno do fluxo de tarefas e da infraestrutura de auth/HTTP.
4. Reorganizar o mobile em torno do core compartilhado e do fluxo de tarefas.
5. Adicionar testes e documentacao como parte do fechamento, nao como pos-processo.
