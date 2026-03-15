# Autenticação e gestão de conta

## Visão geral

O sistema agora possui um módulo completo de autenticação com:

- login por e-mail e senha
- cadastro de conta com verificação obrigatória por código
- reenvio de código de verificação
- recuperação de senha por código
- redefinição de senha com invalidação de sessões anteriores
- refresh token com rotação de sessão
- auditoria dos eventos de autenticação
- mensagens amigáveis para usuário final

## Ciclo de vida da conta

1. O usuário cria a conta em `POST /api/auth/register`.
2. A conta é criada com status `pending_verification`.
3. Um código de verificação é enviado por e-mail.
4. O usuário confirma o código em `POST /api/auth/email/verify`.
5. A conta passa para `active` e a sessão é criada.

Regras:

- contas pendentes não recebem sessão no login
- o login de conta pendente retorna `email_verification_required`
- contas verificadas recebem `token` e `refreshToken`

## Sessão

- `token`: JWT de acesso de curta duração
- `refreshToken`: token opaco persistido em `auth_sessions`
- `POST /api/auth/refresh`: gira o refresh token e renova a sessão
- `POST /api/auth/logout`: revoga a sessão atual
- `POST /api/auth/logout-all`: revoga todas as sessões do usuário

## Códigos de autenticação

Todos os códigos são armazenados com hash em `auth_codes`.

Propósitos suportados:

- `EMAIL_VERIFICATION`
- `PASSWORD_RESET`

Regras aplicadas:

- códigos numéricos de 6 dígitos
- expiração curta
- tentativa máxima por código
- invalidação de códigos anteriores ao emitir um novo
- cooldown para reenvio

## Endpoints

### Públicos

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/email/verify`
- `POST /api/auth/email/resend-code`
- `POST /api/auth/password/forgot`
- `POST /api/auth/password/verify-code`
- `POST /api/auth/password/reset`

### Protegidos

- `GET /api/auth/me`
- `POST /api/auth/logout`
- `POST /api/auth/logout-all`

## Integração de e-mail

Variáveis principais:

- `EMAIL_PROVIDER=console|smtp`
- `EMAIL_FROM_NAME`
- `EMAIL_FROM_ADDRESS`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_SECURE`
- `SMTP_USER`
- `SMTP_PASSWORD`

Ambientes:

- `console`: não envia e-mail real; registra a mensagem no log do servidor
- `smtp`: usa o servidor SMTP configurado

## Auditoria

O módulo registra eventos como:

- `AUTH_REGISTER_SUCCESS`
- `AUTH_REGISTER_FAILURE`
- `AUTH_LOGIN_SUCCESS`
- `AUTH_LOGIN_FAILURE`
- `AUTH_EMAIL_VERIFICATION_RESENT`
- `AUTH_EMAIL_VERIFIED`
- `AUTH_PASSWORD_RESET_REQUESTED`
- `AUTH_PASSWORD_RESET_CODE_VERIFIED`
- `AUTH_PASSWORD_RESET_SUCCESS`
- `AUTH_REFRESH_TOKEN_ROTATED`
- `AUTH_LOGOUT`

Falhas técnicas continuam indo para `error_logs`.

## Segurança

- senhas com `bcrypt`
- refresh token salvo com hash
- código de verificação salvo com hash
- detalhes técnicos não aparecem na interface
- proteção básica contra abuso em login, envio de código e recuperação
- redefinição de senha revoga sessões anteriores
