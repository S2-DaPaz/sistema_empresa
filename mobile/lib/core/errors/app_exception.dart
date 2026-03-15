class AppException implements Exception {
  AppException({
    required this.message,
    this.category = 'unexpected_error',
    this.code = 'unexpected_error',
    this.statusCode,
    this.requestId,
    this.details,
    this.technicalMessage = '',
    this.retryable = false,
  });

  final String message;
  final String category;
  final String code;
  final int? statusCode;
  final String? requestId;
  final dynamic details;
  final String technicalMessage;
  final bool retryable;

  @override
  String toString() => message;
}
