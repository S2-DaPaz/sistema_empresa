import 'app_exception.dart';

const Map<String, String> _categoryMessages = {
  'connection_error':
      'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.',
  'server_error': 'Algo deu errado. Tente novamente em instantes.',
  'authentication_error':
      'Sua sessão expirou. Faça login novamente para continuar.',
  'permission_error': 'Você não tem permissão para realizar esta ação.',
  'validation_error': 'Revise os dados informados e tente novamente.',
  'not_found': 'Não foi possível encontrar as informações solicitadas.',
  'operation_invalid': 'Não foi possível concluir a operação no momento.',
  'unexpected_error': 'Não foi possível concluir a operação no momento.',
};

final RegExp _technicalPattern = RegExp(
  r'(socketexception|network ?error|econn|internal server error|failed to fetch|typeerror|clientexception|timeout|timed out|unhandled exception|dioexception)',
  caseSensitive: false,
);

bool _looksTechnical(String value) => _technicalPattern.hasMatch(value);

String _messageForCategory(String category, [String? fallbackMessage]) {
  return fallbackMessage ??
      _categoryMessages[category] ??
      _categoryMessages['unexpected_error']!;
}

String inferErrorCategory({int? statusCode, String? code}) {
  final normalizedCode = (code ?? '').toLowerCase();

  if (normalizedCode == 'unauthorized') return 'authentication_error';
  if (normalizedCode == 'forbidden') return 'permission_error';
  if (normalizedCode == 'validation_error') return 'validation_error';
  if (normalizedCode == 'not_found' || normalizedCode == 'route_not_found') {
    return 'not_found';
  }
  if (normalizedCode == 'conflict') return 'operation_invalid';

  final status = statusCode ?? 0;
  if (status == 0) return 'connection_error';
  if (status == 401) return 'authentication_error';
  if (status == 403) return 'permission_error';
  if (status == 404) return 'not_found';
  if (status == 429) return 'operation_invalid';
  if (status == 400 || status == 409 || status == 422) {
    return 'operation_invalid';
  }
  if (status >= 500) return 'server_error';
  return 'unexpected_error';
}

AppException normalizeApiError({
  Map<String, dynamic>? payload,
  int? statusCode,
  String? technicalMessage,
  String? fallbackMessage,
}) {
  final errorMap = payload?['error'] is Map<String, dynamic>
      ? Map<String, dynamic>.from(payload!['error'] as Map)
      : payload?['error'] is Map
          ? Map<String, dynamic>.from(payload!['error'] as Map)
          : <String, dynamic>{};
  final category = errorMap['category']?.toString() ??
      inferErrorCategory(
        statusCode: statusCode,
        code: errorMap['code']?.toString(),
      );
  final rawMessage =
      (errorMap['message'] ?? technicalMessage ?? '').toString().trim();
  final safeMessage = rawMessage.isNotEmpty && !_looksTechnical(rawMessage)
      ? rawMessage
      : _messageForCategory(category, fallbackMessage);

  return AppException(
    message: safeMessage,
    category: category,
    code: errorMap['code']?.toString() ?? 'request_failed',
    statusCode: statusCode,
    requestId: errorMap['requestId']?.toString(),
    details: errorMap['details'],
    technicalMessage: rawMessage.isNotEmpty
        ? rawMessage
        : 'HTTP ${statusCode ?? 0}',
    retryable: category == 'connection_error' || category == 'server_error',
  );
}

AppException normalizeNetworkError(
  Object error, {
  bool timedOut = false,
  String? technicalMessage,
}) {
  return AppException(
    message: timedOut
        ? 'A conexão demorou mais do que o esperado. Tente novamente.'
        : _messageForCategory('connection_error'),
    category: 'connection_error',
    code: timedOut ? 'timeout' : 'network_error',
    technicalMessage:
        technicalMessage ?? error.toString(),
    retryable: true,
  );
}

AppException normalizeUnexpectedError(Object error, {String? fallbackMessage}) {
  final rawMessage = error.toString().trim();
  final statusCode = error is AppException ? error.statusCode : null;
  final category = error is AppException
      ? error.category
      : inferErrorCategory(statusCode: statusCode);
  final safeMessage =
      rawMessage.isNotEmpty && !_looksTechnical(rawMessage)
          ? rawMessage
          : _messageForCategory(category, fallbackMessage);

  return AppException(
    message: safeMessage,
    category: category,
    code: error is AppException ? error.code : 'unexpected_error',
    statusCode: statusCode,
    requestId: error is AppException ? error.requestId : null,
    details: error is AppException ? error.details : null,
    technicalMessage: rawMessage,
    retryable:
        category == 'connection_error' || category == 'server_error',
  );
}
