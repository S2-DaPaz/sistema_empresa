import '../contracts/app_permissions.dart';

List<String> parsePermissions(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }

  return [];
}

List<String> getEffectivePermissions(Map<String, dynamic>? user) {
  if (user == null) return const [];

  final role = user['role']?.toString() ?? 'visitante';
  final roleIsAdmin = user['role_is_admin'] == true || role == 'administracao';
  if (roleIsAdmin) {
    return PermissionCatalog.all;
  }

  final explicitPermissions = parsePermissions(user['permissions']);
  if (explicitPermissions.isNotEmpty) {
    return explicitPermissions.toSet().toList();
  }

  final rolePermissions = parsePermissions(user['role_permissions']);
  final defaults = rolePermissions.isNotEmpty
      ? rolePermissions
      : PermissionCatalog.roleDefaults[role] ??
          PermissionCatalog.roleDefaults['visitante'] ??
          const [];

  return defaults.toSet().toList();
}

bool hasPermissionInUser(Map<String, dynamic>? user, String permission) {
  if (user == null) return false;

  final role = user['role']?.toString() ?? 'visitante';
  if (user['role_is_admin'] == true || role == 'administracao') {
    return true;
  }

  final permissions = getEffectivePermissions(user).toSet();
  if (permissions.contains(permission)) {
    return true;
  }

  if (permission.startsWith('view_')) {
    return permissions.contains(permission.replaceFirst('view_', 'manage_'));
  }

  return false;
}
