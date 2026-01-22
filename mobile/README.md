# RV Sistema Mobile

Este app Flutter consome a API Node do projeto.

## Requisitos
- Flutter SDK instalado
- Node.js LTS (para o server)

## Configurar API
O app usa `API_URL` via `--dart-define`:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3001
```

Notas:
- Android emulator: `http://10.0.2.2:3001`
- iOS simulator: `http://localhost:3001`
- Dispositivo fisico: use o IP da sua maquina

## Autenticacao
O app usa login e registro na API (`/api/auth/login` e `/api/auth/register`).
O token fica salvo no dispositivo com `shared_preferences`.

## PDF
As acoes de PDF no mobile ficam ativadas por padrao. Para desativar, execute com:

```bash
flutter run --dart-define=PDF_ENABLED=false
```

## Rodar
```bash
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3001
```
