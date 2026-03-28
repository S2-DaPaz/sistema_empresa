import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/core/auth/auth_service.dart';
import 'package:rv_sistema_mobile/services/permissions.dart';

void main() {
  tearDown(() {
    AuthService.instance.session.value = null;
  });

  test('visitante navega pelas telas mas não lê dados operacionais', () {
    AuthService.instance.session.value = AuthSession(
      token: 'token',
      refreshToken: 'refresh',
      user: {
        'role': 'visitante',
        'role_permissions': const <String>[],
        'permissions': [Permissions.viewTasks, Permissions.viewClients],
        'role_is_admin': false,
      },
    );

    expect(Permissions.canAccessModule(AppModule.tasks), isTrue);
    expect(Permissions.canAccessModule(AppModule.clients), isTrue);
    expect(Permissions.canViewModuleData(AppModule.tasks), isFalse);
    expect(Permissions.canViewModuleData(AppModule.clients), isFalse);
    expect(Permissions.canManageModule(AppModule.tasks), isFalse);
  });

  test('técnico mantém acesso legítimo às áreas operacionais', () {
    AuthService.instance.session.value = AuthSession(
      token: 'token',
      refreshToken: 'refresh',
      user: {
        'role': 'tecnico',
        'role_permissions': const <String>[],
        'permissions': const <String>[],
        'role_is_admin': false,
      },
    );

    expect(Permissions.canAccessModule(AppModule.tasks), isTrue);
    expect(Permissions.canViewModuleData(AppModule.tasks), isTrue);
    expect(Permissions.canManageModule(AppModule.tasks), isTrue);
    expect(Permissions.canViewEndpointData('/products'), isTrue);
  });
}
