import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/features/tasks/presentation/task_detail/report_autosave_scheduler.dart';

void main() {
  test('executa apenas o ultimo agendamento do debounce', () async {
    final scheduler = ReportAutosaveScheduler();
    final fired = <int>[];
    final completer = Completer<void>();

    scheduler.schedule(
      delay: const Duration(milliseconds: 20),
      onFire: (sequence) async {
        fired.add(sequence);
      },
    );

    scheduler.schedule(
      delay: const Duration(milliseconds: 20),
      onFire: (sequence) async {
        fired.add(sequence);
        completer.complete();
      },
    );

    await completer.future.timeout(const Duration(seconds: 1));

    expect(fired, [2]);
  });

  test('cancel impede a execucao pendente', () async {
    final scheduler = ReportAutosaveScheduler();
    var fired = false;

    scheduler.schedule(
      delay: const Duration(milliseconds: 20),
      onFire: (_) async {
        fired = true;
      },
    );
    scheduler.cancel();

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(fired, isFalse);
  });
}
