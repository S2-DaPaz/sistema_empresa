import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import 'request_executor.dart';

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
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
    return _handleResponse(response);
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
    return _handleResponse(response);
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
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _send(
      path,
      (uri) => _client.delete(uri, headers: _headers(json: false)),
    );
    return _handleResponse(response);
  }

  Future<List<int>> getBytes(String path) async {
    final response = await _send(
      path,
      (uri) => _client.get(uri, headers: _headers(json: false)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/pdf')) {
        throw ApiException(_extractError(response));
      }
      return response.bodyBytes;
    }

    throw ApiException(_extractError(response));
  }

  Future<http.Response> _send(
    String path,
    Future<http.Response> Function(Uri uri) request,
  ) async {
    try {
      return await RequestExecutor.send(path, request);
    } on TimeoutException catch (error) {
      throw ApiException(error.toString());
    } on NetworkRequestException catch (error) {
      throw ApiException(error.message);
    } on http.ClientException catch (error) {
      throw ApiException(error.message);
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 204) {
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload.containsKey('data')) {
        return payload['data'];
      }
      return payload;
    }

    throw ApiException(_extractError(response));
  }

  String _extractError(http.Response response) {
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map) {
        final error = payload['error'];
        if (error is Map && error['message'] != null) {
          return error['message'].toString();
        }
        if (error != null) {
          return error.toString();
        }
      }
    } catch (_) {}

    return 'Falha na requisicao (${response.statusCode})';
  }
}
