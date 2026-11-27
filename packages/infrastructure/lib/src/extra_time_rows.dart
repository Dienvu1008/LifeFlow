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
//   setExtraDone  id, extraId, done           (tasks only)
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';
import 'schedule_mapping.dart';
import 'schedule_rows.dart';

const extraTimeOps = {'addExtra', 'changeExtra', 'removeExtra', 'setExtraDone'};

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
    if (rule != null) throw DomainRejection('an extra time does not repeat');
    if (spec.start == null) throw DomainRejection('an extra time needs a start');
    if (spec.deadline != null) throw DomainRejection('an extra time has no deadline');
    final range = dateRangeOf(spec, null);
    return ExtraTimesCompanion(
      startDate: Value(asSchedule.startDate!),
      startTime: Value(asSchedule.startTime),
      startZone: Value(asSchedule.startZone),
      endDate: Value(asSchedule.endDate),
      endTime: Value(asSchedule.endTime),
      endZone: Value(asSchedule.endZone),
      firstDate: Value('${range.first}'),
      lastDate: Value('${range.last}'),
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
      );

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
        return (extraId: id, change: {'extra': id, 'removed': true}, event: 'ExtraTimeRemoved');

      case 'setExtraDone':
        // P03 D8: automatic completion is derived, never ticked by hand.
        if (automaticCompletion) throw DomainRejection('the completion is derived from the measurements');
        final id = _extraId();
        final before = await _live(id);
        final done = cmd.payload['done'] == true;
        if ((before.doneAt != null) == done) {
          throw DomainRejection(done ? 'this time is already done' : 'this time is not done');
        }
        final row = before.copyWith(
            doneAt: Value(done ? now : null), version: before.version + 1, updatedAt: now);
        await db.into(db.extraTimes).insertOnConflictUpdate(row.toCompanion(false));
        await _outbox(id, 'update', before.version, row.toJson());
        return (extraId: id, change: {'extra': id, 'done': done}, event: done ? 'ExtraTimeCompleted' : 'ExtraTimeReopened');
    }
    throw DomainRejection('unknown op: $op');
  }
}
