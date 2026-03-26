import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/core/network/json_utils.dart';

void main() {
  test('tryDecodeJsonMap decodifica mapa json valido', () {
    final decoded = tryDecodeJsonMap('{"data":{"id":1}}');

    expect(decoded, isNotNull);
    expect(decoded?['data'], isA<Map<String, dynamic>>());
  });

  test('castJsonMapList normaliza listas heterogeneas de mapas', () {
    final normalized = castJsonMapList([
      {'id': 1},
      <Object?, Object?>{'id': 2, 'name': 'Cliente'},
    ]);

    expect(normalized, hasLength(2));
    expect(normalized[1]['name'], 'Cliente');
  });
}
