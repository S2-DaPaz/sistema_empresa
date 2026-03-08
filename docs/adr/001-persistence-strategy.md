# ADR 001 - Manter Estrategia Dual SQLite + PostgreSQL

## Status

Aceita

## Contexto

O sistema ja suporta execucao local empacotada e uso opcional de banco remoto PostgreSQL/Neon.

O fluxo local e parte do produto, nao apenas ambiente de desenvolvimento. Forcar uma migracao para ORM ou remover SQLite agora aumentaria custo, risco e superficie de regressao sem retorno proporcional.

## Decisao

Manter a compatibilidade dual SQLite + PostgreSQL.

A reforma vai:

- preservar o adapter cross-database
- mover schema e compatibilidade para infraestrutura dedicada
- introduzir repositories por dominio acima do adapter
- documentar melhor a evolucao do schema

## Consequencias

### Positivas

- preserva a estrategia operacional ja usada pelo produto
- reduz risco de regressao no empacotamento local
- permite refatorar arquitetura sem uma migracao de dados agressiva

### Negativas

- exige disciplina maior na camada de persistencia
- nao entrega features de ORM como migrations e typing automaticamente

## Racional

Neste contexto, a melhor troca entre robustez, custo e velocidade e encapsular melhor a persistencia existente, nao substitui-la por uma stack nova.
