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
  AuthSession({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  final String token;
  final String refreshToken;
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
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userKey = 'auth_user';

  final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);
  final http.Client _client = http.Client();

  String? get token => session.value?.token;
  String? get refreshToken => session.value?.refreshToken;
  Map<String, dynamic>? get user => session.value?.user;
  bool get isLoggedIn => session.value != null;
  bool get isAdmin => session.value?.roleIsAdmin == true;
  bool get canRefreshSession =>
      refreshToken != null && refreshToken!.isNotEmpty;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    final storedRefreshToken = prefs.getString(_refreshTokenKey);
    final storedUser = prefs.getString(_userKey);

    if ((storedToken == null || storedToken.isEmpty) &&
        (storedRefreshToken == null || storedRefreshToken.isEmpty)) {
      return;
    }

    try {
      final userMap = storedUser == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(storedUser) as Map);

      session.value = AuthSession(
        token: storedToken ?? '',
        refreshToken: storedRefreshToken ?? '',
        user: userMap,
      );

      if (storedToken == null || storedToken.isEmpty) {
        final refreshed = await tryRefreshSession();
        if (!refreshed) {
          await logout(localOnly: true);
          return;
        }
      }

      await refreshUser();
    } on AppException catch (error) {
      if (error.category == 'authentication_error' ||
          error.category == 'permission_error') {
        final refreshed = await tryRefreshSession();
        if (!refreshed) {
          await logout(localOnly: true);
        }
      }
    } catch (_) {
      await logout(localOnly: true);
    }
  }

  Future<void> refreshUser() async {
    if (token == null || token!.isEmpty) return;

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
        session.value = AuthSession(
          token: token!,
          refreshToken: refreshToken ?? '',
          user: Map<String, dynamic>.from(userPayload),
        );
        await _persist();
        return;
      }
    }

    if ((response.statusCode == 401 || response.statusCode == 403) &&
        await tryRefreshSession()) {
      return refreshUser();
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await logout(localOnly: true);
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

  Future<Map<String, dynamic>> login(String email, String password) async {
    final payload = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _applyAuthPayload(payload);
    return payload;
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) {
    return _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    final payload = await _post('/auth/email/verify', {
      'email': email,
      'code': code,
    });
    await _applyAuthPayload(payload);
    return payload;
  }

  Future<Map<String, dynamic>> resendVerificationCode(String email) {
    return _post('/auth/email/resend-code', {'email': email});
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) {
    return _post('/auth/password/forgot', {'email': email});
  }

  Future<Map<String, dynamic>> verifyPasswordResetCode(
    String email,
    String code,
  ) {
    return _post('/auth/password/verify-code', {
      'email': email,
      'code': code,
    });
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
  ) {
    return _post('/auth/password/reset', {
      'email': email,
      'code': code,
      'password': password,
    });
  }

  Future<bool> tryRefreshSession() async {
    final storedRefreshToken = refreshToken;
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _send(
        '/auth/refresh',
        (uri) => _client.post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'X-Client-Platform': 'mobile',
          },
          body: jsonEncode({'refreshToken': storedRefreshToken}),
        ),
      );

      final payload = _tryDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = payload?['data'] is Map
            ? Map<String, dynamic>.from(payload!['data'] as Map)
            : payload ?? <String, dynamic>{};
        await _applyAuthPayload(data);
        return true;
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<void> logout({bool localOnly = false}) async {
    try {
      if (!localOnly && token != null && token!.isNotEmpty) {
        await _send(
          '/auth/logout',
          (uri) => _client.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Client-Platform': 'mobile',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({}),
          ),
        );
      }
    } catch (_) {
      // A limpeza local da sessão não depende do backend responder.
    } finally {
      session.value = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userKey);
    }
  }

  Future<void> logoutAll() async {
    try {
      if (token != null && token!.isNotEmpty) {
        await _send(
          '/auth/logout-all',
          (uri) => _client.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Client-Platform': 'mobile',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({}),
          ),
        );
      }
    } finally {
      await logout(localOnly: true);
    }
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
      fallbackMessage: 'Não foi possível concluir a operação de autenticação.',
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
    final nextRefreshToken = payload['refreshToken']?.toString();
    final userPayload = payload['user'];

    if (nextToken == null ||
        nextToken.isEmpty ||
        nextRefreshToken == null ||
        nextRefreshToken.isEmpty ||
        userPayload is! Map) {
      final error = normalizeUnexpectedError(
        'Missing auth payload',
        fallbackMessage: 'Não foi possível concluir a autenticação.',
      );
      await _report(error, path: '/auth/login', method: 'POST');
      throw error;
    }

    session.value = AuthSession(
      token: nextToken,
      refreshToken: nextRefreshToken,
      user: Map<String, dynamic>.from(userPayload),
    );
    await _persist();
  }

  Future<void> _persist() async {
    final current = session.value;
    if (current == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, current.token);
    await prefs.setString(_refreshTokenKey, current.refreshToken);
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
