import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineReadCache {
  OfflineReadCache._();

  static final OfflineReadCache instance = OfflineReadCache._();

  Future<void> writeJson(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    final raw = await _readString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Future<List<dynamic>?> readList(String key) async {
    final raw = await _readString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return List<dynamic>.from(decoded);
    }
    return null;
  }

  Future<String?> _readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
