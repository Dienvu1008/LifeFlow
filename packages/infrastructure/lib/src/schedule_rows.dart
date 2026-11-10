// Writing schedule and exception rows of a task or an event inside a
// command's transaction (P02 T4/T5, ADR-0030/0031). Shared by the task and
// the event handlers so both follow the same rules: the payload is checked
// again (untrusted), every written row gets its own version and an outbox
// row under the command's operation (LF-INV-VER-001, LF-INV-OUTBOX-001), and
// nothing is hard-deleted (SYNC-004).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'app_database.dart';
import 'schedule_mapping.dart';

class ScheduleRows {
  ScheduleRows(this.db, this.cmd, this.subjectType, this.subjectId, this.ownerId, this.now);
  final AppDatabase db;
  final Command cmd;
  final String subjectType;
  final String subjectId;
  final String ownerId;
  final DateTime now;

  String get scheduleId => scheduleIdOf(subjectType, subjectId);

  Future<void> outbox(String entityType, String entityId, String opType, int? base, Object row) =>
      db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: entityId,
            entityType: entityType,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: opType,
            baseVersion: Value(base),
            payload: jsonEncode(row),
            createdAt: now,
          ));

  Future<Schedule?> current() =>
      (db.select(db.schedules)..where((s) => s.id.equals(scheduleId))).getSingleOrNull();

  /// The live (not cleared) schedule, or null.
  Future<Schedule?> live() async {
    final c = await current();
    return c != null && c.deletedAt == null ? c : null;
  }

  /// Writes the schedule from [fields] (the JSON of the schedule columns,
  /// untrusted) and returns it with its kernel types.
  Future<(Schedule, tk.ScheduleSpec, tk.RecurrenceRule?, Schedule?)> write(Map<String, Object?> fields) async {
    final previous = await current();
    final row = <String, Object?>{
      ...fields,
      'id': scheduleId,
      'subjectType': subjectType,
      'subjectId': subjectId,
      'workspaceId': cmd.workspaceId,
      'ownerId': ownerId,
      'version': (previous?.version ?? 0) + 1,
      'createdAt': (previous?.createdAt ?? now).millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
      'deletedAt': null,
      'deletedBy': null,
    };
    final Schedule schedule;
    try {
      schedule = Schedule.fromJson(row);
    } catch (_) {
      throw DomainRejection('the schedule cannot be read');
    }
    final (spec, rule) = read(schedule); // the payload is untrusted: full check
    await db.into(db.schedules).insertOnConflictUpdate(schedule.toCompanion(false));
    await outbox('schedule', scheduleId, previous == null ? 'create' : 'update', previous?.version,
        schedule.toJson());
    return (schedule, spec, rule, previous);
  }

  /// Clears the live schedule (tombstone).
  Future<void> clear(Schedule live) async {
    final cleared = live.copyWith(
        deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()),
        version: live.version + 1, updatedAt: now);
    await db.into(db.schedules).insertOnConflictUpdate(cleared.toCompanion(false));
    await outbox('schedule', scheduleId, 'delete', live.version, cleared.toJson());
  }

  /// The original date in the payload, checked to be an occurrence of the
  /// live repeating schedule.
  Future<(Schedule, LocalDate)> occurrence() async {
    final s = await live();
    if (s == null) throw DomainRejection('the item has no schedule');
    final (spec, rule) = read(s);
    if (rule == null) throw DomainRejection('the item does not repeat');
    final LocalDate original;
    try {
      original = LocalDate.parse(cmd.payload['originalDate'] as String);
    } catch (_) {
      throw DomainRejection('bad occurrence date');
    }
    if (!tk.isRuleDate(rule, spec, original)) {
      throw DomainRejection('$original is not an occurrence of this item');
    }
    return (s, original);
  }

  Future<OccurrenceException?> _exception(String id) =>
      (db.select(db.occurrenceExceptions)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Writes the change of one occurrence.
  Future<void> writeException(LocalDate original, tk.ExceptionKind kind) async {
    final id = exceptionIdOf(subjectType, subjectId, original);
    final existing = await _exception(id);
    final fields = exceptionFields(subjectType, subjectId, tk.OccurrenceException(original, kind));
    final row = OccurrenceException(
      id: id,
      workspaceId: cmd.workspaceId,
      ownerId: ownerId,
      version: (existing?.version ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      subjectType: subjectType,
      subjectId: subjectId,
      originalDate: '$original',
      kind: fields.kind.value,
      moveDate: fields.moveDate.value,
      moveTime: fields.moveTime.value,
      patch: fields.patch.value,
    );
    await db.into(db.occurrenceExceptions).insertOnConflictUpdate(row.toCompanion(false));
    await outbox('exception', id, existing == null ? 'create' : 'update', existing?.version, row.toJson());
  }

  /// Removes the change of one occurrence (tombstone).
  Future<void> clearException(LocalDate original) async {
    final id = exceptionIdOf(subjectType, subjectId, original);
    final existing = await _exception(id);
    if (existing == null || existing.deletedAt != null) {
      throw DomainRejection('this occurrence has no change to remove');
    }
    final cleared = existing.copyWith(
        deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()),
        version: existing.version + 1, updatedAt: now);
    await db.into(db.occurrenceExceptions).insertOnConflictUpdate(cleared.toCompanion(false));
    await outbox('exception', id, 'delete', existing.version, cleared.toJson());
  }

  /// A move from the payload (moveDate, moveTime?), checked.
  tk.MoveOccurrence move(Schedule s) {
    final LocalDate to;
    TimeOfDayValue? at;
    try {
      to = LocalDate.parse(cmd.payload['moveDate'] as String);
      final t = cmd.payload['moveTime'] as String?;
      at = t == null ? null : TimeOfDayValue.parse(t);
    } catch (_) {
      throw DomainRejection('bad move date or time');
    }
    if (at != null && s.startTime == null) {
      throw DomainRejection('an item without a start time cannot move to a time');
    }
    return tk.MoveOccurrence(to, toTime: at);
  }

  static (tk.ScheduleSpec, tk.RecurrenceRule?) read(Schedule s) {
    try {
      return readSchedule(s);
    } on BadScheduleRow catch (e) {
      throw DomainRejection('invalid schedule (${e.why})');
    }
  }
}
