# Sistema Empresa (MVP)

Este projeto tem dois apps:
- `server`: API em Node/Express + SQLite.
- `web`: interface React (Vite).

## Como rodar
1) Instale Node.js LTS.
2) Instale as dependencias:
   - `npm install`
   - `npm run install:all`
3) Rode em desenvolvimento:
   - `npm run dev`

A API sobe em `http://localhost:3001` e o front em `http://localhost:5173`.

## Pastas
- `server/`: API e banco SQLite (`server/data.db`).
- `web/`: app React.

## Observacoes
- O banco e criado automaticamente no primeiro start.
- Esta versao foca em tarefas com relatorios customizados e orcamentos vinculados.
- Para autocomplete de endereco via Google Maps, crie `web/.env` com `VITE_GOOGLE_MAPS_API_KEY`.

## Banco remoto (Neon)
Se quiser manter o site local e hospedar apenas o banco:
1) Crie um banco no Neon e copie a `DATABASE_URL`.
2) Crie `server/.env` com:
   - `DATABASE_URL=postgresql://...`
   - `DATABASE_SSL=true` (se o Neon exigir TLS)
3) Migre os dados atuais do SQLite:
   - `cd server`
   - `npm run migrate:neon`

Se o banco Neon ja tiver dados e voce quiser sobrescrever, rode com:
`RESET_DB=1 npm run migrate:neon`
