import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import '../errors/error_reporter.dart';
import 'request_executor.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      'X-Client-Platform': 'mobile',
    };

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    final token = AuthService.instance.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> get(String path) async {
    final response = await _send(
      path,
      (uri) => _client.get(uri, headers: _headers(json: false)),
    );
    return _handleResponse(response, path: path, method: 'GET');
  }

  Future<Map<String, dynamic>> getEnvelope(String path) async {
    final response = await _send(
      path,
      (uri) => _client.get(uri, headers: _headers(json: false)),
    );
    return _decodeEnvelope(
      response,
      path: path,
      method: 'GET',
    );
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _send(
      path,
      (uri) => _client.post(
        uri,
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    return _handleResponse(
      response,
      path: path,
      method: 'POST',
      payloadSummary: body,
    );
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _send(
      path,
      (uri) => _client.put(
        uri,
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    return _handleResponse(
      response,
      path: path,
      method: 'PUT',
      payloadSummary: body,
    );
  }

  Future<dynamic> delete(String path) async {
    final response = await _send(
      path,
      (uri) => _client.delete(uri, headers: _headers(json: false)),
    );
    return _handleResponse(response, path: path, method: 'DELETE');
  }

  Future<List<int>> getBytes(String path) async {
    final response = await _send(
      path,
      (uri) => _client.get(uri, headers: _headers(json: false)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/pdf')) {
        final error = normalizeUnexpectedError(
          'Invalid PDF response',
          fallbackMessage: 'Nao foi possivel abrir o PDF no momento.',
        );
        await _report(error, path: path, method: 'GET');
        throw error;
      }
      return response.bodyBytes;
    }

    final payload = _tryDecode(response.body);
    final error = normalizeApiError(
      payload: payload,
      statusCode: response.statusCode,
      technicalMessage: payload?['error']?.toString() ?? response.body,
      fallbackMessage: 'Nao foi possivel abrir o PDF no momento.',
    );
    await _report(error, path: path, method: 'GET');
    throw error;
  }

  Future<http.Response> _send(
    String path,
    Future<http.Response> Function(Uri uri) request,
  ) async {
    try {
      return await RequestExecutor.send(path, request);
    } on NetworkRequestException catch (error) {
      final normalized = normalizeNetworkError(
        error,
        timedOut: error.timedOut,
        technicalMessage: error.technicalMessage,
      );
      await _report(normalized, path: path, method: 'REQUEST');
      throw normalized;
    } on http.ClientException catch (error) {
      final normalized = normalizeNetworkError(
        error,
        technicalMessage: error.message,
      );
      await _report(normalized, path: path, method: 'REQUEST');
      throw normalized;
    }
  }

  Future<dynamic> _handleResponse(
    http.Response response, {
    required String path,
    required String method,
    Object? payloadSummary,
  }) async {
    if (response.statusCode == 204) {
      return null;
    }

    final envelope = await _decodeEnvelope(
      response,
      path: path,
      method: method,
      payloadSummary: payloadSummary,
    );

    if (envelope.containsKey('data')) {
      return envelope['data'];
    }

    return envelope;
  }

  Future<Map<String, dynamic>> _decodeEnvelope(
    http.Response response, {
    required String path,
    required String method,
    Object? payloadSummary,
  }) async {
    final payload = _tryDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (payload == null) {
        final error = normalizeUnexpectedError(
          'Invalid response body',
          fallbackMessage: 'Nao foi possivel processar a resposta do servidor.',
        );
        await _report(
          error,
          path: path,
          method: method,
          payloadSummary: payloadSummary,
        );
        throw error;
      }

      return payload;
    }

    final error = normalizeApiError(
      payload: payload,
      statusCode: response.statusCode,
      technicalMessage: payload?['error']?.toString() ?? response.body,
    );
    await _report(
      error,
      path: path,
      method: method,
      payloadSummary: payloadSummary,
    );
    throw error;
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _report(
    AppException error, {
    required String path,
    required String method,
    Object? payloadSummary,
  }) async {
    if (path == '/auth/me' && error.category == 'authentication_error') {
      return;
    }

    final user = AuthService.instance.user;
    await ErrorReporter.report(
      error: error,
      endpoint: path,
      method: method,
      payloadSummary: payloadSummary,
      module: path.replaceFirst(RegExp(r'^/'), '').split('/').first,
      token: AuthService.instance.token,
      userId: user?['id']?.toString(),
      userName: user?['name']?.toString(),
      userEmail: user?['email']?.toString(),
    );
  }
}
