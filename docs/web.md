# Web

## Estrutura atual

- `web/src/app/`
  router e provider de autenticacao
- `web/src/shared/`
  cliente HTTP, contratos compartilhados e helpers reutilizaveis
- `web/src/features/`
  inicio da modularizacao por dominio; a feature de tarefas ja extraiu configuracoes e helpers fora da pagina
- `web/src/pages/`
  ainda concentra parte do legado, com foco de reforma em `TaskDetail.jsx`

## Melhorias aplicadas

- `web/src/shared/api/http-client.js` agora entende o envelope `{ data }` do backend
- erros leem `error.message` de forma consistente
- auth passou a consumir contratos compartilhados de permissao
- logica de permissao foi extraida para `web/src/shared/auth/permissions.js`
- testes unitarios cobrem cliente HTTP e resolucao de permissoes

## Executar

- `npm run dev --prefix web`
- `npm run build --prefix web`
- `npm run test --prefix web -- --run`

## Diretriz de evolucao

- mover fluxo de `TaskDetail` para hooks/controladores e componentes de secao
- consolidar estados `loading/error/empty`
- continuar removendo regra de negocio da camada visual
