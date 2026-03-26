import 'dart:async';

/// Encapsula apenas o debounce do autosave para deixar o widget livre do
/// gerenciamento direto de `Timer`.
class ReportAutosaveScheduler {
  Timer? _timer;
  int _sequence = 0;

  int get sequence => _sequence;

  int schedule({
    Duration delay = const Duration(milliseconds: 1500),
    required Future<void> Function(int sequence) onFire,
  }) {
    _timer?.cancel();
    final nextSequence = ++_sequence;
    _timer = Timer(delay, () {
      unawaited(onFire(nextSequence));
    });
    return nextSequence;
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    cancel();
  }
}
