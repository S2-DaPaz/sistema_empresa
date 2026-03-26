import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class TaskPhotoDraft {
  const TaskPhotoDraft({
    required this.id,
    required this.name,
    required this.dataUrl,
  });

  final String id;
  final String name;
  final String dataUrl;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dataUrl': dataUrl,
    };
  }
}

/// Normaliza fotos anexadas ao relatório mantendo o formato já esperado
/// pelo backend e pela UI atual (`dataUrl` base64), mas tirando esse
/// processamento pesado do widget principal.
class TaskPhotoProcessor {
  const TaskPhotoProcessor({
    this.maxDimension = 1024,
    this.jpegQuality = 60,
  });

  final int maxDimension;
  final int jpegQuality;

  Future<List<TaskPhotoDraft>> buildDrafts(List<XFile> files) async {
    final drafts = <TaskPhotoDraft>[];
    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      final optimizedBytes = _optimizeImageBytes(bytes);
      drafts.add(
        TaskPhotoDraft(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: _asJpegName(path.basename(file.path)),
          dataUrl: 'data:image/jpeg;base64,${base64Encode(optimizedBytes)}',
        ),
      );
    }
    return drafts;
  }

  String _asJpegName(String original) {
    final ext = path.extension(original);
    if (ext.isEmpty) return '$original.jpg';
    return original.replaceRange(
      original.length - ext.length,
      original.length,
      '.jpg',
    );
  }

  Uint8List _optimizeImageBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final maxSourceDimension =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    img.Image processed = decoded;

    if (maxSourceDimension > maxDimension) {
      final scale = maxDimension / maxSourceDimension;
      processed = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    final encoded = img.encodeJpg(processed, quality: jpegQuality);
    return Uint8List.fromList(encoded);
  }
}
