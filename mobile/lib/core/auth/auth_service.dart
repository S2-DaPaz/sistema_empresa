import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import '../errors/error_reporter.dart';
import '../network/request_executor.dart';
import 'session_permissions.dart';

class AuthSession {
  AuthSession({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;

  String get role => user['role']?.toString() ?? 'visitante';
  bool get roleIsAdmin =>
      user['role_is_admin'] == true || role == 'administracao';
  List<String> get rolePermissions =>
      parsePermissions(user['role_permissions']);
  List<String> get permissions => parsePermissions(user['permissions']);
  List<String> get effectivePermissions => getEffectivePermissions(user);
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);
  final http.Client _client = http.Client();

  String? get token => session.value?.token;
  Map<String, dynamic>? get user => session.value?.user;
  bool get isLoggedIn => session.value != null;
  bool get isAdmin => session.value?.roleIsAdmin == true;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    final storedUser = prefs.getString(_userKey);
    if (storedToken == null || storedUser == null) {
      return;
    }

    try {
      final userMap = jsonDecode(storedUser) as Map<String, dynamic>;
      session.value = AuthSession(token: storedToken, user: userMap);
      await refreshUser();
    } on AppException catch (error) {
      if (error.category == 'authentication_error' ||
          error.category == 'permission_error') {
        await logout();
      }
    } catch (_) {
      await logout();
    }
  }

  Future<void> refreshUser() async {
    if (token == null) return;

    final response = await _send(
      '/auth/me',
      (uri) => _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'X-Client-Platform': 'mobile',
        },
      ),
    );

    final payload = _tryDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final userPayload = payload?['data']?['user'] ?? payload?['user'];
      if (userPayload is Map) {
        final userMap = Map<String, dynamic>.from(userPayload);
        session.value = AuthSession(token: token!, user: userMap);
        await _persist();
        return;
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await logout();
      throw normalizeApiError(
        payload: payload,
        statusCode: response.statusCode,
      );
    }

    throw normalizeUnexpectedError(
      'Invalid auth refresh response',
      fallbackMessage: 'Não foi possível validar sua sessão agora.',
    );
  }

  Future<void> login(String email, String password) async {
    final payload = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _applyAuthPayload(payload);
  }

  Future<void> register(String name, String email, String password) async {
    final payload = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    await _applyAuthPayload(payload);
  }

  Future<void> logout() async {
    session.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  bool hasPermission(String permission) {
    return hasPermissionInUser(user, permission);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      path,
      (uri) => _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'X-Client-Platform': 'mobile',
        },
        body: jsonEncode(body),
      ),
    );

    final payload = _tryDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (payload == null) {
        final error = normalizeUnexpectedError(
          'Invalid auth response',
          fallbackMessage: 'Não foi possível processar a autenticação.',
        );
        await _report(error, path: path, method: 'POST', payloadSummary: body);
        throw error;
      }
      return payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'] as Map)
          : payload;
    }

    final error = normalizeApiError(
      payload: payload,
      statusCode: response.statusCode,
      technicalMessage: payload?['error']?.toString() ?? response.body,
      fallbackMessage: 'Não foi possível autenticar com os dados informados.',
    );
    await _report(error, path: path, method: 'POST', payloadSummary: body);
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

  Future<void> _applyAuthPayload(Map<String, dynamic> payload) async {
    final nextToken = payload['token']?.toString();
    final userPayload = payload['user'];

    if (nextToken == null || userPayload is! Map) {
      final error = normalizeUnexpectedError(
        'Missing auth payload',
        fallbackMessage: 'Não foi possível concluir a autenticação.',
      );
      await _report(error, path: '/auth/login', method: 'POST');
      throw error;
    }

    final userMap = Map<String, dynamic>.from(userPayload);
    session.value = AuthSession(token: nextToken, user: userMap);
    await _persist();
  }

  Future<void> _persist() async {
    final current = session.value;
    if (current == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, current.token);
    await prefs.setString(_userKey, jsonEncode(current.user));
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
    await ErrorReporter.report(
      error: error,
      endpoint: path,
      method: method,
      payloadSummary: payloadSummary,
      module: 'auth',
      token: token,
      userId: user?['id']?.toString(),
      userName: user?['name']?.toString(),
      userEmail: user?['email']?.toString(),
    );
  }
}
