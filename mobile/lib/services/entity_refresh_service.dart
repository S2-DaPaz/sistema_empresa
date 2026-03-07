import 'dart:async';

class EntityRefreshService {
  EntityRefreshService._();

  static final EntityRefreshService instance = EntityRefreshService._();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  StreamSubscription<String> listen(
    Iterable<String> endpoints,
    void Function(String endpoint) onRefresh,
  ) {
    final watched = endpoints.map(_normalize).toSet();
    return _controller.stream
        .where((endpoint) => watched.contains(_normalize(endpoint)))
        .listen(onRefresh);
  }

  void notifyChanged(String endpoint) {
    _controller.add(_normalize(endpoint));
  }

  String _normalize(String endpoint) {
    var normalized = endpoint.trim();
    if (normalized.isEmpty) return '/';
    final queryIndex = normalized.indexOf('?');
    if (queryIndex >= 0) {
      normalized = normalized.substring(0, queryIndex);
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
