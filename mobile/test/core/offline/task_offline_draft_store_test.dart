import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rv_sistema_mobile/core/offline/task_offline_draft.dart';
import 'package:rv_sistema_mobile/core/offline/task_offline_draft_store.dart';

void main() {
  test('persists and removes task offline drafts on disk', () async {
    final tempRoot = await Directory.systemTemp.createTemp('offline-draft-test');
    final store = TaskOfflineDraftStore(rootResolver: () async => tempRoot);
    final draft = TaskOfflineDraft(
      draftId: TaskOfflineDraftStore.buildDraftId(42),
      taskId: 42,
      activeReportId: 8,
      reportEquipmentId: 4,
      updatedAt: DateTime.utc(2026, 3, 20, 12, 0).toIso8601String(),
      pendingSync: true,
      lookups: {
        'clients': [
          {'id': 1, 'name': 'Cliente teste'}
        ]
      },
      task: {
        'title': 'Tarefa offline',
        'status': 'em_andamento',
      },
      reports: [
        {
          'id': 8,
          'title': 'Relatório',
          'content': {
            'answers': {'campo': 'valor'}
          }
        }
      ],
      budgets: const [],
    );

    await store.save(draft);
    final restored = await store.read(draft.draftId);

    expect(restored, isNotNull);
    expect(restored!.taskId, 42);
    expect(restored.pendingSync, isTrue);
    expect(restored.task['title'], 'Tarefa offline');
    expect(restored.reports.first['id'], 8);

    await store.delete(draft.draftId);
    expect(await store.read(draft.draftId), isNull);

    await tempRoot.delete(recursive: true);
  });
}
