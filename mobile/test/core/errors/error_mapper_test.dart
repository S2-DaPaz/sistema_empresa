import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/core/errors/error_mapper.dart';

void main() {
  test('preserves structured details from API auth errors', () {
    final error = normalizeApiError(
      payload: {
        'error': {
          'code': 'email_verification_required',
          'category': 'authentication_error',
          'message':
              'Sua conta ainda não foi verificada. Informe o código enviado por e-mail.',
          'details': {
            'email': 'maria@empresa.com',
            'maskedEmail': 'ma***@empresa.com',
          }
        }
      },
      statusCode: 403,
    );

    expect(error.code, 'email_verification_required');
    expect(error.message,
        'Sua conta ainda não foi verificada. Informe o código enviado por e-mail.');
    expect(error.details, isA<Map>());
    expect((error.details as Map)['email'], 'maria@empresa.com');
  });

  test('maps too many requests to an operation-friendly category', () {
    final error = normalizeApiError(
      payload: {
        'error': {
          'code': 'rate_limited',
          'message':
              'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.',
        }
      },
      statusCode: 429,
    );

    expect(error.category, 'operation_invalid');
    expect(error.retryable, isFalse);
  });
}
