import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'permissions.dart';

List<String> _parsePermissions(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  if (value is String && value.isNotEmpty) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is List) {
        return parsed.map((item) => item.toString()).toList();
      }
    } catch (_) {}
  }
  return [];
}

const Map<String, List<String>> _roleDefaults = {
  'administracao': [
    Permissions.viewDashboard,
    Permissions.viewClients,
    Permissions.manageClients,
    Permissions.viewTasks,
    Permissions.manageTasks,
    Permissions.viewTemplates,
    Permissions.manageTemplates,
    Permissions.viewBudgets,
    Permissions.manageBudgets,
    Permissions.viewUsers,
    Permissions.manageUsers,
    Permissions.viewProducts,
    Permissions.manageProducts,
    Permissions.viewTaskTypes,
    Permissions.manageTaskTypes,
  ],
  'gestor': [
    Permissions.viewDashboard,
    Permissions.viewClients,
    Permissions.manageClients,
    Permissions.viewTasks,
    Permissions.manageTasks,
    Permissions.viewTemplates,
    Permissions.manageTemplates,
    Permissions.viewBudgets,
    Permissions.manageBudgets,
    Permissions.viewProducts,
    Permissions.manageProducts,
    Permissions.viewTaskTypes,
    Permissions.manageTaskTypes,
  ],
  'tecnico': [
    Permissions.viewDashboard,
    Permissions.viewClients,
    Permissions.viewTasks,
    Permissions.manageTasks,
    Permissions.viewBudgets,
    Permissions.viewProducts,
  ],
  'visitante': [
    Permissions.viewDashboard,
    Permissions.viewClients,
    Permissions.viewTasks,
    Permissions.viewTemplates,
    Permissions.viewBudgets,
    Permissions.viewProducts,
    Permissions.viewTaskTypes,
  ],
};

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
  bool get roleIsAdmin => user['role_is_admin'] == true;
  List<String> get rolePermissions => _parsePermissions(user['role_permissions']);

  List<String> get permissions => _parsePermissions(user['permissions']);

  List<String> get effectivePermissions {
    if (roleIsAdmin || role == 'administracao') return permissions;
    final base = rolePermissions.isNotEmpty
        ? rolePermissions
        : _roleDefaults[role] ?? _roleDefaults['visitante'] ?? [];
    if (base.isNotEmpty &&
        permissions.isNotEmpty &&
        base.every(permissions.contains)) {
      return {...permissions}.toList();
    }
    return {...base, ...permissions}.toList();
  }
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
  bool get isAdmin => session.value?.roleIsAdmin == true || session.value?.role == 'administracao';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    final storedUser = prefs.getString(_userKey);
    if (storedToken == null || storedUser == null) return;
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
    final response = await _client.get(
      ApiConfig.buildUri('/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['user'] is Map) {
        final userMap = Map<String, dynamic>.from(payload['user'] as Map);
        session.value = AuthSession(token: token!, user: userMap);
        await _persist();
      }
      return;
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
    final current = session.value;
    if (current == null) return false;
    if (current.roleIsAdmin || current.role == 'administracao') return true;
    final perms = current.effectivePermissions;
    if (perms.contains(permission)) return true;
    if (permission.startsWith('view_')) {
      final manage = permission.replaceFirst('view_', 'manage_');
      return perms.contains(manage);
    }
    return false;
  }

  bool canManageTasks() => hasPermission(Permissions.manageTasks);
  bool canManageBudgets() => hasPermission(Permissions.manageBudgets);
  bool canManageClients() => hasPermission(Permissions.manageClients);
  bool canManageTemplates() => hasPermission(Permissions.manageTemplates);
  bool canManageProducts() => hasPermission(Permissions.manageProducts);
  bool canManageTaskTypes() => hasPermission(Permissions.manageTaskTypes);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      ApiConfig.buildUri(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) return payload;
    }
    throw AuthException(_extractError(response));
  }

  Future<void> _applyAuthPayload(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString();
    final user = payload['user'];
    if (token == null || user is! Map) {
      throw AuthException('Falha ao autenticar.');
    }
    final userMap = Map<String, dynamic>.from(user);
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

  String _extractError(http.Response response) {
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['error'] != null) {
        return payload['error'].toString();
      }
    } catch (_) {}
    return 'Falha ao autenticar (${response.statusCode})';
  }
}
