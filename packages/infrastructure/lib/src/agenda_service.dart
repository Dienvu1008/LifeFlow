// P02 T4 (ADR-0030): scheduling commands and the agenda queries of tasks.
//
// Queries never store occurrences (FR-PLAN-09): candidate series are picked
// by their stored date range (plus series with an occurrence MOVED into the
// window), then expanded by the Time Kernel with the device's limits
// (owner decision D1, LF-INV-PLAN-010).
import 'dart:async';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'profile_store.dart';
import 'schedule_inputs.dart';
import 'schedule_mapping.dart';
import 'task_command_handler.dart';

class DriftTaskScheduling implements TaskScheduling {
  DriftTaskScheduling(this.db, this.gateway) : _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore _store;
  final _handler = TaskCommandHandler();
  final _uuid = const Uuid();

  Future<CommandResult> _run(String type, String taskId, Map<String, Object?> payload) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    }
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null || task.deletedAt != null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'task not found');
    }
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: type,
        payload: {...payload, 'id': taskId},
        expectedVersion: Version(task.version),
        issuedAt: Instant.now(),
      ),
      _handler,
    );
  }

  @override
  Future<CommandResult> setSchedule(String taskId, TaskScheduleInput? schedule) async {
    if (schedule == null) return _run('ClearTaskSchedule', taskId, {'op': 'clearSchedule'});
    final error = scheduleInputError(schedule);
    if (error != null) {
      return CommandFailure(CommandFailureKind.validationFailed, reason: error);
    }
    final fields = scheduleFieldsJson('task', taskId, specOfInput(schedule), ruleOfInput(schedule.repeat));
    return _run('SetTaskSchedule', taskId, {'op': 'setSchedule', 'schedule': fields});
  }

  @override
  Future<CommandResult> changeOccurrence(String taskId, LocalDate originalDate, OccurrenceChange? change) =>
      switch (change) {
        null => _run('ClearOccurrenceChange', taskId, {'op': 'clearException', 'originalDate': '$originalDate'}),
        SkipThisOccurrence() => _run('SkipOccurrence', taskId,
            {'op': 'setException', 'originalDate': '$originalDate', 'kind': 'skip'}),
        MoveThisOccurrence(:final toDate, :final toTime) => _run('MoveOccurrence', taskId, {
            'op': 'setException',
            'originalDate': '$originalDate',
            'kind': 'move',
            'moveDate': '$toDate',
            'moveTime': toTime?.toString(),
          }),
      };

  @override
  Future<CommandResult> setOccurrenceDone(String taskId, LocalDate originalDate, {required bool done}) =>
      _run(done ? 'CompleteOccurrence' : 'ReopenOccurrence', taskId,
          {'op': 'setOccurrenceDone', 'originalDate': '$originalDate', 'done': done});

  @override
  Future<TaskScheduleInput?> scheduleOf(String taskId) async {
    final row = await (db.select(db.schedules)
          ..where((s) => s.id.equals(scheduleIdOf('task', taskId)) & s.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) return null;
    final (spec, rule) = readSchedule(row);
    return scheduleInputOf(spec, rule);
  }
}

/// The device clock and zone (the app supplies the zone from the platform).
class SystemDeviceTime implements DeviceTime {
  SystemDeviceTime(this._zone);
  final String Function() _zone;
  @override
  Instant now() => Instant.now();
  @override
  String zone() => _zone();
}

class DriftAgendaQueries implements AgendaQueries {
  DriftAgendaQueries(this.db, this.time, {tk.OccurrenceLimits Function()? limits})
      : _store = ProfileStore(db),
        _limits = limits ?? (() => tk.OccurrenceLimits.standard);
  final AppDatabase db;
  final DeviceTime time;
  final ProfileStore _store;
  final tk.OccurrenceLimits Function() _limits;

  LocalDate _today() => tk.dateAt(time.now(), time.zone());

  Stream<Agenda> _watch(Future<Agenda> Function() compute) async* {
    yield await compute();
    yield* db
        .tableUpdates(TableUpdateQuery.onAllTables(
            [db.tasks, db.schedules, db.occurrenceExceptions, db.occurrenceCompletions]))
        .asyncMap((_) => compute());
  }

  @override
  Stream<Agenda> watchToday() => _watch(() {
        final today = _today();
        return range(today, today, overdueBefore: today);
      });

  @override
  Stream<Agenda> watchUpcoming({int days = 14}) => _watch(() {
        final today = _today();
        return range(today.addDays(1), today.addDays(days));
      });

  @override
  Stream<Agenda> watchRange(LocalDate from, LocalDate to) => _watch(() => range(from, to));

  /// The agenda of [from]..[to]. With [overdueBefore], one-off tasks planned
  /// or due before that date and still open are added, marked overdue.
  Future<Agenda> range(LocalDate from, LocalDate to, {LocalDate? overdueBefore}) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const Agenda([]);
    final ws = profile.activeWorkspaceId.value;
    final tasks = {
      for (final t in await (db.select(db.tasks)
            ..where((t) => t.workspaceId.equals(ws) & t.deletedAt.isNull()))
          .get())
        t.id: t,
    };

    // Series whose stored range can touch the window, plus series with an
    // occurrence moved into it (a move can leave the stored range).
    final f = '$from', t = '$to';
    final moved = await (db.select(db.occurrenceExceptions)
          ..where((e) =>
              e.subjectType.equals('task') & e.deletedAt.isNull() & e.kind.equals('move') &
              e.moveDate.isBetweenValues(f, t)))
        .get();
    final schedules = await (db.select(db.schedules)
          ..where((s) =>
              s.workspaceId.equals(ws) &
              s.subjectType.equals('task') &
              s.deletedAt.isNull() &
              ((s.firstDate.isSmallerOrEqualValue(t) &
                      (s.lastDate.isNull() | s.lastDate.isBiggerOrEqualValue(f))) |
                  s.subjectId.isIn(moved.map((m) => m.subjectId)) |
                  // Overdue one-offs end before the window.
                  (overdueBefore == null
                      ? const Constant(false)
                      : (s.frequency.isNull() & s.lastDate.isSmallerThanValue('$overdueBefore'))))))
        .get();

    final ids = schedules.map((s) => s.subjectId).toList();
    final exceptions = <String, List<tk.OccurrenceException>>{};
    for (final e in await (db.select(db.occurrenceExceptions)
          ..where((e) => e.subjectType.equals('task') & e.deletedAt.isNull() & e.subjectId.isIn(ids)))
        .get()) {
      exceptions.putIfAbsent(e.subjectId, () => []).add(exceptionOf(e));
    }
    final done = <String>{
      for (final c in await (db.select(db.occurrenceCompletions)
            ..where((c) => c.deletedAt.isNull() & c.taskId.isIn(ids)))
          .get())
        c.id,
    };

    final window = tk.DateWindow(from, to);
    final limits = _limits();
    final items = <AgendaItem>[];
    var truncated = false;
    for (final s in schedules) {
      final task = tasks[s.subjectId];
      if (task == null) continue; // trashed task: its schedule is not shown
      final (spec, rule) = readSchedule(s);
      final r = tk.occurrencesInWindow(
        seriesId: task.id,
        spec: spec,
        rule: rule,
        exceptions: exceptions[task.id] ?? const [],
        window: window,
        limits: limits,
      );
      truncated |= r.truncated;
      for (final o in r.occurrences) {
        items.add(_item(task, o, rule != null, done));
      }
      if (overdueBefore != null && rule == null && task.status != 'done') {
        final last = (spec.end ?? spec.start ?? spec.deadline)!.date;
        if (last.isBefore(overdueBefore)) {
          final o = tk.Occurrence(seriesId: task.id, originalDate: (spec.start ?? spec.end ?? spec.deadline)!.date, schedule: spec);
          items.add(_item(task, o, false, done, overdue: true));
        }
      }
    }
    items.sort(_byTime);
    if (items.length > limits.maxOccurrences) {
      truncated = true;
      items.removeRange(limits.maxOccurrences, items.length);
    }
    return Agenda(items, truncated: truncated);
  }

  AgendaItem _item(Task task, tk.Occurrence o, bool repeating, Set<String> done, {bool overdue = false}) =>
      AgendaItem(
        taskId: task.id,
        title: task.title,
        originalDate: o.originalDate,
        start: inputOf(o.schedule.start),
        end: inputOf(o.schedule.end),
        deadline: inputOf(o.schedule.deadline),
        isRepeating: repeating,
        isDone: repeating ? done.contains(completionIdOf(task.id, o.originalDate)) : task.status == 'done',
        isMoved: o.isException,
        isOverdue: overdue,
      );

  static int _byTime(AgendaItem a, AgendaItem b) {
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    final c = a.date.compareTo(b.date);
    if (c != 0) return c;
    int minute(AgendaItem i) => (i.start ?? i.end)?.time?.minuteOfDay ?? -1;
    final m = minute(a).compareTo(minute(b));
    if (m != 0) return m;
    final n = a.title.compareTo(b.title);
    return n != 0 ? n : a.taskId.compareTo(b.taskId);
  }
}
