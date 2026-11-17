// P04 T5 (ADR-0058; p04-plan.md D8): when this device syncs while the app is
// open, if the device's "When to sync" is Automatic and sync is on:
//   on start            when the profile opens
//   on return           when the app comes back to the front (the app calls
//                       resumed())
//   after a change      a few seconds after a change waits to be sent
//   every few minutes   while open
//   after a failure     again after syncBackoff (5 s, 15 s, 1 min, 5 min,
//                       then 15 min) while offline or failing
// "Only when I tap Sync now" turns all of these off; "Sync now" works in
// both (it calls the service). Nothing runs while the app is closed.
import 'dart:async';

import 'package:application/application.dart';

import 'sync_engine.dart' show syncBackoff;

class SyncScheduler {
  SyncScheduler({
    required this.service,
    required this.when,
    this.afterChange = const Duration(seconds: 5),
    this.every = const Duration(minutes: 5),
    this.backoff = syncBackoff,
    this.onError,
  });

  /// The profile's sync, or a shared space's (P04b T11: every minute, B12).
  final SyncRunner service;

  /// The device's "When to sync", read before every automatic sync.
  final Future<SyncWhen> Function() when;
  final Duration afterChange;
  final Duration every;
  final Duration Function(int failures) backoff;
  final void Function(Object error)? onError;

  /// Failed automatic syncs in a row (offline or failed).
  int failures = 0;

  Timer? _soon, _periodic, _retry;
  StreamSubscription<SyncStatus>? _watch;
  bool _started = false, _stopped = false;

  /// Starts the timers and syncs once (not awaited by the caller: opening a
  /// profile never waits for the network, LF-INV-SEC-002).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopped = false;
    _watch = service.watchStatus().listen((s) {
      if (s.on && s.pending > 0 && !s.syncing) _later();
    }, onError: (Object e) => onError?.call(e));
    _periodic = Timer.periodic(every, (_) => run());
    await run();
  }

  /// The app came back to the front.
  Future<SyncReport?> resumed() => run();

  void _later() {
    _soon?.cancel();
    _soon = Timer(afterChange, run);
  }

  /// One automatic sync, if the setting and the profile allow it.
  Future<SyncReport?> run() async {
    try {
      if (await when() != SyncWhen.automatic) return null;
      if (!(await service.status()).on) return null;
      if (_stopped) return null;
      _soon?.cancel();
      _retry?.cancel();
      final r = await service.syncNow();
      if (_stopped) return r;
      if (r.outcome == SyncOutcome.offline || r.outcome == SyncOutcome.failed) {
        failures++;
        _retry = Timer(backoff(failures), run);
      } else {
        // Up to date, or something only the user can fix (signed out, a new
        // key, the server copy deleted, an update): no fast retries.
        failures = 0;
      }
      return r;
    } catch (e) {
      onError?.call(e);
      return null;
    }
  }

  /// Before the profile's store closes (start() again resumes, for a profile
  /// switch that failed).
  Future<void> stop() async {
    _stopped = true;
    _started = false;
    _soon?.cancel();
    _periodic?.cancel();
    _retry?.cancel();
    await _watch?.cancel();
  }
}
