import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/core/errors/error_mapper.dart';

void main() {
  test('normalizes technical network errors into a friendly connection message',
      () {
    final error = normalizeNetworkError(
      Exception('SocketException: Connection refused'),
    );

    expect(error.category, 'connection_error');
    expect(
      error.message,
      'Nao foi possivel conectar ao servidor. Verifique sua internet e tente novamente.',
    );
    expect(error.technicalMessage, contains('SocketException'));
  });

  test('uses backend category when the API already returns a friendly auth error',
      () {
    final error = normalizeApiError(
      payload: {
        'error': {
          'code': 'unauthorized',
          'category': 'authentication_error',
          'message': 'Sua sessao expirou. Faca login novamente para continuar.',
          'requestId': 'req-123',
        },
      },
      statusCode: 401,
    );

    expect(error.category, 'authentication_error');
    expect(
      error.message,
      'Sua sessao expirou. Faca login novamente para continuar.',
    );
    expect(error.requestId, 'req-123');
  });

  test('replaces raw server text with a safe message when necessary', () {
    final error = normalizeApiError(
      payload: {
        'error': {
          'code': 'internal_error',
          'message': '500 Internal Server Error',
        },
      },
      statusCode: 500,
    );

    expect(error.category, 'server_error');
    expect(error.message, 'Algo deu errado. Tente novamente em instantes.');
  });
}
