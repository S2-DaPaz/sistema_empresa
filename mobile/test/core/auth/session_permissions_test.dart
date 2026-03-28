import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/core/auth/session_permissions.dart';
import 'package:rv_sistema_mobile/services/permissions.dart';

void main() {
  test('falls back to role defaults when role permissions are missing', () {
    final permissions = getEffectivePermissions({
      'role': 'tecnico',
      'role_permissions': null,
      'permissions': null,
      'role_is_admin': false,
    });

    expect(permissions, contains(Permissions.manageTasks));
    expect(permissions, contains(Permissions.viewTasks));
  });

test('prefers explicit user permissions when present', () {
  final permissions = getEffectivePermissions({
    'role': 'visitante',
      'role_permissions': const [],
      'permissions': [Permissions.viewUsers],
      'role_is_admin': false,
    });

  expect(permissions, [Permissions.viewUsers]);
});

test('visitor defaults no longer grant operational reads', () {
  final permissions = getEffectivePermissions({
    'role': 'visitante',
    'role_permissions': null,
    'permissions': null,
    'role_is_admin': false,
  });

  expect(permissions, isEmpty);
});

test('manage permission satisfies related view permission', () {
  final allowed = hasPermissionInUser({
    'role': 'visitante',
      'role_permissions': [Permissions.manageClients],
      'permissions': const [],
      'role_is_admin': false,
    }, Permissions.viewClients);

    expect(allowed, isTrue);
  });
}
