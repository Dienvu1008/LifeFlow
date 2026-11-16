// P04 T5: an in-memory SyncService for the sync UI tests. It keeps the
// rules the UI depends on (the two confirmation words, the passphrase
// minimum, the right key to join, an export for "use the account's data")
// and records every call.
import 'dart:async';

import 'package:application/application.dart';

class FakeSync implements SyncService {
  FakeSync({this.start = const SyncStartFresh(), this.on = false});

  SyncStart start;

  /// When set, prepare() fails with it.
  SyncSetupProblem? prepareProblem;
  bool on;
  bool canUndoJoin = false;
  int pending = 0;
  SyncOutcome? lastResult;
  DateTime? lastSyncAt;

  /// What the next syncNow() reports.
  SyncOutcome next = SyncOutcome.upToDate;
  final reviewItems = <SyncReviewView>[];
  final calls = <String>[];

  static final words = [for (var i = 1; i <= 24; i++) 'word$i'];
  static const check = (3, 17);
  static const passphrase = 'a long enough passphrase';

  final _changes = StreamController<void>.broadcast();
  void changed() => _changes.add(null);

  @override
  Future<SyncStatus> status() async => SyncStatus(
        on: on,
        lastResult: lastResult,
        lastSyncAt: lastSyncAt,
        pending: pending,
        reviews: reviewItems.length,
        canUndoJoin: canUndoJoin,
      );

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield await status();
    await for (final _ in _changes.stream) {
      yield await status();
    }
  }

  @override
  Future<SyncStart> prepare() async {
    calls.add('prepare');
    final p = prepareProblem;
    if (p != null) throw SyncSetupException(p);
    return start;
  }

  @override
  Future<RecoveryKeyOffer> offerRecoveryKey() async {
    calls.add('offer');
    return RecoveryKeyOffer(words: words, qrText: 'LIFEFLOW RECOVERY 1 ${words.join(' ').toUpperCase()}', check: check);
  }

  SyncSetupResult _turnOn() {
    on = true;
    lastResult = SyncOutcome.upToDate;
    lastSyncAt = DateTime(2026, 11, 16, 10, 5);
    changed();
    return SyncSetupResult(firstSync: SyncReport(SyncOutcome.upToDate));
  }

  @override
  Future<SyncSetupResult> startWithRecoveryKey((String, String) answers) async {
    calls.add('startKey:${answers.$1}:${answers.$2}');
    if (answers.$1.trim() != words[check.$1 - 1] || answers.$2.trim() != words[check.$2 - 1]) {
      return const SyncSetupResult.failed(SyncSetupProblem.recoveryKeyNotConfirmed);
    }
    return _turnOn();
  }

  @override
  Future<SyncSetupResult> startWithPassphrase(String p) async {
    calls.add('startPassphrase');
    if (p.length < 12) return const SyncSetupResult.failed(SyncSetupProblem.passphraseTooShort);
    return _turnOn();
  }

  @override
  Future<SyncSetupResult> join(JoinChoice choice, {String? recoveryKey, String? passphrase}) async {
    calls.add('join:${choice.name}');
    if (recoveryKey != null && recoveryKey.trim() != words.join(' ')) {
      return const SyncSetupResult.failed(SyncSetupProblem.wrongRecoveryKey);
    }
    if (recoveryKey == null && passphrase != FakeSync.passphrase) {
      return const SyncSetupResult.failed(SyncSetupProblem.wrongPassphrase);
    }
    final r = _turnOn();
    canUndoJoin = true;
    changed();
    return SyncSetupResult(
      firstSync: r.firstSync,
      export: choice == JoinChoice.useAccountOnly
          ? const ExportFile(suggestedName: 'before-sync.lifeflow.json', contents: '{}', taskCount: 1)
          : null,
    );
  }

  @override
  Future<SyncSetupResult> undoJoin() async {
    calls.add('undoJoin');
    on = false;
    canUndoJoin = false;
    changed();
    return const SyncSetupResult();
  }

  @override
  Future<SyncReport> syncNow() async {
    calls.add('syncNow');
    lastResult = next;
    lastSyncAt = DateTime(2026, 11, 16, 10, 30);
    pending = 0;
    changed();
    return SyncReport(next);
  }

  @override
  Future<SyncSetupResult> turnOff() async {
    calls.add('turnOff');
    on = false;
    canUndoJoin = false;
    changed();
    return const SyncSetupResult();
  }

  @override
  Future<SyncSetupResult> deleteServerData() async {
    calls.add('deleteServerData');
    on = false;
    changed();
    return const SyncSetupResult();
  }

  @override
  Future<List<SyncReviewView>> reviews() async => List.of(reviewItems);

  @override
  Future<SyncSetupResult> resolveReview(String id, {required bool takeOther}) async {
    calls.add('resolve:$id:${takeOther ? 'other' : 'kept'}');
    reviewItems.removeWhere((r) => r.id == id);
    changed();
    return const SyncSetupResult();
  }

  void dispose() => _changes.close();
}
