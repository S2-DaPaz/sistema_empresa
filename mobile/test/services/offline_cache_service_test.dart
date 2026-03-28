import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rv_sistema_mobile/services/offline_cache_service.dart';

void main() {
  test('clearDataCaches remove apenas chaves de cache offline', () async {
    SharedPreferences.setMockInitialValues({
      'offline_cache_clients_list': '[{"id":1}]',
      'offline_cache_dashboard_resumo': '{"summary":{"clients":1}}',
      'auth_token': 'token-seguro',
    });

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('offline_cache_clients_list'), isNotNull);
    expect(prefs.getString('auth_token'), 'token-seguro');

    await OfflineCacheService.clearDataCaches();

    expect(prefs.getString('offline_cache_clients_list'), isNull);
    expect(prefs.getString('offline_cache_dashboard_resumo'), isNull);
    expect(prefs.getString('auth_token'), 'token-seguro');
  });
}
