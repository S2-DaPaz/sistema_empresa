# Auditoria Tecnica da Base Atual

## Resumo Executivo

O repositorio nao esta em estado de colapso funcional, mas esta em estado de risco arquitetural alto.

Os sintomas principais sao:

- backend monolitico com concentracao extrema de responsabilidade em [`server/index.js`](/d:/MEUS%20PROJETOS/sistema%20empresa2/server/index.js)
- duplicacao transversal de regras de permissao e papeis entre Node, React e Flutter
- contratos de API informais, sem padrao de resposta, sem tipagem compartilhada e com validacao fraca
- front web e mobile organizados por telas, nao por dominio, com arquivos gigantes e logica de negocio embutida na camada de apresentacao
- configuracao por ambiente inconsistente, incluindo URL remota hardcoded no mobile e fallback inseguro de JWT no backend
- ausencia pratica de testes automatizados e de guardrails de DX/CI
- empacotamento local com sinais de inconsistencias entre launcher, API e front

## Mapa Atual do Monorepo

### Raiz

- `server/`: API Node + Express com SQLite/Postgres via adapter manual
- `web/`: React 18 + Vite + React Router
- `mobile/`: Flutter sem arquitetura de estado formal
- `launcher/`: bootstrap Windows para distribuicao local
- `installer/`: scripts de empacotamento Windows
- `docs/skills/`: documentos auxiliares, nao arquitetura do produto

### Backend

- Um unico arquivo monolitico com 3.086 linhas em [`server/index.js`](/d:/MEUS%20PROJETOS/sistema%20empresa2/server/index.js)
- Schema, auth, autorizacao, CRUDs genericos, regras de dominio, PDF, cache, paginas publicas, links publicos e bootstrap HTTP no mesmo modulo
- `server/db.js` mistura schema, migracoes oportunistas e adapter cross-database

### Web

- Estrutura por `pages/`, `components/` e `contexts/`
- Auth, permissoes e HTTP espalhados em arquivos globais simples
- Paginas criticas concentram estado, IO, mapeamento de contrato e renderizacao
- Principal hotspot: [`web/src/pages/TaskDetail.jsx`](/d:/MEUS%20PROJETOS/sistema%20empresa2/web/src/pages/TaskDetail.jsx) com 53 KB

### Mobile

- Estrutura por `screens/`, `services/`, `widgets/`, `utils/`
- Sem camada de dominio formal, sem repositorios, sem state management consistente
- Principal hotspot: [`mobile/lib/screens/task_detail_screen.dart`](/d:/MEUS%20PROJETOS/sistema%20empresa2/mobile/lib/screens/task_detail_screen.dart) com 55 KB

## Dependencias e Decisoes Atuais

### Backend

- `express`, `cors`, `dotenv`, `jsonwebtoken`, `bcryptjs`
- `sqlite`, `sqlite3`, `pg`
- `puppeteer`

### Web

- React 18
- React Router
- Vite

### Mobile

- `http` e `dio` ao mesmo tempo, sem estrategia clara de uso
- `shared_preferences`, `image_picker`, `printing`, `signature`, `share_plus`

## Achados Criticos

### 1. Backend com acoplamento estrutural inaceitavel

Evidencias:

- [`server/index.js`](/d:/MEUS%20PROJETOS/sistema%20empresa2/server/index.js) concentra bootstrap, middlewares, auth, autorizacao, repositorio ad-hoc, servicos, renderizacao HTML/PDF e rotas publicas
- funcoes utilitarias de diferentes camadas vivem no mesmo escopo global
- tratamento de erro repetitivo e inconsistente

Impacto:

- manutencao lenta
- regressao facil
- baixo isolamento para testes
- mudancas de auth/PDF/tarefas afetam o servidor inteiro

Classificacao:

- `Reestruturar` imediatamente

### 2. Seguranca basica abaixo do minimo esperado

Evidencias:

- fallback inseguro de JWT em [`server/index.js:14`](/d:/MEUS%20PROJETOS/sistema%20empresa2/server/index.js#L14)
- admin default com senha fraca em [`server/index.js:289`](/d:/MEUS%20PROJETOS/sistema%20empresa2/server/index.js#L289)
- `cors()` aberto sem whitelist/config em [`server/index.js:1682`](/d:/MEUS%20PROJETOS/sistema%20empresa2/server/index.js#L1682)
- validacao de payload apenas por campos obrigatorios em grande parte das rotas
- exposicao de endpoints publicos sem padrao formal de expiracao/limite alem do token

Impacto:

- superficie de ataque desnecessaria
- configuracao insegura por default
- inconsistencias de autorizacao mais dificeis de auditar

Classificacao:

- `Reescrever` a camada de configuracao e `refatorar` auth/autorizacao

### 3. Contratos duplicados e inconsistentes entre camadas

Evidencias:

- permissoes declaradas no backend, React e Flutter
- defaults de papeis repetidos no backend, React e Flutter
- statuses e enums de negocio espalhados
- API sem envelope padrao de sucesso/erro

Impacto:

- drift entre clientes e servidor
- bugs silenciosos quando um papel ou permissao muda em apenas uma camada
- alta dificuldade para evoluir auth/permissoes

Classificacao:

- `Reestruturar` com camada compartilhada de contratos

### 4. Web com pagina critica oversized e sem separacao de concerns

Evidencias:

- [`web/src/pages/TaskDetail.jsx`](/d:/MEUS%20PROJETOS/sistema%20empresa2/web/src/pages/TaskDetail.jsx) mistura carregamento, DTOs, regras de relatorio, orcamento, compartilhamento publico, exportacao PDF e apresentacao
- [`web/src/contexts/AuthContext.jsx`](/d:/MEUS%20PROJETOS/sistema%20empresa2/web/src/contexts/AuthContext.jsx) replica logica de permissao do servidor
- [`web/src/api.js`](/d:/MEUS%20PROJETOS/sistema%20empresa2/web/src/api.js) e minimalista demais para uma base com auth/erros/contratos

Impacto:

- baixa testabilidade
- dificuldade de reuso
- pages crescem por adicao lateral de features

Classificacao:

- `Reestruturar` a feature de tarefas e `refatorar` a infraestrutura do cliente web

### 5. Mobile com acoplamento entre tela, estado e IO

Evidencias:

- [`mobile/lib/screens/task_detail_screen.dart`](/d:/MEUS%20PROJETOS/sistema%20empresa2/mobile/lib/screens/task_detail_screen.dart) concentra rede, parsing, regra de negocio, autosave, fotos, assinaturas e UI
- `AuthService` e `ApiService` sao singletons globais com responsabilidades misturadas
- URL da API remota hardcoded em [`mobile/lib/services/api_config.dart`](/d:/MEUS%20PROJETOS/sistema%20empresa2/mobile/lib/services/api_config.dart)

Impacto:

- mudancas de contrato exigem revisao manual de varias telas
- testes unitarios ficam caros
- ambiente local e homologacao sao dificeis de padronizar

Classificacao:

- `Reestruturar` a base do mobile e `reescrever` a configuracao HTTP

### 6. Persistencia dual SQLite/Postgres e pragmatica, mas mal encapsulada

Evidencias:

- adapter atual em [`server/db.js`](/d:/MEUS%20PROJETOS/sistema%20empresa2/server/db.js) resolve compatibilidade, mas mistura schema, migracao oportunista e infra
- nao ha migracoes formais nem camada de repositorio por agregado

Impacto:

- dificuldade para validar consistencia
- risco alto ao evoluir schema

Classificacao:

- `Manter` a estrategia dual
- `Refatorar` a encapsulacao e a forma de evolucao do schema

### 7. DX abaixo do necessario para evolucao segura

Evidencias:

- sem testes no backend/web/mobile
- sem CI minima
- sem `.env.example` serio
- README raiz superficial
- root package sem workspaces e sem camada compartilhada

Impacto:

- pouca confianca em refactors
- onboarding lento
- drift operacional entre ambientes

Classificacao:

- `Reestruturar`

### 8. Empacotamento local parece conceitualmente inconsistente

Evidencias:

- [`launcher/index.js`](/d:/MEUS%20PROJETOS/sistema%20empresa2/launcher/index.js) sobe servidor estatico, mas nao sobe explicitamente a API
- `server/index.js` ja sabe servir o front e a API sozinho
- conflitos de responsabilidade entre launcher e backend

Impacto:

- risco real de build local empacotado quebrado ou dependente de configuracao implicita

Classificacao:

- `Refatorar` a estrategia de launcher

## O Que Manter

- uso de Express e Node no backend
- estrategia dual SQLite local + Postgres remoto
- modelo de negocio principal: tarefas, relatorios, orcamentos, links publicos e assinaturas
- Vite + React Router no web
- Flutter no mobile
- ideia de CRUD generico para entidades simples
- geracao de PDF por Puppeteer como integracao isolada

## O Que Refatorar

- camada de banco e repositorios
- auth/autorizacao
- API client do web
- API client do mobile
- organizacao de telas e paginas
- scripts de monorepo
- launcher/packaging

## O Que Reestruturar

- arquitetura do backend por modulos
- web por dominio/feature
- mobile por feature + core
- contratos compartilhados
- documentacao tecnica
- testes e fluxo de verificacao

## O Que Reescrever

- bootstrap do servidor
- configuracao/env/security defaults
- fluxo critico de `TaskDetail` no web
- fluxo critico de `task_detail_screen` no mobile
- cliente HTTP e padrao de resposta/erro

## O Que Remover

- duplicacao manual de permissoes entre camadas
- fallback fixo de `JWT_SECRET`
- hardcode de URL remota no mobile
- catch blocks repetidos retornando strings ad-hoc
- dependencia conceitual entre launcher e suposicoes implcitas da API
