import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class OsmGeocodingService {
  OsmGeocodingService({
    http.Client? httpClient,
    Future<String> Function()? packageNameResolver,
    DateTime Function()? clock,
    this.minInterval = const Duration(seconds: 1),
  })  : _httpClient = httpClient ?? http.Client(),
        _packageNameResolver = packageNameResolver,
        _clock = clock ?? DateTime.now;

  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _fallbackPackageName = 'com.example.rv_sistema_mobile';

  final http.Client _httpClient;
  final Future<String> Function()? _packageNameResolver;
  final DateTime Function() _clock;
  final Duration minInterval;

  final Map<String, String> _reverseCache = <String, String>{};
  DateTime? _lastReverseLookupAt;
  String? _resolvedUserAgent;

  static Future<String> resolvePackageName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName.trim();
      if (packageName.isNotEmpty) {
        return packageName;
      }
    } catch (_) {
      // Mantemos um fallback estável para ainda identificar o app no OSM.
    }
    return _fallbackPackageName;
  }

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final cacheKey = _buildCacheKey(latitude, longitude);
    final cached = _reverseCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    await _respectRateLimit();

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      <String, String>{
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      },
    );

    final response = await _httpClient.get(
      uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
        'User-Agent': await _resolveUserAgent(),
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const OsmGeocodingException(
        'Nao foi possivel consultar o endereco no momento.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const OsmGeocodingException(
        'Resposta inesperada do servico de enderecos.',
      );
    }

    final formattedAddress = _extractFormattedAddress(decoded);
    if (formattedAddress == null || formattedAddress.isEmpty) {
      return null;
    }

    _reverseCache[cacheKey] = formattedAddress;
    return formattedAddress;
  }

  Future<void> _respectRateLimit() async {
    final now = _clock();
    final lastLookupAt = _lastReverseLookupAt;
    if (lastLookupAt != null) {
      final elapsed = now.difference(lastLookupAt);
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastReverseLookupAt = _clock();
  }

  Future<String> _resolveUserAgent() async {
    final resolved = _resolvedUserAgent;
    if (resolved != null) {
      return resolved;
    }
    final packageName =
        await (_packageNameResolver?.call() ?? resolvePackageName());
    final userAgent = 'RVSistemaEmpresaMobile/1.0 ($packageName)';
    _resolvedUserAgent = userAgent;
    return userAgent;
  }

  String _buildCacheKey(double latitude, double longitude) {
    // Arredondamos as coordenadas para reduzir chamadas duplicadas do mesmo ponto
    // sem tentar adivinhar endereco enquanto o usuario ainda navega no mapa.
    return '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
  }

  String? _extractFormattedAddress(Map<String, dynamic> payload) {
    final displayName = payload['display_name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final address = payload['address'];
    if (address is! Map) {
      return null;
    }

    final normalized = address.map(
      (key, value) => MapEntry(key.toString(), value?.toString().trim()),
    );

    final parts = <String?>[
      normalized['road'],
      normalized['house_number'],
      normalized['suburb'],
      normalized['city'] ?? normalized['town'] ?? normalized['village'],
      normalized['state'],
      normalized['postcode'],
      normalized['country'],
    ]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }
}

class OsmGeocodingException implements Exception {
  const OsmGeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
