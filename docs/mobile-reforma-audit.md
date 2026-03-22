# Reforma Mobile RV Sistema Empresa

## Objetivo entendido

- Reformar a UI mobile com fidelidade alta às 15 referências em `referencias/`.
- Preservar a lógica real já existente no app Flutter e ampliar o backend quando a nova UI exigir suporte real.
- Centralizar o design system para eliminar o visual híbrido atual e reduzir duplicação de estilo.

## Inventário das referências

- `01` e `01-1`: splash institucional azul com branding limpo.
- `02`: login com header azul curvo, card branco principal e CTA primário largo.
- `03`: cadastro com topo claro, campos iguais ao login e critérios de senha.
- `04`: verificação de e-mail com OTP em 6 caixas, contador e callout informativo.
- `05`: recuperação de senha com variante cromática de alerta e CTA de envio de código.
- `06`: dashboard com header azul alto, busca, atalhos, cards métricos, atividade recente e bottom nav com ação central.
- `07`: inbox de tarefas com tabs de status, agrupamento temporal e cards de prioridade forte.
- `08`: detalhe da tarefa com overview operacional, cliente, endereço, equipamentos, fotos, checklist e CTA fixo.
- `09`: nova tarefa em fluxo focado e objetivo.
- `10`: quadro kanban horizontal com colunas e contadores.
- `11`: clientes com agrupamento alfabético, contadores e badges laterais.
- `12`: detalhe de orçamento com resumo financeiro, aprovação, recusa e envio por WhatsApp.
- `13`: hub "Mais" agrupado por áreas funcionais.
- `14`: perfil com permissões, sessões e status da conta.
- `15`: relatórios com agrupamento por data, faixa lateral colorida e ações rápidas.

## Mapeamento referência -> base real

| Referência | Tela real atual | Estado atual | Ação |
| --- | --- | --- | --- |
| Splash | `mobile/lib/widgets/auth_gate.dart` | Existe, mas ainda simples | Reformar |
| Login / cadastro / OTP / reset | `mobile/lib/screens/login_screen.dart` | Fluxo funcional já existe | Reformar UI e estados |
| Dashboard | `mobile/lib/screens/dashboard_screen.dart` | Dados reais via `/summary` | Reformar e enriquecer payload |
| Tarefas inbox / agenda / board | `mobile/lib/screens/tasks_screen.dart` | Fluxos já existem | Reformar com shell único |
| Detalhe / nova tarefa | `mobile/lib/screens/task_detail_screen.dart` | Fluxo funcional forte, UI desalinhada | Reestruturar overview e entrada |
| Clientes | `mobile/lib/screens/clients_screen.dart` | Lista funcional | Reformar e destacar métricas |
| Perfil do cliente | `mobile/lib/screens/client_profile_screen.dart` | Existe | Aproximar da linguagem nova |
| Orçamentos | `mobile/lib/screens/budgets_screen.dart` | Lista e edição existem | Separar detalhe e reforçar ações |
| Mais | `mobile/lib/screens/more_screen.dart` | Existe | Reformar como hub |
| Perfil | `mobile/lib/screens/profile_screen.dart` | Sessões e reset já existem | Reformar |
| Relatórios | `mobile/lib/screens/reports_screen.dart` | Existe | Reformar |
| PDF viewer | `mobile/lib/screens/pdf_viewer_screen.dart` | Existe | Ajuste visual leve |

## Diagnóstico da base mobile

### Pontos fortes

- Fluxo de autenticação já cobre cadastro, verificação, recuperação, refresh e sessões.
- `task_detail_screen.dart` já suporta relatórios, fotos, orçamentos, assinaturas e rascunho offline.
- A base já possui tema, tokens e componentes compartilhados.

### Hotspots

- `mobile/lib/screens/task_detail_screen.dart` concentra lógica demais e ainda expõe uma UI muito distante da referência.
- `mobile/lib/widgets/app_scaffold.dart` e `mobile/lib/widgets/app_ui.dart` ainda expressam um visual genérico, não a linguagem azul/branco das referências.
- Telas listadas em `screens/` usam padrões diferentes entre si, com densidade e hierarquia inconsistentes.
- Bottom navigation atual e headers ainda não traduzem o layout de referência.

## Diagnóstico do backend

### O que já sustenta a nova UX

- `server/src/modules/auth/` já suporta registro, verificação de e-mail, recuperação de senha, refresh, sessões ativas e logout global.
- `server/src/modules/tasks/`, `reports/` e `budgets/` já oferecem CRUD real, PDF e links públicos.
- `server/src/modules/summary/summary.router.js` já entrega contagens e métricas iniciais.
- Auditoria automática já existe em `server/src/modules/monitoring/monitoring.service.js`.

### Gaps reais para a reforma

- Dashboard precisa de feed de atividade e indicadores mais ricos do que o payload atual expõe.
- Tarefa detalhada precisa de resumo operacional pronto para UI: contagem de equipamentos, fotos e checklist/progresso.
- Perfil pede mais dados de conta para a UI final; hoje o schema de usuário ainda é enxuto.
- Orçamento detalhado precisa de leitura mobile mais orientada a aprovação/recusa/WhatsApp.

## Mudanças fullstack previstas

- Expandir `summary` com dados adicionais para a home mobile.
- Enriquecer payload de tarefa com agregados para checklist, fotos e equipamentos.
- Adicionar campos de perfil que faltarem no usuário sem quebrar compatibilidade.
- Manter tudo compatível com os consumidores atuais: adicionar campos sem remover os existentes.

## Estratégia de arquitetura

### Presentation layer

- Consolidar tokens em `theme/`.
- Evoluir `app_scaffold.dart`, `app_ui.dart` e `form_fields.dart` para virarem o design system real do app.
- Separar widgets de domínio visual em blocos reutilizáveis: header azul, search field, metric card, list card, status pill, callout, avatar e action chips.

### Execução por fases

1. Consolidar design system e shells.
2. Reformar autenticação e splash.
3. Reformar home, tarefas e detalhe/nova tarefa.
4. Reformar clientes, orçamento, relatórios, mais e perfil.
5. Ajustar backend/contratos necessários.
6. Rodar análise e testes.

## Restrições observadas

- O workspace já contém alterações locais do usuário em auth e algumas telas mobile; nada será revertido.
- As referências são PNGs locais. Como a sessão não possui visualização direta desses arquivos, a implementação usa a descrição detalhada do prompt como fonte principal e o inventário físico dos PNGs como confirmação da cobertura.
