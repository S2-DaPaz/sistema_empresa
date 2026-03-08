import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  static const String defaultRemoteApiUrl =
      'https://sistema-empresa-jvkb.onrender.com';

  static const String appName = 'RV Sistema Empresa';
  static const String appTagline =
      'Tarefas, relatorios e orcamentos vinculados';

  static const bool pdfEnabled = bool.fromEnvironment(
    'PDF_ENABLED',
    defaultValue: true,
  );

  static bool get hasConfiguredApiUrl => _configuredApiUrl.isNotEmpty;

  static String get apiBaseUrl {
    return apiBaseUrlCandidates.first;
  }

  static List<String> get apiBaseUrlCandidates {
    if (hasConfiguredApiUrl) {
      return [_normalizeBaseUrl(_configuredApiUrl)];
    }

    if (kReleaseMode) {
      return [defaultRemoteApiUrl];
    }

    if (!kIsWeb && Platform.isAndroid) {
      return const [
        defaultRemoteApiUrl,
        'http://127.0.0.1:3001',
        'http://10.0.2.2:3001',
      ];
    }

    return const [
      defaultRemoteApiUrl,
      'http://127.0.0.1:3001',
    ];
  }

  static Uri buildUri(String path) {
    return buildUriForBase(apiBaseUrl, path);
  }

  static Uri buildUriForBase(String baseUrl, String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl/api$cleanPath');
  }

  static String buildConnectivityErrorMessage({
    required List<String> attemptedBaseUrls,
    Object? cause,
  }) {
    final attempted = attemptedBaseUrls.join(', ');
    final detail = cause == null ? '' : ' Detalhe tecnico: $cause';

    if (hasConfiguredApiUrl) {
      return 'Nao foi possivel conectar com a API configurada em $attempted.$detail';
    }

    if (attemptedBaseUrls.contains(defaultRemoteApiUrl)) {
      return 'Nao foi possivel conectar com a API padrao do projeto. Enderecos tentados: $attempted. Passe `API_URL` para sobrescrever o destino.$detail';
    }

    if (!kIsWeb && Platform.isAndroid) {
      return 'Nao foi possivel conectar com a API local. Em aparelho fisico, mantenha `adb reverse tcp:3001 tcp:3001`. Em emulador Android, use `10.0.2.2:3001` ou passe `API_URL`. Enderecos tentados: $attempted.$detail';
    }

    return 'Nao foi possivel conectar com a API local em $attempted.$detail';
  }

  static String _normalizeBaseUrl(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }

    return value;
  }

  static const String _configuredApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );
}
