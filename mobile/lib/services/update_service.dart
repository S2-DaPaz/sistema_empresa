import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.notes,
    required this.mandatory,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String notes;
  final bool mandatory;

  static AppUpdateInfo? fromJson(Map<String, dynamic> json) {
    final code = int.tryParse(json['versionCode']?.toString() ?? '') ?? 0;
    final url = json['apkUrl']?.toString() ?? '';
    if (code <= 0 || url.isEmpty) return null;
    return AppUpdateInfo(
      versionCode: code,
      versionName: json['versionName']?.toString() ?? '',
      apkUrl: url,
      notes: json['notes']?.toString() ?? '',
      mandatory: json['mandatory'] == true,
    );
  }
}

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  int? _lastShownVersion;

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(ApiConfig.buildUri('/app/mobile-update'));
      if (response.statusCode == 204) return;
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return;
      final info = AppUpdateInfo.fromJson(payload);
      if (info == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      if (info.versionCode <= currentCode) return;
      if (_lastShownVersion == info.versionCode) return;
      _lastShownVersion = info.versionCode;

      if (!context.mounted) return;
      await _showUpdateDialog(context, info);
    } catch (_) {
      return;
    }
  }

  Future<void> _showUpdateDialog(BuildContext context, AppUpdateInfo info) async {
    final versionLabel = info.versionName.isNotEmpty
        ? info.versionName
        : 'build ${info.versionCode}';

    await showDialog<void>(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (context) => AlertDialog(
        title: const Text('Atualizacao disponivel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versao $versionLabel'),
            if (info.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(info.notes),
            ]
          ],
        ),
        actions: [
          if (!info.mandatory)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Depois'),
            ),
          ElevatedButton(
            onPressed: () async {
              await _openUrl(context, info.apkUrl);
              if (context.mounted && !info.mandatory) {
                Navigator.pop(context);
              }
            },
            child: const Text('Atualizar agora'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final rawUri = Uri.tryParse(url);
    final uri = rawUri != null && rawUri.hasScheme
        ? rawUri
        : Uri.parse(ApiConfig.baseUrl).resolve(url);
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success) {
      _showSnack(context, 'Nao foi possivel abrir o link de atualizacao.');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
