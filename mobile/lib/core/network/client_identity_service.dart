import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class ClientIdentityService {
  ClientIdentityService._();

  static final ClientIdentityService instance = ClientIdentityService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  Future<String>? _deviceNameFuture;

  Future<Map<String, String>> buildHeaders({
    bool json = true,
    String? authToken,
  }) async {
    final headers = <String, String>{
      'X-Client-Platform': 'mobile',
    };

    final deviceName = await getDeviceName();
    if (deviceName.isNotEmpty) {
      headers['X-Client-Device-Name'] = deviceName;
    }

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  Future<String> getDeviceName() {
    return _deviceNameFuture ??= _resolveDeviceName();
  }

  Future<String> _resolveDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        if (!info.isPhysicalDevice) {
          return 'Android (emulador)';
        }

        final brand = _cleanPart(info.brand);
        final model = _cleanPart(info.model);
        if (brand.isEmpty && model.isEmpty) {
          return 'Android';
        }
        if (brand.isEmpty || model.toLowerCase().startsWith(brand.toLowerCase())) {
          return model.isNotEmpty ? model : brand;
        }
        return '$brand $model';
      }

      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        if (!info.isPhysicalDevice) {
          return 'iPhone (simulador)';
        }

        final name = _cleanPart(info.name);
        final model = _cleanPart(info.model);
        if (name.isNotEmpty && name.toLowerCase() != 'iphone') {
          return name;
        }
        if (model.isNotEmpty) {
          return model;
        }
        return 'iPhone';
      }
    } catch (_) {
      // O app continua funcionando mesmo sem conseguir enriquecer o header.
    }

    return _platformFallback();
  }

  String _cleanPart(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _platformFallback() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iPhone';
    return 'Mobile';
  }
}
