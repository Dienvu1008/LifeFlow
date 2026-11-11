// P03 T4 (ADR-0039): measurements (D10) and the closing of periods (D9),
// through the gateway like every write (ADR-0011/0014).
//
//   MeasurementCommandHandler (entity measurement)
//     record   payload: id, taskId, value, date, today, note?, deviceId?,
//              confirmClosed?
//     correct  payload: id (the new measurement), supersedesId, value
//              (null = withdraw), today, note?, deviceId?, confirmClosed?
//   PeriodCloseHandler (entity periodResult)
//     close    payload: id (task:<task>@<key>#<kind>), taskId, today
//
// A measurement is never changed: a correction is a new row that replaces
// the old one in the totals; the old one stays (LF-INV-EXEC-001). A change
// in a closed period needs the user's confirmation and re-evaluates the
// stored result with the target it was stored with (D9).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' as d;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'habit_tracking.dart';

LocalDate _date(Object? raw, String what) {
  try {
    return LocalDate.parse(raw as String);
  } catch (_) {
    throw DomainRejection('bad $what');
  }
}

String? _note(Command cmd) {
  final n = (cmd.payload['note'] as String?)?.trim();
  if (n == null || n.isEmpty) return null;
  if (n.length > 500) throw DomainRejection('the note is too long');
  return n;
}

class MeasurementCommandHandler implements CommandHandler {
  const MeasurementCommandHandler({this.clock = const SystemClock()});
  final Clock clock;

  @override
  String get entityType => 'measurement';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.measurements)..where((m) => m.id.equals(cmd.payload['id'] as String)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = clock.now().utc;
    final today = _date(cmd.payload['today'], 'today');
    if (await (db.select(db.measurements)..where((m) => m.id.equals(id))).getSingleOrNull() != null) {
      throw DomainRejection('the measurement already exists');
    }

    final String taskId;
    final LocalDate date;
    final double value;
    String? supersedes;
    var withdrawn = false;
    switch (op) {
      case 'record':
        taskId = cmd.payload['taskId'] as String;
        date = _date(cmd.payload['date'], 'date');
        final v = cmd.payload['value'];
        if (v is! num) throw DomainRejection('a measurement needs a value');
        value = v.toDouble();
      case 'correct':
        supersedes = cmd.payload['supersedesId'] as String?;
        final old = supersedes == null
            ? null
            : await (db.select(db.measurements)..where((m) => m.id.equals(supersedes!))).getSingleOrNull();
        if (old == null || old.deletedAt != null || old.workspaceId != cmd.workspaceId) {
          throw DomainRejection('measurement not found');
        }
        if (old.withdrawn) throw DomainRejection('a withdrawal cannot be corrected');
        final later = await (db.select(db.measurements)
              ..where((m) => m.supersedesId.equals(old.id) & m.deletedAt.isNull()))
            .get();
        if (later.isNotEmpty) throw DomainRejection('the measurement was already corrected');
        taskId = old.taskId;
        date = LocalDate.parse(old.localDate); // fixed when recorded (D10)
        final v = cmd.payload['value'];
        if (v == null) {
          withdrawn = true;
          value = old.value;
        } else if (v is num) {
          value = v.toDouble();
        } else {
          throw DomainRejection('bad value');
        }
      default:
        throw DomainRejection('unknown op: $op');
    }

    final error = d.measurementValueError(value);
    if (error != null) throw DomainRejection(error);
    if (date.isAfter(today)) throw DomainRejection('a measurement cannot be in the future');
    final t = await TrackedTask.load(db, taskId);
    if (t == null || t.row.workspaceId != cmd.workspaceId) throw DomainRejection('task not found');
    if (t.target == null) throw DomainRejection('the task has no target');
    final period = t.periodOn(date);
    if (period == null) throw DomainRejection('the date is before the task starts');
    final closed = period.hasEndedOn(today);
    if (closed && cmd.payload['confirmClosed'] != true) throw DomainRejection(closedPeriodNeedsConfirmation);

    await db.into(db.measurements).insert(MeasurementsCompanion.insert(
          id: id,
          workspaceId: cmd.workspaceId,
          ownerId: t.row.ownerId,
          createdAt: now,
          updatedAt: now,
          taskId: taskId,
          value: value,
          localDate: '$date',
          recordedAt: now,
          source: 'manual', // LF-INV-HEALTH-004
          deviceId: Value(cmd.payload['deviceId'] as String?),
          note: Value(_note(cmd)),
          supersedesId: Value(supersedes),
          withdrawn: Value(withdrawn),
          version: Value(newVersion.value),
        ));
    final reevaluated = closed &&
        await reevaluateClosedPeriod(db, taskId, date,
            operationId: cmd.operationId, workspaceId: cmd.workspaceId, actor: cmd.actor.toString(), now: now);
    return HandlerOutcome(
      entityId: id,
      operationType: 'create',
      changeSet: {
        'id': id,
        'taskId': taskId,
        'value': value,
        'date': '$date',
        if (supersedes != null) 'supersedesId': supersedes,
        if (withdrawn) 'withdrawn': true,
        if (closed) 'closedPeriod': true,
        if (reevaluated) 'closedResultChanged': true,
      },
      events: [
        DomainEvent(op == 'record' ? 'MeasurementRecorded' : 'MeasurementCorrected', {'id': id, 'taskId': taskId}),
        if (reevaluated) DomainEvent('PeriodResultChanged', {'taskId': taskId, 'date': '$date'}),
      ],
    );
  }
}

class PeriodCloseHandler implements CommandHandler {
  const PeriodCloseHandler({this.clock = const SystemClock()});
  final Clock clock;

  @override
  String get entityType => 'periodResult';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.periodResults)..where((r) => r.id.equals(cmd.payload['id'] as String)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    if (cmd.payload['op'] != 'close') throw DomainRejection('unknown op: ${cmd.payload['op']}');
    final id = cmd.payload['id'] as String;
    final now = clock.now().utc;
    final today = _date(cmd.payload['today'], 'today');
    final t = await TrackedTask.load(db, cmd.payload['taskId'] as String);
    if (t == null || t.row.workspaceId != cmd.workspaceId) throw DomainRejection('task not found');
    if (await (db.select(db.periodResults)..where((r) => r.id.equals(id))).getSingleOrNull() != null) {
      throw DomainRejection('the period is already closed');
    }
    // Derived here from the stored rows, never taken from the caller.
    final r = t.endedResults(today).where((r) => r.id == id).firstOrNull;
    if (r == null) throw DomainRejection('the period has not ended');
    await db.into(db.periodResults).insert(PeriodResultsCompanion.insert(
          id: id,
          workspaceId: cmd.workspaceId,
          ownerId: t.row.ownerId,
          createdAt: now,
          updatedAt: now,
          taskId: t.row.id,
          periodKey: r.key,
          kind: r.kind,
          outcome: r.outcome.name,
          value: Value(r.value),
          target: Value(r.target),
          evaluatedAt: now,
          version: Value(newVersion.value),
        ));
    return HandlerOutcome(
      entityId: id,
      operationType: 'create',
      changeSet: {
        'id': id,
        'taskId': t.row.id,
        'key': r.key,
        'kind': r.kind,
        'outcome': r.outcome.name,
        'value': r.value,
        if (r.target != null) 'target': jsonDecode(r.target!),
      },
      events: [DomainEvent('PeriodClosed', {'id': id, 'taskId': t.row.id, 'outcome': r.outcome.name})],
    );
  }
}
