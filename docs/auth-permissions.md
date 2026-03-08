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
