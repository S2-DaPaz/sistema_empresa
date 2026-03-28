# Auth e Permissoes

## Fonte unica

- `packages/contracts/permissions.json`
- geracao Dart: `mobile/lib/core/contracts/generated/permissions.g.dart`
- consumo web: `web/src/shared/contracts/permissions.js`
- consumo backend: `server/src/config/contracts.js`

## Regras

- administracao e `role_is_admin=true` recebem acesso total
- `manage_*` implica `view_*`
- defaults de papel existem para:
  - `administracao`
  - `gestor`
  - `tecnico`
  - `visitante`

## Fluxo

1. backend autentica com JWT e normaliza o usuario autenticado
2. backend calcula permissoes efetivas
3. web e mobile usam o mesmo contrato compartilhado para fallback e renderizacao de guards

## Garantias adicionadas

- backend, web e mobile agora testam a mesma regra de fallback de permissao
- foi corrigido o bug em que `role_permissions = null` derrubava as permissoes default no backend

## Regra especial do visitante

- `visitante` nao recebe mais `view_*` por default no contrato compartilhado
- o visitante pode navegar pela estrutura visual do app mobile, mas nao pode ler dados operacionais reais
- o mobile separa acesso de tela e leitura de dados via guards centrais em `mobile/lib/services/permissions.dart`
- o backend reforca essa regra com isolamento em `server/src/core/security/visitor-data-access.js`
- permissoes explicitas em um usuario visitante nao devem reabrir leitura operacional; a blindagem principal continua no papel + backend
