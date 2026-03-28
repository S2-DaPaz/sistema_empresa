import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  const OfflineCacheService._();

  static const _cachePrefix = 'offline_cache_';

  static Future<Map<String, dynamic>?> readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  static Future<List<Map<String, dynamic>>?> readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeMap(
    String key,
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  static Future<void> writeList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  static String endpointKey(String prefix, String endpoint) {
    final normalized = endpoint
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '$_cachePrefix${prefix}_$normalized';
  }

  static Future<void> clearDataCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_cachePrefix))
        .toList(growable: false);

    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
