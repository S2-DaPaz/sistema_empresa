import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/request_executor.dart';
import 'session_permissions.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
    } catch (_) {
      await logout();
    }
  }

  Future<void> refreshUser() async {
    if (token == null) return;

    final response = await RequestExecutor.send(
      '/auth/me',
      (uri) => _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = _unwrapResponse(response);
      final userPayload = payload['user'];
      if (userPayload is Map) {
        final userMap = Map<String, dynamic>.from(userPayload);
        session.value = AuthSession(token: token!, user: userMap);
        await _persist();
        return;
      }
    }

    await logout();
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
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapResponse(response);
    }

    throw AuthException(_extractError(response));
  }

  Future<http.Response> _send(
    String path,
    Future<http.Response> Function(Uri uri) request,
  ) async {
    try {
      return await RequestExecutor.send(path, request);
    } on NetworkRequestException catch (error) {
      throw AuthException(error.message);
    } on http.ClientException catch (error) {
      throw AuthException(error.message);
    }
  }

  Future<void> _applyAuthPayload(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString();
    final userPayload = payload['user'];

    if (token == null || userPayload is! Map) {
      throw AuthException('Falha ao autenticar.');
    }

    final userMap = Map<String, dynamic>.from(userPayload);
    session.value = AuthSession(token: token, user: userMap);
    await _persist();
  }

  Future<void> _persist() async {
    final current = session.value;
    if (current == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, current.token);
    await prefs.setString(_userKey, jsonEncode(current.user));
  }

  Map<String, dynamic> _unwrapResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw AuthException('Resposta invalida do servidor.');
    }

    final payload = Map<String, dynamic>.from(decoded);
    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return payload;
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

    return 'Falha ao autenticar (${response.statusCode})';
  }
}
