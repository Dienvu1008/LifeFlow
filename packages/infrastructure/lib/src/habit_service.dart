// P03 T4 (ADR-0039): habit, target and measurement commands and the
// tracking reads for the active profile. "Today" is the device's date in
// its zone (DeviceTime), passed in the payload so the store never guesses
// a zone.
import 'package:application/application.dart';
import 'package:domain/domain.dart' as d;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'habit_tracking.dart';
import 'measurement_command_handler.dart';
import 'profile_store.dart';
import 'task_command_handler.dart';

TargetInput targetInputOf(d.MeasurableTarget t) => TargetInput(
      kind: TargetKind.values.byName(t.type.name),
      min: t.min,
      max: t.max,
      unit: t.unit,
      aggregation: TargetAggregationKind.values.byName(t.aggregation.name),
    );

Map<String, Object?> targetPayloadOf(TargetInput t) =>
    {'type': t.kind.name, 'min': t.min, 'max': t.max, 'unit': t.unit, 'aggregation': t.aggregation.name};

PeriodOutcome _outcomeView(d.HabitOutcome o) => PeriodOutcome.values.byName(o.name);

class DriftHabitService implements HabitService {
  DriftHabitService(this.db, this.gateway, this.time, {this.clock = const SystemClock(), this.deviceId})
      : _store = ProfileStore(db),
        _tasks = TaskCommandHandler(),
        _measurements = MeasurementCommandHandler(clock: clock),
        _close = PeriodCloseHandler(clock: clock);

  final AppDatabase db;
  final CommandGateway gateway;
  final DeviceTime time;
  final Clock clock;

  /// Kept with each measurement (LF-INV-HEALTH-004).
  final String? deviceId;
  final ProfileStore _store;
  final TaskCommandHandler _tasks;
  final MeasurementCommandHandler _measurements;
  final PeriodCloseHandler _close;
  final _uuid = const Uuid();

  LocalDate _today() => tk.dateAt(time.now(), time.zone());

  Future<CommandResult> _run(CommandHandler handler, String type, Map<String, Object?> payload,
      {Version? expected}) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: type,
        payload: {...payload, 'today': '${_today()}'},
        expectedVersion: expected,
        issuedAt: clock.now(),
      ),
      handler,
    );
  }

  Future<CommandResult> _task(String type, String taskId, Map<String, Object?> payload) async {
    final t = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (t == null || t.deletedAt != null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'task not found');
    }
    return _run(_tasks, type, {...payload, 'id': taskId}, expected: Version(t.version));
  }

  @override
  Future<CommandResult> setHabit(String taskId, {required bool isHabit}) =>
      _task('SetTaskHabit', taskId, {'op': 'setHabit', 'isHabit': isHabit});

  @override
  Future<CommandResult> setTarget(String taskId, TargetInput? target) async {
    // D9: the periods that ended keep the target they were judged with.
    await closePeriods(taskId: taskId);
    return _task(target == null ? 'ClearTaskTarget' : 'SetTaskTarget', taskId,
        {'op': 'setTarget', 'target': target == null ? null : targetPayloadOf(target)});
  }

  @override
  Future<CommandResult> setCompletion(String taskId, CompletionMode mode) =>
      _task('SetTaskCompletion', taskId, {'op': 'setCompletion', 'policy': mode.name});

  @override
  Future<CommandResult> recordMeasurement(String taskId, double value,
          {LocalDate? date, String? note, bool confirmClosed = false}) =>
      _run(_measurements, 'RecordMeasurement', {
        'op': 'record',
        'id': _uuid.v7(),
        'taskId': taskId,
        'value': value,
        'date': '${date ?? _today()}',
        'note': note,
        'deviceId': deviceId,
        'confirmClosed': confirmClosed,
      });

  @override
  Future<CommandResult> correctMeasurement(String measurementId, double? value,
          {String? note, bool confirmClosed = false}) =>
      _run(_measurements, value == null ? 'WithdrawMeasurement' : 'CorrectMeasurement', {
        'op': 'correct',
        'id': _uuid.v7(),
        'supersedesId': measurementId,
        'value': value,
        'note': note,
        'deviceId': deviceId,
        'confirmClosed': confirmClosed,
      });

  @override
  Future<int> closePeriods({String? taskId}) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return 0;
    final rows = await (db.select(db.tasks)
          ..where((t) =>
              t.workspaceId.equals(profile.activeWorkspaceId.value) &
              t.deletedAt.isNull() &
              (t.isHabit.equals(true) | t.targetType.isNotNull()) &
              (taskId == null ? const Constant(true) : t.id.equals(taskId))))
        .get();
    final today = _today();
    var n = 0;
    for (final row in rows) {
      final t = await TrackedTask.load(db, row.id);
      if (t == null) continue;
      for (final r in t.endedResults(today)) {
        if (t.stored.containsKey(r.id)) continue;
        final res = await _run(_close, 'ClosePeriod', {'op': 'close', 'id': r.id, 'taskId': row.id});
        if (res is CommandOk) n++;
      }
    }
    return n;
  }
}

class DriftHabitQueries implements HabitQueries {
  DriftHabitQueries(this.db, this.time) : _store = ProfileStore(db);
  final AppDatabase db;
  final DeviceTime time;
  final ProfileStore _store;

  LocalDate _today() => tk.dateAt(time.now(), time.zone());

  @override
  Future<TrackingView?> tracking(String taskId) async {
    final profile = await _store.getActiveProfile();
    final t = await TrackedTask.load(db, taskId);
    if (profile == null || t == null || t.row.workspaceId != profile.activeWorkspaceId.value) return null;
    final rows = await (db.select(db.measurements)
          ..where((m) => m.taskId.equals(taskId) & m.deletedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.recordedAt), (m) => OrderingTerm.desc(m.id)]))
        .get();
    return _view(t, _today(), rows);
  }

  TrackingView _view(TrackedTask t, LocalDate today, List<MeasurementRow> rows) {
    final target = t.target;
    final results = t.results(today);
    final c = t.current(today);
    final outcomes = [for (final (r, _) in results) r.outcome];
    final from30 = today.addDays(-30);
    final recent = [
      for (final (r, _) in results)
        if (r.keyDate != null && !r.keyDate!.isBefore(from30)) r.outcome
    ];
    final current = d.currentMeasurements(t.measurements).map((m) => m.id).toSet();
    LocalDate? since;
    if (t.row.trackedSince != null) since = t.trackedSince;
    return TrackingView(
      taskId: t.row.id,
      title: t.row.title,
      isHabit: t.isHabit,
      isRepeating: t.isRepeating,
      target: target == null ? null : targetInputOf(target),
      completion: t.row.completionPolicy == 'automatic' ? CompletionMode.automatic : CompletionMode.manual,
      trackedSince: since,
      current: c == null
          ? null
          : CurrentPeriodView(
              from: c.$1.from, to: c.$1.to, value: c.$2, progress: PeriodProgress.values.byName(c.$3.name)),
      results: [
        for (final (r, stored) in results)
          PeriodResultView(
            key: r.keyDate,
            isOccurrence: r.kind == 'occurrence',
            outcome: _outcomeView(r.outcome),
            value: r.value,
            target: switch (targetOfJson(r.target)) { final x? => targetInputOf(x), null => null },
            stored: stored,
          ),
      ],
      measurements: [
        for (final m in rows)
          MeasurementView(
            id: m.id,
            value: m.value,
            date: LocalDate.parse(m.localDate),
            recordedAt: Instant(m.recordedAt.toUtc()),
            source: m.source,
            deviceId: m.deviceId,
            note: m.note,
            supersedesId: m.supersedesId,
            withdrawn: m.withdrawn,
            isCurrent: current.contains(m.id),
          ),
      ],
      rate30: d.completionRate(recent).ratio,
      rateAll: d.completionRate(outcomes).ratio,
      streak: d.currentStreak(t.streakInput(today)),
      isCompleteNow: t.row.completionPolicy == 'automatic' && c?.$3 == d.PeriodState.achieved,
    );
  }

  Future<List<TrackingView>> _habits({bool tracked = false}) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const [];
    final rows = await (db.select(db.tasks)
          ..where((t) =>
              t.workspaceId.equals(profile.activeWorkspaceId.value) &
              t.deletedAt.isNull() &
              (tracked ? t.isHabit.equals(true) | t.targetType.isNotNull() : t.isHabit.equals(true)))
          ..orderBy([(t) => OrderingTerm(expression: const CustomExpression<int>('tasks.rowid'))]))
        .get();
    final today = _today();
    return [
      for (final r in rows)
        if (await TrackedTask.load(db, r.id) case final t?)
          _view(
              t,
              today,
              await (db.select(db.measurements)
                    ..where((m) => m.taskId.equals(r.id) & m.deletedAt.isNull())
                    ..orderBy([(m) => OrderingTerm.desc(m.recordedAt), (m) => OrderingTerm.desc(m.id)]))
                  .get()),
    ];
  }

  Stream<T> _follow<T>(Future<T> Function() read) async* {
    yield await read();
    yield* db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.tasks,
          db.schedules,
          db.occurrenceExceptions,
          db.occurrenceCompletions,
          db.measurements,
          db.periodResults,
        ]))
        .asyncMap((_) => read());
  }

  @override
  Stream<List<TrackingView>> watchHabits() => _follow(_habits);

  @override
  Stream<List<TrackingView>> watchTracked() => _follow(() => _habits(tracked: true));

  @override
  Stream<TrackingView?> watchTracking(String taskId) => _follow(() => tracking(taskId));
}
