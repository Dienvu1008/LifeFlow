// P02 T5 (ADR-0031): event and calendar commands, on the single mutation
// path (ADR-0011) with the atomic set (ADR-0014). An event is its own
// aggregate with its own ids, never a task (LF-INV-CAL-001, owner D6).
//
// EventCommandHandler, payload['op']:
//   create        id, title, location?, calendarId?, schedule (columns JSON)
//   update        id, title, location?, calendarId?, schedule
//   setCancelled  id, cancelled
//   trash | restore  id
//   setException  id, originalDate, kind (skip|cancel|move|edit),
//                 moveDate?, moveTime?, title?, location?
//   clearException id, originalDate
//   setReminders  id, reminders (P02 T7, reminder_rows.dart)
// CalendarCommandHandler, payload['op']:
//   create  id, name, color      update  id, name?, color?
//   trash   id (its events stay, without a calendar)
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'app_database.dart';
import 'command_gateway.dart';
import 'reminder_rows.dart';
import 'schedule_rows.dart';

String _title(Command cmd) {
  final t = (cmd.payload['title'] as String? ?? '').trim();
  if (t.isEmpty) throw DomainRejection('title is empty');
  return t;
}

String? _optText(Command cmd, String key) {
  final v = (cmd.payload[key] as String?)?.trim();
  return v == null || v.isEmpty ? null : v;
}

class EventCommandHandler implements CommandHandler {
  const EventCommandHandler();

  @override
  String get entityType => 'event';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.events)..where((e) => e.id.equals(cmd.payload['id'] as String)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  Future<String?> _calendar(AppDatabase db, Command cmd) async {
    final id = cmd.payload['calendarId'] as String?;
    if (id == null) return null;
    final c = await (db.select(db.calendars)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (c == null || c.deletedAt != null || c.workspaceId != cmd.workspaceId) {
      throw DomainRejection('unknown calendar');
    }
    return id;
  }

  /// An event's schedule: a start is required, a deadline is not allowed.
  Future<tk.RecurrenceRule?> _schedule(ScheduleRows rows, Command cmd) async {
    final (_, spec, rule, _) = await rows.write((cmd.payload['schedule'] as Map).cast<String, Object?>());
    if (spec.start == null) throw DomainRejection('an event needs a start');
    if (spec.deadline != null) throw DomainRejection('an event has no deadline');
    return rule;
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = DateTime.now().toUtc();
    final owner = cmd.actor.id;
    final rows = ScheduleRows(db, cmd, 'event', id, owner, now);
    final existing = await (db.select(db.events)..where((e) => e.id.equals(id))).getSingleOrNull();

    HandlerOutcome outcome(String type, String event, Map<String, Object?> change) => HandlerOutcome(
        entityId: id, operationType: type, changeSet: {'id': id, ...change}, events: [DomainEvent(event, {'id': id})]);

    switch (op) {
      case 'create':
        if (existing != null) throw DomainRejection('the event already exists');
        // LF-INV-CAL-001: never the id of a task.
        final asTask = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (asTask != null) throw DomainRejection('an event cannot share the id of a task');
        final title = _title(cmd);
        await db.into(db.events).insert(EventsCompanion.insert(
              id: id,
              workspaceId: cmd.workspaceId,
              ownerId: owner,
              createdAt: now,
              updatedAt: now,
              title: title,
              location: Value(_optText(cmd, 'location')),
              calendarId: Value(await _calendar(db, cmd)),
              version: Value(newVersion.value),
            ));
        final rule = await _schedule(rows, cmd);
        return outcome('create', 'EventCreated', {'title': title, 'repeats': rule != null});

      case 'update':
        if (existing == null || existing.deletedAt != null) throw DomainRejection('event not found');
        final title = _title(cmd);
        await (db.update(db.events)..where((e) => e.id.equals(id))).write(EventsCompanion(
            title: Value(title),
            location: Value(_optText(cmd, 'location')),
            calendarId: Value(await _calendar(db, cmd)),
            version: Value(newVersion.value),
            updatedAt: Value(now)));
        final rule = await _schedule(rows, cmd);
        return outcome('update', 'EventUpdated', {'title': title, 'repeats': rule != null});

      case 'setCancelled':
        if (existing == null || existing.deletedAt != null) throw DomainRejection('event not found');
        final cancelled = cmd.payload['cancelled'] == true;
        if ((existing.status == 'cancelled') == cancelled) {
          throw DomainRejection(cancelled ? 'the event is already cancelled' : 'the event is not cancelled');
        }
        await (db.update(db.events)..where((e) => e.id.equals(id))).write(EventsCompanion(
            status: Value(cancelled ? 'cancelled' : 'confirmed'),
            version: Value(newVersion.value),
            updatedAt: Value(now)));
        return outcome('update', cancelled ? 'EventCancelled' : 'EventUpdated', {'status': cancelled ? 'cancelled' : 'confirmed'});

      case 'trash':
      case 'restore':
        if (existing == null) throw DomainRejection('event not found');
        final trash = op == 'trash';
        if ((existing.deletedAt != null) == trash) {
          throw DomainRejection(trash ? 'the event is already in the trash' : 'the event is not in the trash');
        }
        await (db.update(db.events)..where((e) => e.id.equals(id))).write(EventsCompanion(
            deletedAt: Value(trash ? now : null),
            deletedBy: Value(trash ? cmd.actor.toString() : null),
            version: Value(newVersion.value),
            updatedAt: Value(now)));
        return outcome(trash ? 'delete' : 'update', 'EventUpdated', {'tombstone': trash});

      case 'setReminders':
        // P02 T7 (ADR-0034): the reminders are part of the event.
        if (existing == null || existing.deletedAt != null) throw DomainRejection('event not found');
        final n = await replaceReminders(
            ScheduleRows(db, cmd, 'event', id, existing.ownerId, now), remindersOfPayload(cmd.payload['reminders']));
        await (db.update(db.events)..where((e) => e.id.equals(id)))
            .write(EventsCompanion(version: Value(newVersion.value), updatedAt: Value(now)));
        return outcome('update', 'EventRemindersChanged', {'reminders': n});

      case 'setException':
      case 'clearException':
        if (existing == null || existing.deletedAt != null) throw DomainRejection('event not found');
        final (s, original) = await rows.occurrence();
        if (op == 'clearException') {
          await rows.clearException(original);
        } else {
          final tk.ExceptionKind kind = switch (cmd.payload['kind']) {
            'skip' => const tk.SkipOccurrence(),
            'cancel' => const tk.CancelOccurrence(),
            'move' => rows.move(s),
            'edit' => () {
                final patch = <String, Object?>{
                  if (cmd.payload['title'] != null) 'title': _title(cmd),
                  if (cmd.payload.containsKey('location')) 'location': _optText(cmd, 'location'),
                };
                if (patch.isEmpty) throw DomainRejection('nothing to change');
                return tk.EditOccurrence(patch);
              }(),
            _ => throw DomainRejection('unknown occurrence change'),
          };
          await rows.writeException(original, kind);
        }
        await (db.update(db.events)..where((e) => e.id.equals(id)))
            .write(EventsCompanion(version: Value(newVersion.value), updatedAt: Value(now)));
        return HandlerOutcome(
          entityId: id,
          operationType: 'update',
          changeSet: {'id': id, 'occurrence': '$original', 'change': op == 'clearException' ? null : cmd.payload['kind']},
          events: [DomainEvent('OccurrenceExceptionAdded', {'id': id, 'originalDate': '$original'})],
        );
    }
    throw DomainRejection('unknown op: $op');
  }
}

class CalendarCommandHandler implements CommandHandler {
  const CalendarCommandHandler();

  @override
  String get entityType => 'calendar';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.calendars)..where((c) => c.id.equals(cmd.payload['id'] as String)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  String _name(Command cmd) {
    final n = (cmd.payload['name'] as String? ?? '').trim();
    if (n.isEmpty) throw DomainRejection('name is empty');
    return n;
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = DateTime.now().toUtc();
    final existing = await (db.select(db.calendars)..where((c) => c.id.equals(id))).getSingleOrNull();

    switch (op) {
      case 'create':
        if (existing != null) throw DomainRejection('the calendar already exists');
        final name = _name(cmd);
        await db.into(db.calendars).insert(CalendarsCompanion.insert(
              id: id,
              workspaceId: cmd.workspaceId,
              ownerId: cmd.actor.id,
              createdAt: now,
              updatedAt: now,
              name: name,
              color: Value(cmd.payload['color'] as int? ?? 0xFF009688),
              version: Value(newVersion.value),
            ));
        return HandlerOutcome(entityId: id, operationType: 'create', changeSet: {'id': id, 'name': name},
            events: [DomainEvent('CalendarCreated', {'id': id})]);

      case 'update':
        if (existing == null || existing.deletedAt != null) throw DomainRejection('calendar not found');
        await (db.update(db.calendars)..where((c) => c.id.equals(id))).write(CalendarsCompanion(
            name: cmd.payload['name'] == null ? const Value.absent() : Value(_name(cmd)),
            color: cmd.payload['color'] == null ? const Value.absent() : Value(cmd.payload['color'] as int),
            version: Value(newVersion.value),
            updatedAt: Value(now)));
        return HandlerOutcome(entityId: id, operationType: 'update', changeSet: {'id': id},
            events: [DomainEvent('CalendarUpdated', {'id': id})]);

      case 'trash':
        if (existing == null || existing.deletedAt != null) throw DomainRejection('calendar not found');
        await (db.update(db.calendars)..where((c) => c.id.equals(id))).write(CalendarsCompanion(
            deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()),
            version: Value(newVersion.value), updatedAt: Value(now)));
        // Its events stay, without a calendar; each one is a change for sync.
        final rows = ScheduleRows(db, cmd, 'calendar', id, cmd.actor.id, now);
        for (final e in await (db.select(db.events)..where((e) => e.calendarId.equals(id))).get()) {
          final moved = e.copyWith(calendarId: const Value(null), version: e.version + 1, updatedAt: now);
          await (db.update(db.events)..where((x) => x.id.equals(e.id))).write(moved.toCompanion(false));
          await rows.outbox('event', e.id, 'update', e.version, moved.toJson());
        }
        return HandlerOutcome(entityId: id, operationType: 'delete', changeSet: {'id': id, 'tombstone': true},
            events: [DomainEvent('CalendarTrashed', {'id': id})]);
    }
    throw DomainRejection('unknown op: $op');
  }
}
