import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'RV Sistema Empresa';
  static const String appTagline =
      'Tarefas, relatorios e orcamentos vinculados';

  static const bool pdfEnabled = bool.fromEnvironment(
    'PDF_ENABLED',
    defaultValue: true,
  );

  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_URL', defaultValue: '');
    if (configured.isNotEmpty) {
      return _normalizeBaseUrl(configured);
    }

    if (kReleaseMode) {
      throw StateError('API_URL is required for release builds.');
    }

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://127.0.0.1:3001';
  }

  static Uri buildUri(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiBaseUrl/api$cleanPath');
  }

  static String _normalizeBaseUrl(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }

    return value;
  }
}
