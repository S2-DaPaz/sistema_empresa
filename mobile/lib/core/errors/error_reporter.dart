import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../navigation/route_tracker.dart';
import 'app_exception.dart';

class ErrorReporter {
  ErrorReporter._();

  static final http.Client _client = http.Client();

  static Future<void> report({
    required AppException error,
    required String endpoint,
    required String method,
    Object? payloadSummary,
    String module = 'mobile',
    String? operation,
    String? token,
    String? userId,
    String? userName,
    String? userEmail,
  }) async {
    if (endpoint.contains('/monitoring/client-errors')) {
      return;
    }

    final body = jsonEncode({
      'friendlyMessage': error.message,
      'technicalMessage':
          error.technicalMessage.isNotEmpty ? error.technicalMessage : error.message,
      'category': error.category,
      'errorCode': error.code,
      'httpStatus': error.statusCode,
      'httpMethod': method,
      'endpoint': endpoint,
      'module': module,
      'platform': 'mobile',
      'screenRoute': RouteTracker.instance.currentScreen,
      'operation': operation ?? '$method $endpoint',
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'context': {
        'requestId': error.requestId,
      },
      'payloadSummary': payloadSummary,
    });

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Client-Platform': 'mobile',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    for (final baseUrl in AppConfig.apiBaseUrlCandidates) {
      try {
        await _client
            .post(
              AppConfig.buildUriForBase(baseUrl, '/monitoring/client-errors'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 4));
        return;
      } catch (_) {
        continue;
      }
    }
  }
}
