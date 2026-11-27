// P06c E1 (ADR-0095): writing the extra times of a task or an event inside a
// command's transaction. Shared by the task and the event handlers, as
// ScheduleRows is: the payload is checked again (untrusted), every written
// row gets its own version and an outbox row under the command's operation
// (LF-INV-VER-001, LF-INV-OUTBOX-001), and nothing is hard-deleted
// (SYNC-004).
//
// payload ops (on the item's own command, which moves the item's version):
//   addExtra      id (the item), extraId (new), schedule (the time as schedule
//                 columns JSON: a start, maybe an end; no repeat, no deadline)
//   changeExtra   id, extraId, schedule
//   removeExtra   id, extraId
//   setExtraDone  id, extraId, done           (tasks only; a time that does not repeat)
// P06c E3 (ADR-0097): an extra time may repeat. Then (schedule carries the
// repeat columns) one time of it is changed or ticked like one of a schedule:
//   setExtraException    id, extraId, originalDate, kind (skip|move for a task;
//                        skip|cancel|move|edit for an event), moveDate?, ...
//   clearExtraException  id, extraId, originalDate
//   setExtraOccurrenceDone  id, extraId, originalDate, done   (tasks only)
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'app_database.dart';
import 'schedule_mapping.dart';
import 'schedule_rows.dart';

const extraTimeOps = {
  'addExtra',
  'changeExtra',
  'removeExtra',
  'setExtraDone',
  'setExtraException',
  'clearExtraException',
  'setExtraOccurrenceDone',
};

class ExtraTimeRows {
  ExtraTimeRows(this.db, this.cmd, this.subjectType, this.subjectId, this.ownerId, this.now);
  final AppDatabase db;
  final Command cmd;
  final String subjectType;
  final String subjectId;
  final String ownerId;
  final DateTime now;

  Future<void> _outbox(String id, String opType, int? base, Object row) => db.into(db.outbox).insert(OutboxCompanion.insert(
        operationId: cmd.operationId,
        entityId: id,
        entityType: 'extraTime',
        workspaceId: cmd.workspaceId,
        actorId: cmd.actor.toString(),
        operationType: opType,
        baseVersion: Value(base),
        payload: jsonEncode(row),
        createdAt: now,
      ));

  Future<ExtraTime?> _row(String id) => (db.select(db.extraTimes)..where((e) => e.id.equals(id))).getSingleOrNull();

  String _extraId() {
    final id = cmd.payload['extraId'];
    if (id is! String || id.isEmpty || id.length > 64) throw DomainRejection('an extra time needs an id');
    return id;
  }

  /// The live extra time [id] of this item.
  Future<ExtraTime> _live(String id) async {
    final r = await _row(id);
    if (r == null ||
        r.deletedAt != null ||
        r.subjectType != subjectType ||
        r.subjectId != subjectId ||
        r.workspaceId != cmd.workspaceId) {
      throw DomainRejection('extra time not found');
    }
    return r;
  }

  /// The time columns of the payload's schedule, checked: a start, maybe an
  /// end, nothing else (the payload is untrusted).
  ExtraTimesCompanion _times() {
    final fields = (cmd.payload['schedule'] as Map?)?.cast<String, Object?>();
    if (fields == null) throw DomainRejection('a time is needed');
    final Schedule asSchedule;
    try {
      asSchedule = Schedule.fromJson({
        ...fields,
        'id': scheduleIdOf(subjectType, subjectId),
        'subjectType': subjectType,
        'subjectId': subjectId,
        'workspaceId': cmd.workspaceId,
        'ownerId': ownerId,
        'version': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'deletedAt': null,
        'deletedBy': null,
      });
    } catch (_) {
      throw DomainRejection('the time cannot be read');
    }
    final (spec, rule) = ScheduleRows.read(asSchedule);
    if (spec.start == null) throw DomainRejection('an extra time needs a start');
    if (spec.deadline != null) throw DomainRejection('an extra time has no deadline');
    final range = dateRangeOf(spec, rule);
    return ExtraTimesCompanion(
      startDate: Value(asSchedule.startDate!),
      startTime: Value(asSchedule.startTime),
      startZone: Value(asSchedule.startZone),
      endDate: Value(asSchedule.endDate),
      endTime: Value(asSchedule.endTime),
      endZone: Value(asSchedule.endZone),
      firstDate: Value('${range.first}'),
      lastDate: Value(range.last?.toString()),
      frequency: Value(asSchedule.frequency),
      interval: Value(asSchedule.interval),
      weekdays: Value(asSchedule.weekdays),
      endKind: Value(asSchedule.endKind),
      endDateRule: Value(asSchedule.endDateRule),
      endCount: Value(asSchedule.endCount),
      monthEndRule: Value(asSchedule.monthEndRule),
      weekStart: Value(asSchedule.weekStart),
    );
  }

  ExtraTime _with(ExtraTime? previous, String id, ExtraTimesCompanion c) => ExtraTime(
        id: id,
        workspaceId: cmd.workspaceId,
        ownerId: previous?.ownerId ?? ownerId,
        version: (previous?.version ?? 0) + 1,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        subjectType: subjectType,
        subjectId: subjectId,
        startDate: c.startDate.value,
        startTime: c.startTime.value,
        startZone: c.startZone.value,
        endDate: c.endDate.value,
        endTime: c.endTime.value,
        endZone: c.endZone.value,
        firstDate: c.firstDate.value,
        lastDate: c.lastDate.value,
        doneAt: previous?.doneAt,
        frequency: c.frequency.value,
        interval: c.interval.value,
        weekdays: c.weekdays.value,
        endKind: c.endKind.value,
        endDateRule: c.endDateRule.value,
        endCount: c.endCount.value,
        monthEndRule: c.monthEndRule.value,
        weekStart: c.weekStart.value,
      );

  /// The live repeating extra time [id] of this item, and the date in the
  /// payload, checked to be one of its times.
  Future<(ExtraTime, LocalDate)> _occurrence(String id) async {
    final x = await _live(id);
    final tk.RecurrenceRule? rule;
    final tk.ScheduleSpec spec;
    try {
      (spec, rule) = readExtra(x);
    } on BadScheduleRow catch (e) {
      throw DomainRejection('invalid extra time (${e.why})');
    }
    if (rule == null) throw DomainRejection('this time does not repeat');
    final LocalDate original;
    try {
      original = LocalDate.parse(cmd.payload['originalDate'] as String);
    } catch (_) {
      throw DomainRejection('bad occurrence date');
    }
    if (!tk.isRuleDate(rule, spec, original)) throw DomainRejection('$original is not one of its times');
    return (x, original);
  }

  /// A move from the payload (moveDate, moveTime?), checked.
  tk.MoveOccurrence _move(ExtraTime x) {
    final LocalDate to;
    TimeOfDayValue? at;
    try {
      to = LocalDate.parse(cmd.payload['moveDate'] as String);
      final t = cmd.payload['moveTime'] as String?;
      at = t == null ? null : TimeOfDayValue.parse(t);
    } catch (_) {
      throw DomainRejection('bad move date or time');
    }
    if (at != null && x.startTime == null) throw DomainRejection('a time without hours cannot move to hours');
    return tk.MoveOccurrence(to, toTime: at);
  }

  /// Tombstones the changes and ticks of a removed extra time.
  Future<void> _dropDependents(String extraId) async {
    for (final e in await (db.select(db.occurrenceExceptions)
          ..where((e) => e.subjectType.equals('extraTime') & e.subjectId.equals(extraId) & e.deletedAt.isNull()))
        .get()) {
      final gone = e.copyWith(
          deletedAt: Value(now),
          deletedBy: Value(cmd.actor.toString()),
          patch: const Value(null),
          version: e.version + 1,
          updatedAt: now);
      await db.into(db.occurrenceExceptions).insertOnConflictUpdate(gone.toCompanion(false));
      await _outboxOf('exception', e.id, 'delete', e.version, gone.toJson());
    }
    for (final c in await (db.select(db.occurrenceCompletions)
          ..where((c) => c.extraId.equals(extraId) & c.deletedAt.isNull()))
        .get()) {
      final gone = c.copyWith(
          deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()), version: c.version + 1, updatedAt: now);
      await db.into(db.occurrenceCompletions).insertOnConflictUpdate(gone.toCompanion(false));
      await _outboxOf('completion', c.id, 'delete', c.version, gone.toJson());
    }
  }

  Future<void> _outboxOf(String type, String id, String opType, int? base, Object row) =>
      db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: id,
            entityType: type,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: opType,
            baseVersion: Value(base),
            payload: jsonEncode(row),
            createdAt: now,
          ));

  /// Changes or clears one time of a repeating extra time. [kindOf] builds
  /// the change (the item's own handler knows what its kind may do).
  Future<({String extraId, Map<String, Object?> change, String event})> applyException(String op,
      {required tk.ExceptionKind Function(ExtraTime x, tk.MoveOccurrence Function() move) kindOf}) async {
    final id = _extraId();
    final (x, original) = await _occurrence(id);
    final rows = ScheduleRows(db, cmd, 'extraTime', id, x.ownerId, now);
    if (op == 'clearExtraException') {
      await rows.clearException(original);
    } else {
      await rows.writeException(original, kindOf(x, () => _move(x)));
    }
    return (
      extraId: id,
      change: {'extra': id, 'occurrence': '$original', 'change': op == 'clearExtraException' ? null : cmd.payload['kind']},
      event: 'ExtraTimeOccurrenceChanged'
    );
  }

  /// Runs [op]; the item's own row was moved by the caller.
  Future<({String extraId, Map<String, Object?> change, String event})> apply(String op,
      {required bool automaticCompletion}) async {
    switch (op) {
      case 'addExtra':
        final id = _extraId();
        if (await _row(id) != null) throw DomainRejection('the extra time already exists');
        final row = _with(null, id, _times());
        await db.into(db.extraTimes).insert(row.toCompanion(false));
        await _outbox(id, 'create', null, row.toJson());
        return (extraId: id, change: {'extra': id, 'start': row.startDate}, event: 'ExtraTimeAdded');

      case 'changeExtra':
        final id = _extraId();
        final before = await _live(id);
        final row = _with(before, id, _times());
        await db.into(db.extraTimes).insertOnConflictUpdate(row.toCompanion(false));
        await _outbox(id, 'update', before.version, row.toJson());
        return (extraId: id, change: {'extra': id, 'start': row.startDate}, event: 'ExtraTimeChanged');

      case 'removeExtra':
        final id = _extraId();
        final before = await _live(id);
        final gone = before.copyWith(
            deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()), version: before.version + 1, updatedAt: now);
        await db.into(db.extraTimes).insertOnConflictUpdate(gone.toCompanion(false));
        await _outbox(id, 'delete', before.version, gone.toJson());
        await _dropDependents(id);
        return (extraId: id, change: {'extra': id, 'removed': true}, event: 'ExtraTimeRemoved');

      case 'setExtraDone':
        // P03 D8: automatic completion is derived, never ticked by hand.
        if (automaticCompletion) throw DomainRejection('the completion is derived from the measurements');
        final id = _extraId();
        final before = await _live(id);
        if (before.frequency != null) {
          throw DomainRejection('a repeating time is ticked one time at a time');
        }
        final done = cmd.payload['done'] == true;
        if ((before.doneAt != null) == done) {
          throw DomainRejection(done ? 'this time is already done' : 'this time is not done');
        }
        final row = before.copyWith(
            doneAt: Value(done ? now : null), version: before.version + 1, updatedAt: now);
        await db.into(db.extraTimes).insertOnConflictUpdate(row.toCompanion(false));
        await _outbox(id, 'update', before.version, row.toJson());
        return (extraId: id, change: {'extra': id, 'done': done}, event: done ? 'ExtraTimeCompleted' : 'ExtraTimeReopened');

      case 'setExtraOccurrenceDone':
        if (subjectType != 'task') throw DomainRejection('only a task can be ticked');
        if (automaticCompletion) throw DomainRejection('the completion is derived from the measurements');
        final id = _extraId();
        final (x, original) = await _occurrence(id);
        final done = cmd.payload['done'] == true;
        final cid = extraCompletionIdOf(id, original);
        final existing = await (db.select(db.occurrenceCompletions)..where((c) => c.id.equals(cid))).getSingleOrNull();
        final isDone = existing != null && existing.deletedAt == null;
        if (done == isDone) {
          throw DomainRejection(done ? 'this time is already done' : 'this time is not done');
        }
        final row = OccurrenceCompletion(
          id: cid,
          workspaceId: cmd.workspaceId,
          ownerId: x.ownerId,
          version: (existing?.version ?? 0) + 1,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          deletedAt: done ? null : now,
          deletedBy: done ? null : cmd.actor.toString(),
          taskId: subjectId,
          originalDate: '$original',
          completedAt: done ? now : existing!.completedAt,
          extraId: id,
        );
        await db.into(db.occurrenceCompletions).insertOnConflictUpdate(row.toCompanion(false));
        await _outboxOf('completion', cid, done ? (existing == null ? 'create' : 'update') : 'delete',
            existing?.version, row.toJson());
        return (
          extraId: id,
          change: {'extra': id, 'occurrence': '$original', 'done': done},
          event: done ? 'ExtraTimeOccurrenceCompleted' : 'ExtraTimeOccurrenceReopened'
        );
    }
    throw DomainRejection('unknown op: $op');
  }
}
