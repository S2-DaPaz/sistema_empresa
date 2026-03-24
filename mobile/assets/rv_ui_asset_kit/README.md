# RV UI Asset Kit

Kit de assets criado a partir da logo enviada e das referências visuais mobile do projeto.

## O que vem no pacote
- `brand/`: monograma, wordmarks, app icon, splash screen, favicon
- `illustrations/`: peças para autenticação e empty states
- `icons/`: ícones SVG 24px com mesmo grid e stroke
- `tokens/`: CSS, JSON e tema Flutter
- `compat/web/src/assets/`: arquivos com nomes prontos para substituir `Logo.png`, `rv-logo.png` e `favicon.svg`

## Direção visual aplicada
- azul principal mais profundo para CTAs e navegação
- acento menta/ciano para microdestaques e badges
- superfícies brancas com borda fria e sombra curta
- cantos mais arredondados para coerência entre web e mobile
- ícones lineares com cantos arredondados e leitura limpa em 24px

## Estrutura sugerida no projeto
### Web
- copiar `compat/web/src/assets/Logo.png` para `web/src/assets/Logo.png`
- copiar `compat/web/src/assets/rv-logo.png` para `web/src/assets/rv-logo.png`
- copiar `compat/web/src/assets/favicon.svg` para `web/src/assets/favicon.svg`
- importar `tokens/rv-design-tokens.css` antes ou junto do `styles.css`

### Mobile Flutter
- mover `brand/`, `illustrations/` e `icons/` para `mobile/assets/ui/`
- registrar a pasta em `pubspec.yaml`
- usar `tokens/rv-flutter-theme.json` como base para o `ThemeData`

## Recomendações de uso
- CTA primário: `brand_600`
- CTA hover: `brand_700`
- badges de info: `brand_50` + `brand_700`
- sucesso: `success`
- alerta: `warning`
- erro: `danger`
- fundo de página: `surface_soft`
- cards: `surface`

## Observações
- os SVGs foram desenhados para evitar serrilhado e manter boa leitura em 1x e 2x
- os PNGs foram exportados em alta resolução para uso imediato
- o monograma não depende de fontes externas
