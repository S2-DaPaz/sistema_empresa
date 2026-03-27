import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:rv_sistema_mobile/services/osm_geocoding_service.dart';

void main() {
  test('reverseGeocode reaproveita cache para coordenadas arredondadas', () async {
    var requestCount = 0;

    final service = OsmGeocodingService(
      httpClient: MockClient((request) async {
        requestCount += 1;
        expect(
          request.headers['User-Agent'],
          contains('com.example.test'),
        );
        return http.Response(
          '{"display_name":"Avenida Paulista, Sao Paulo, Brasil"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      packageNameResolver: () async => 'com.example.test',
      minInterval: Duration.zero,
    );

    final first = await service.reverseGeocode(
      latitude: -23.55052,
      longitude: -46.63330,
    );
    final second = await service.reverseGeocode(
      latitude: -23.55054,
      longitude: -46.63331,
    );

    expect(first, 'Avenida Paulista, Sao Paulo, Brasil');
    expect(second, 'Avenida Paulista, Sao Paulo, Brasil');
    expect(requestCount, 1);
  });

  test('reverseGeocode lanca excecao amigavel em resposta invalida', () async {
    final service = OsmGeocodingService(
      httpClient: MockClient(
        (_) async => http.Response('erro', 503),
      ),
      packageNameResolver: () async => 'com.example.test',
      minInterval: Duration.zero,
    );

    expect(
      () => service.reverseGeocode(latitude: -15, longitude: -47),
      throwsA(isA<OsmGeocodingException>()),
    );
  });
}
