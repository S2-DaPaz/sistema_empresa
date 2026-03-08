import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class NetworkRequestException implements Exception {
  NetworkRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef HttpRequestBuilder = Future<http.Response> Function(Uri uri);

class RequestExecutor {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<http.Response> send(
    String path,
    HttpRequestBuilder request,
  ) async {
    Object? lastError;
    final attemptedBaseUrls = <String>[];

    for (final baseUrl in AppConfig.apiBaseUrlCandidates) {
      attemptedBaseUrls.add(baseUrl);

      try {
        return await request(AppConfig.buildUriForBase(baseUrl, path))
            .timeout(_timeout);
      } on SocketException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
    }

    throw NetworkRequestException(
      AppConfig.buildConnectivityErrorMessage(
        attemptedBaseUrls: attemptedBaseUrls,
        cause: lastError,
      ),
    );
  }
}
