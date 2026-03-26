import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import '../errors/error_reporter.dart';
import 'json_utils.dart';
import 'request_executor.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool _deveRenovarSessao(String path) {
    if (!AuthService.instance.canRefreshSession) return false;
    if (path == '/auth/refresh') return false;
    if (path == '/auth/login' || path == '/auth/register') return false;
    if (path.startsWith('/auth/email/') || path.startsWith('/auth/password/')) {
      return false;
    }
    return true;
  }

  Map<String, String> _cabecalhos({bool json = true}) {
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
    final response = await _enviar(
      path,
      (uri) => _client.get(uri, headers: _cabecalhos(json: false)),
    );
    return _processarResposta(response, path: path, method: 'GET');
  }

  Future<Map<String, dynamic>> getEnvelope(String path) async {
    final response = await _enviar(
      path,
      (uri) => _client.get(uri, headers: _cabecalhos(json: false)),
    );
    return _decodificarEnvelope(
      response,
      path: path,
      method: 'GET',
    );
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _enviar(
      path,
      (uri) => _client.post(
        uri,
        headers: _cabecalhos(),
        body: jsonEncode(body),
      ),
    );
    return _processarResposta(
      response,
      path: path,
      method: 'POST',
      payloadSummary: body,
    );
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _enviar(
      path,
      (uri) => _client.put(
        uri,
        headers: _cabecalhos(),
        body: jsonEncode(body),
      ),
    );
    return _processarResposta(
      response,
      path: path,
      method: 'PUT',
      payloadSummary: body,
    );
  }

  Future<dynamic> delete(String path) async {
    final response = await _enviar(
      path,
      (uri) => _client.delete(uri, headers: _cabecalhos(json: false)),
    );
    return _processarResposta(response, path: path, method: 'DELETE');
  }

  Future<List<int>> getBytes(String path) async {
    final response = await _enviar(
      path,
      (uri) => _client.get(uri, headers: _cabecalhos(json: false)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/pdf')) {
        final error = normalizeUnexpectedError(
          'Invalid PDF response',
          fallbackMessage: 'Não foi possível abrir o PDF no momento.',
        );
        await _reportar(error, path: path, method: 'GET');
        throw error;
      }
      return response.bodyBytes;
    }

    final payload = tryDecodeJsonMap(response.body);
    final error = normalizeApiError(
      payload: payload,
      statusCode: response.statusCode,
      technicalMessage: payload?['error']?.toString() ?? response.body,
      fallbackMessage: 'Não foi possível abrir o PDF no momento.',
    );
    await _reportar(error, path: path, method: 'GET');
    throw error;
  }

  Future<http.Response> _enviar(
    String path,
    Future<http.Response> Function(Uri uri) request,
  ) async {
    try {
      final response = await RequestExecutor.send(path, request);
      if (response.statusCode == 401 && _deveRenovarSessao(path)) {
        final refreshed = await AuthService.instance.tryRefreshSession();
        if (refreshed) {
          return RequestExecutor.send(path, request);
        }
      }
      return response;
    } on NetworkRequestException catch (error) {
      final normalized = normalizeNetworkError(
        error,
        timedOut: error.timedOut,
        technicalMessage: error.technicalMessage,
      );
      await _reportar(normalized, path: path, method: 'REQUEST');
      throw normalized;
    } on http.ClientException catch (error) {
      final normalized = normalizeNetworkError(
        error,
        technicalMessage: error.message,
      );
      await _reportar(normalized, path: path, method: 'REQUEST');
      throw normalized;
    }
  }

  Future<dynamic> _processarResposta(
    http.Response response, {
    required String path,
    required String method,
    Object? payloadSummary,
  }) async {
    if (response.statusCode == 204) {
      return null;
    }

    final envelope = await _decodificarEnvelope(
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

  Future<Map<String, dynamic>> _decodificarEnvelope(
    http.Response response, {
    required String path,
    required String method,
    Object? payloadSummary,
  }) async {
    final payload = tryDecodeJsonMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (payload == null) {
        final error = normalizeUnexpectedError(
          'Invalid response body',
          fallbackMessage: 'Não foi possível processar a resposta do servidor.',
        );
        await _reportar(
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
    await _reportar(
      error,
      path: path,
      method: method,
      payloadSummary: payloadSummary,
    );
    throw error;
  }

  Future<void> _reportar(
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
