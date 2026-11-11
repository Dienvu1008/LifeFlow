// P03 T3 (ADR-0038): focus commands and reads for the active profile.
// Every write goes through the gateway with the FocusCommandHandler.
import 'package:application/application.dart';
import 'package:domain/domain.dart' as d;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'focus_command_handler.dart';
import 'profile_store.dart';

/// The read model of a stored row. A row that cannot be read is still
/// shown (as unrecoverable), never hidden.
FocusSessionView focusViewOf(FocusSessionRow r, {String? taskTitle}) {
  final s = focusSessionOfRow(r);
  if (s == null) {
    return FocusSessionView(
      id: r.id,
      mode: FocusSessionMode.values.where((m) => m.name == r.mode).firstOrNull ?? FocusSessionMode.stopwatch,
      status: FocusSessionStatus.unrecoverable,
      startedAt: Instant.fromMillis(r.startedAt),
      taskId: r.taskId,
      taskTitle: taskTitle,
    );
  }
  return FocusSessionView(
    id: s.id,
    mode: FocusSessionMode.values.byName(s.mode.name),
    status: FocusSessionStatus.values.byName(s.state.name),
    startedAt: s.startedAt,
    taskId: s.taskId,
    taskTitle: taskTitle,
    occurrenceDate: s.occurrenceDate,
    planned: s.planned,
    pausedTotal: s.pausedTotal,
    pausedAt: s.pausedAt,
    endedAt: s.endedAt,
  );
}

class DriftFocusService implements FocusService {
  DriftFocusService(this.db, this.gateway, {this.clock = const SystemClock()})
      : _store = ProfileStore(db),
        _handler = FocusCommandHandler(clock: clock);

  final AppDatabase db;
  final CommandGateway gateway;
  final Clock clock;
  final ProfileStore _store;
  final FocusCommandHandler _handler;
  final _uuid = const Uuid();

  Future<CommandResult> _run(String type, Map<String, Object?> payload, {Version? expected}) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: type,
        payload: payload,
        expectedVersion: expected,
        issuedAt: clock.now(),
      ),
      _handler,
    );
  }

  Future<CommandResult> _update(String type, String id, String op, [Map<String, Object?> extra = const {}]) async {
    final row = await (db.select(db.focusSessions)..where((s) => s.id.equals(id))).getSingleOrNull();
    if (row == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'focus session not found');
    return _run(type, {'op': op, 'id': id, ...extra}, expected: Version(row.version));
  }

  @override
  Future<CommandResult> start({
    required FocusSessionMode mode,
    Duration? planned,
    String? taskId,
    LocalDate? occurrenceDate,
  }) =>
      _run('StartFocusSession', {
        'op': 'start',
        'id': _uuid.v7(),
        'mode': mode.name,
        'plannedMs': planned?.inMilliseconds,
        'taskId': taskId,
        'occurrenceDate': occurrenceDate?.toString(),
      });

  @override
  Future<CommandResult> pause(String id) => _update('PauseFocusSession', id, 'pause');

  @override
  Future<CommandResult> resume(String id) => _update('ResumeFocusSession', id, 'resume');

  @override
  Future<CommandResult> end(String id, {required bool count}) =>
      _update('EndFocusSession', id, 'end', {'count': count, 'at': 'now'});

  @override
  Future<CommandResult> cancel(String id) => _update('CancelFocusSession', id, 'cancel');

  @override
  Future<CommandResult> resolveOverdue(String id, OverdueChoice choice) => switch (choice) {
        OverdueChoice.countToPlannedEnd => _update('EndFocusSession', id, 'end', {'count': true, 'at': 'plannedEnd'}),
        OverdueChoice.countToNow => _update('EndFocusSession', id, 'end', {'count': true, 'at': 'now'}),
        OverdueChoice.discard => _update('CancelFocusSession', id, 'cancel'),
      };

  Future<FocusSessionView> _viewOf(String id) async {
    final r = await (db.select(db.focusSessions)..where((s) => s.id.equals(id))).getSingle();
    final t = r.taskId == null
        ? null
        : await (db.select(db.tasks)..where((t) => t.id.equals(r.taskId!) & t.deletedAt.isNull())).getSingleOrNull();
    return focusViewOf(r, taskTitle: t?.title);
  }

  @override
  Future<FocusLaunch> recoverOnLaunch() async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const NoActiveFocus();
    final active = await (db.select(db.focusSessions)
          ..where((s) =>
              s.workspaceId.equals(profile.activeWorkspaceId.value) &
              s.state.isIn(activeFocusStates) &
              s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt), (s) => OrderingTerm.desc(s.id)]))
        .get();
    if (active.isEmpty) return const NoActiveFocus();
    // D2: only the newest continues (two can meet after a restore merge);
    // the others are kept as unrecoverable, marked while the newest is active.
    for (final older in active.skip(1)) {
      await _run('MarkFocusSessionUnrecoverable', {'op': 'markUnrecoverable', 'id': older.id, 'cause': 'superseded'},
          expected: Version(older.version));
    }
    final newest = active.first;
    final s = focusSessionOfRow(newest);
    final recovery = s == null ? null : d.FocusSessionMachine.recover(s, clock.now());
    switch (recovery) {
      case d.ResumeAsItWas():
        return FocusResumed(await _viewOf(newest.id));
      case d.AskPomodoroOverdue(:final plannedEnd):
        return FocusOverdue(await _viewOf(newest.id), plannedEnd);
      case d.Unrecoverable() || null:
        await _run('MarkFocusSessionUnrecoverable', {'op': 'markUnrecoverable', 'id': newest.id, 'cause': 'untrusted'},
            expected: Version(newest.version));
        final reason = recovery is d.Unrecoverable ? recovery.reason : 'the session cannot be read';
        return FocusUnrecoverable(await _viewOf(newest.id), reason);
    }
  }
}

class DriftFocusQueries implements FocusQueries {
  DriftFocusQueries(this.db) : _store = ProfileStore(db);
  final AppDatabase db;
  final ProfileStore _store;

  Future<String?> _workspace() async => (await _store.getActiveProfile())?.activeWorkspaceId.value;

  @override
  Stream<FocusSessionView?> watchActive() async* {
    final ws = await _workspace();
    if (ws == null) {
      yield null;
      return;
    }
    final query = db.select(db.focusSessions).join([
      leftOuterJoin(db.tasks, db.tasks.id.equalsExp(db.focusSessions.taskId) & db.tasks.deletedAt.isNull()),
    ])
      ..where(db.focusSessions.workspaceId.equals(ws) &
          db.focusSessions.state.isIn(activeFocusStates) &
          db.focusSessions.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(db.focusSessions.startedAt), OrderingTerm.desc(db.focusSessions.id)])
      ..limit(1);
    yield* query.watch().map((rows) => rows.isEmpty
        ? null
        : focusViewOf(rows.first.readTable(db.focusSessions), taskTitle: rows.first.readTableOrNull(db.tasks)?.title));
  }

  @override
  Future<List<FocusSessionView>> unrecoverable() async {
    final ws = await _workspace();
    if (ws == null) return const [];
    final rows = await (db.select(db.focusSessions)
          ..where((s) => s.workspaceId.equals(ws) & s.state.equals('unrecoverable') & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
    return [for (final r in rows) focusViewOf(r)];
  }
}
