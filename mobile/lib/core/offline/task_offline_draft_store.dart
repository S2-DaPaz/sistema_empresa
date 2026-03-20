import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'task_offline_draft.dart';

typedef OfflineDraftRootResolver = Future<Directory> Function();

class TaskOfflineDraftStore {
  TaskOfflineDraftStore({
    OfflineDraftRootResolver? rootResolver,
  }) : _rootResolver = rootResolver ?? getApplicationDocumentsDirectory;

  static final TaskOfflineDraftStore instance = TaskOfflineDraftStore();

  final OfflineDraftRootResolver _rootResolver;

  static String buildDraftId(int? taskId) {
    return taskId == null ? 'task_new' : 'task_$taskId';
  }

  Future<void> save(TaskOfflineDraft draft) async {
    final file = await _resolveFile(draft.draftId);
    await file.writeAsString(jsonEncode(draft.toJson()));
  }

  Future<TaskOfflineDraft?> read(String draftId) async {
    final file = await _resolveFile(draftId);
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }

    return TaskOfflineDraft.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> delete(String draftId) async {
    final file = await _resolveFile(draftId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _resolveFile(String draftId) async {
    final root = await _rootResolver();
    final draftsDir = Directory(path.join(root.path, 'offline-task-drafts'));
    if (!await draftsDir.exists()) {
      await draftsDir.create(recursive: true);
    }

    return File(path.join(draftsDir.path, '$draftId.json'));
  }
}
