# Desenvolvimento

## Setup

1. `npm install`
2. `npm run install:all`
3. `cd mobile && flutter pub get`
4. copie `server/.env.example` para `server/.env` quando precisar de configuracao persistente

## Scripts da raiz

- `npm run dev`
  sobe backend e web
- `npm run dev:mobile`
  inicia o Flutter apontando para a API local
- `npm run sync:contracts`
  regenera contratos Dart consumidos no mobile
- `npm test`
  roda testes de backend, web e mobile
- `npm run package:local`
  build do web + executavel local

## Smoke checks recomendados

- `npm test`
- `npm run build --prefix web`
- `cd mobile && flutter analyze`
- subir o backend e validar `/api/health`
