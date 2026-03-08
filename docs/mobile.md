# Mobile

## Estrutura atual

- `mobile/lib/core/`
  configuracao, auth, network e contratos gerados
- `mobile/lib/screens/`
  legado de telas, agora parcialmente desacoplado do core
- `mobile/test/`
  testes unitarios para a resolucao de permissoes

## Melhorias aplicadas

- URL remota hardcoded foi removida
- `API_URL` agora vem de `dart-define`; em debug usa fallback local pragmático
- auth e API client passaram a respeitar o envelope `{ data }`
- contratos de permissao e enums de dominio passaram a vir da fonte compartilhada
- `task_detail_screen.dart` parou de repetir enums de dominio no widget tree

## Executar

- `cd mobile && flutter pub get`
- `cd mobile && flutter analyze`
- `cd mobile && flutter test`
- da raiz: `npm run dev:mobile` ou `npm run test:mobile`

## Observacoes

- para builds de release, `API_URL` deve ser informado explicitamente
- a base ainda tem telas grandes; o proximo passo e migrar `screens/` para `features/<dominio>/presentation`
