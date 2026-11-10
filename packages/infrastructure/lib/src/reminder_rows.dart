// P02 T7 (ADR-0034): the reminders of a task or an event, written inside
// the command of that task or event (the reminder is a capability of the
// aggregate, planning-scheduling.md §10). Same rules as ScheduleRows: the
// payload is checked again, every written row gets a version and an outbox
// row, nothing is hard-deleted.
//
//   setReminders  payload: id, reminders: [{"before": minutes} | {"at": utcMillis}]
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'app_database.dart';
import 'schedule_rows.dart';

/// Row id of the [index]-th reminder of an item.
String reminderIdOf(String subjectType, String subjectId, int index) => '$subjectType:$subjectId#$index';

/// The kernel rule of a stored row, or null when the row is unreadable.
tk.ReminderRule? reminderRuleOf(Reminder r) {
  final m = r.offsetMinutes;
  final at = r.atUtc;
  if (m != null && at == null) return tk.RemindBefore(m);
  if (at != null && m == null) return tk.RemindAt(Instant(at.toUtc()));
  return null;
}

/// The payload list as kernel rules (untrusted input), checked.
List<tk.ReminderRule> remindersOfPayload(Object? raw) {
  if (raw is! List) throw DomainRejection('reminders must be a list');
  final rules = <tk.ReminderRule>[];
  for (final e in raw) {
    if (e is! Map) throw DomainRejection('bad reminder');
    final before = e['before'];
    final at = e['at'];
    if (before is int && at == null) {
      rules.add(tk.RemindBefore(before));
    } else if (at is int && before == null) {
      rules.add(tk.RemindAt(Instant.fromMillis(at)));
    } else {
      throw DomainRejection('a reminder is minutes before or a time');
    }
  }
  switch (tk.validateReminders(rules)) {
    case Err(:final error):
      throw DomainRejection(switch (error) {
        tk.ReminderError.tooMany => 'at most ${tk.maxRemindersPerItem} reminders',
        tk.ReminderError.offsetOutOfRange => 'a reminder can be at most 28 days before',
        tk.ReminderError.duplicate => 'the same reminder twice',
      });
    case Ok():
  }
  return rules;
}

/// The JSON of [r] for a command payload.
Map<String, Object?> reminderPayloadOf(ReminderInput r) => switch (r) {
      RemindMinutesBefore(:final minutes) => {'before': minutes},
      RemindAtInstant(:final at) => {'at': at.millis},
    };

ReminderInput reminderInputOf(tk.ReminderRule r) => switch (r) {
      tk.RemindBefore(:final minutes) => RemindMinutesBefore(minutes),
      tk.RemindAt(:final at) => RemindAtInstant(at),
    };

/// Live reminder rules of an item, in order.
Future<List<tk.ReminderRule>> liveReminders(AppDatabase db, String subjectType, String subjectId) async {
  final rows = await (db.select(db.reminders)
        ..where((r) => r.subjectType.equals(subjectType) & r.subjectId.equals(subjectId) & r.deletedAt.isNull()))
      .get();
  rows.sort((a, b) => a.id.compareTo(b.id)); // `#0`..`#4`
  return rows.map(reminderRuleOf).nonNulls.toList();
}

/// Replaces the reminders of the item: rows `#0..#n-1` hold the new list;
/// other live rows become tombstones. Returns the number written.
Future<int> replaceReminders(ScheduleRows rows, List<tk.ReminderRule> rules) async {
  final db = rows.db;
  final existing = {
    for (final r in await (db.select(db.reminders)
          ..where((r) => r.subjectType.equals(rows.subjectType) & r.subjectId.equals(rows.subjectId)))
        .get())
      r.id: r,
  };
  for (var i = 0; i < rules.length; i++) {
    final id = reminderIdOf(rows.subjectType, rows.subjectId, i);
    final old = existing.remove(id);
    final rule = rules[i];
    final row = Reminder(
      id: id,
      workspaceId: rows.cmd.workspaceId,
      ownerId: rows.ownerId,
      version: (old?.version ?? 0) + 1,
      createdAt: old?.createdAt ?? rows.now,
      updatedAt: rows.now,
      subjectType: rows.subjectType,
      subjectId: rows.subjectId,
      offsetMinutes: rule is tk.RemindBefore ? rule.minutes : null,
      atUtc: rule is tk.RemindAt ? rule.at.utc : null,
    );
    final same = old != null &&
        old.deletedAt == null &&
        old.offsetMinutes == row.offsetMinutes &&
        old.atUtc?.millisecondsSinceEpoch == row.atUtc?.millisecondsSinceEpoch;
    if (same) continue; // unchanged: no new version, no outbox row
    await db.into(db.reminders).insertOnConflictUpdate(row.toCompanion(false));
    await rows.outbox('reminder', id, old == null ? 'create' : 'update', old?.version, row.toJson());
  }
  for (final old in existing.values) {
    if (old.deletedAt != null) continue;
    final gone = old.copyWith(
        deletedAt: Value(rows.now), deletedBy: Value(rows.cmd.actor.toString()),
        version: old.version + 1, updatedAt: rows.now);
    await db.into(db.reminders).insertOnConflictUpdate(gone.toCompanion(false));
    await rows.outbox('reminder', old.id, 'delete', old.version, gone.toJson());
  }
  return rules.length;
}
