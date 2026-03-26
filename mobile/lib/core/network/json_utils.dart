import 'dart:convert';

/// Helpers pequenos e compartilhados para evitar decodificação ad-hoc
/// espalhada entre auth, cliente HTTP e features.
Map<String, dynamic>? tryDecodeJsonMap(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // Mantemos `null` para que a camada chamadora decida a mensagem correta.
  }
  return null;
}

Map<String, dynamic> castJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> castJsonMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(castJsonMap).toList(growable: false);
}
