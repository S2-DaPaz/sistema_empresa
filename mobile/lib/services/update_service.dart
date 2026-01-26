import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

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
              Navigator.pop(context);
              await _downloadAndInstall(context, info);
            },
            child: const Text('Atualizar agora'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(BuildContext context, AppUpdateInfo info) async {
    bool started = false;
    double progress = 0;
    bool done = false;
    String? error;
    final cancelToken = CancelToken();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          if (!started) {
            started = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final file = await _downloadApk(
                  info.apkUrl,
                  cancelToken,
                  (value) => setState(() => progress = value),
                );
                done = true;
                setState(() {});
                final result = await OpenFilex.open(file.path);
                if (result.type != ResultType.done) {
                  error = 'Nao foi possivel abrir o instalador.';
                  setState(() {});
                }
              } catch (err) {
                if (err is DioException && err.type == DioExceptionType.cancel) {
                  error = 'Download cancelado.';
                } else {
                  error = 'Falha ao baixar a atualizacao.';
                }
                setState(() {});
              }
            });
          }

          final showProgress = error == null && !done;
          final progressValue = progress > 0 ? progress : null;

          return AlertDialog(
            title: const Text('Baixando atualizacao'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showProgress)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progressValue),
                      const SizedBox(height: 8),
                      Text(
                        progress > 0
                            ? 'Progresso: ${(progress * 100).toStringAsFixed(0)}%'
                            : 'Preparando download...'
                      ),
                    ],
                  ),
                if (done && error == null)
                  const Text('Instalador aberto. Conclua a instalacao no Android.'),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
            actions: [
              if (!info.mandatory && showProgress)
                TextButton(
                  onPressed: () {
                    cancelToken.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
              if (!info.mandatory && done && error == null)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              if (!info.mandatory && error != null)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              if (error != null)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      progress = 0;
                      done = false;
                      error = null;
                      started = false;
                    });
                  },
                  child: const Text('Tentar novamente'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<File> _downloadApk(
    String url,
    CancelToken cancelToken,
    ValueChanged<double> onProgress,
  ) async {
    final resolved = _resolveApkUrl(url);
    final directory = await getTemporaryDirectory();
    final filePath = path.join(
      directory.path,
      'rv-tecnocare-${DateTime.now().millisecondsSinceEpoch}.apk',
    );
    final dio = Dio();
    await dio.download(
      resolved.toString(),
      filePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress(received / total);
      },
    );
    return File(filePath);
  }

  Uri _resolveApkUrl(String url) {
    final rawUri = Uri.tryParse(url);
    if (rawUri != null && rawUri.hasScheme) return rawUri;
    return Uri.parse(ApiConfig.baseUrl).resolve(url);
  }
}
