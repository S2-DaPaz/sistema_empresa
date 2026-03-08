import '../core/config/app_config.dart';

class ApiConfig {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static bool get pdfEnabled => AppConfig.pdfEnabled;

  static Uri buildUri(String path) {
    return AppConfig.buildUri(path);
  }
}
