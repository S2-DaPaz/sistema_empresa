class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3001',
  );

  static const bool pdfEnabled = bool.fromEnvironment(
    'PDF_ENABLED',
    defaultValue: true,
  );

  static Uri buildUri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalized/api$cleanPath');
  }
}
