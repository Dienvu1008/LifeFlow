// P01 T2 headless tests: the governance kernel's atomic transactional set and
// optimistic concurrency. Golden scenarios:
//   GS-07  outbox/audit exist iff the mutation committed (fault-injection)
//   GS-12  concurrent writers -> one wins (v+1), the other VersionConflict
//   GS-06  crash between commit and dispatch loses no event (event log + redelivery)
// plus idempotency (dedupe) and authorize-before-domain.
// Invariants: LF-INV-GOV-001/002/003, OUTBOX-001/002, AUDIT-001, VER-001.
import 'package:application/application.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

/// Allow-all authorization for the happy path.
class AllowAll implements AuthorizationService {
  @override
  Future<String?> denyReason(ActorRef a, String action, ResourceRef r) async => null;
}

class DenyAll implements AuthorizationService {
  @override
  Future<String?> denyReason(ActorRef a, String action, ResourceRef r) async =>
      'not the owner';
}

/// A minimal handler that creates/updates a Task row, so the gateway can be
/// tested independently of the full Task domain (T3). Optionally throws after
/// writing the aggregate, to exercise rollback of the atomic set.
class _TaskHandler implements CommandHandler {
  _TaskHandler({this.throwAfterApply = false});
  final bool throwAfterApply;

  @override
  String get entityType => 'task';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final id = cmd.payload['id'] as String;
    final row = await (db.select(db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final id = cmd.payload['id'] as String;
    final title = cmd.payload['title'] as String;
    final now = DateTime.now().toUtc();
    final exists = await (db.select(db.tasks)..where((t) => t.id.equals(id)))
            .getSingleOrNull() !=
        null;
    if (exists) {
      await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(title: Value(title), version: Value(newVersion.value), updatedAt: Value(now)));
    } else {
      await db.into(db.tasks).insert(TasksCompanion.insert(
            id: id,
            workspaceId: cmd.workspaceId,
            ownerId: 'owner1',
            createdAt: now,
            updatedAt: now,
            title: title,
            version: Value(newVersion.value),
          ));
    }
    if (throwAfterApply) throw StateError('injected failure after apply');
    return HandlerOutcome(
      entityId: id,
      operationType: exists ? 'update' : 'create',
      changeSet: {'id': id, 'title': title},
      events: [DomainEvent('TaskCreated', {'id': id})],
    );
  }
}

Command cmd(String op, String id, String title, {Version? expected}) => Command(
      operationId: op,
      actor: const ActorRef(ActorKind.owner, 'owner1'),
      workspaceId: 'ws1',
      type: 'CreateTask',
      payload: {'id': id, 'title': title},
      expectedVersion: expected,
      issuedAt: Instant.now(),
    );

void main() {
  late AppDatabase db;
  late List<DomainEvent> delivered;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    delivered = [];
    await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
        id: 'ws1', ownerId: 'owner1', createdAt: DateTime.now().toUtc()));
  });
  tearDown(() => db.close());

  DriftCommandGateway gateway({AuthorizationService? authz, EventSink? onEvent}) =>
      DriftCommandGateway(db, authz ?? AllowAll(),
          onEvent: onEvent ?? (e) async => delivered.add(e));

  test('happy path: aggregate + audit + outbox + event + dedupe all committed', () async {
    final r = await gateway().execute(cmd('op1', 't1', 'Hello'), _TaskHandler());
    expect(r, isA<CommandOk>());
    expect((await db.select(db.tasks).get()).length, 1);
    expect((await db.select(db.auditLog).get()).length, 1);
    expect((await db.select(db.outbox).get()).length, 1);
    expect((await db.select(db.eventLog).get()).length, 1);
    expect((await db.select(db.opDedupe).get()).length, 1);
    expect(delivered.map((e) => e.type), ['TaskCreated']); // dispatched after commit
  });

  test('GS-07: injected failure rolls back the WHOLE set (nothing persists)', () async {
    try {
      await gateway().execute(cmd('op2', 't2', 'Boom'), _TaskHandler(throwAfterApply: true));
    } catch (_) {/* the StateError propagates out of the transaction */}
    // Regardless of how the failure surfaces, NOTHING from op2 may persist.
    expect((await db.select(db.tasks).get()).where((t) => t.id == 't2'), isEmpty);
    expect((await db.select(db.auditLog).get()).where((a) => a.operationId == 'op2'), isEmpty);
    expect((await db.select(db.outbox).get()).where((o) => o.operationId == 'op2'), isEmpty);
    expect((await db.select(db.eventLog).get()).where((e) => e.operationId == 'op2'), isEmpty);
    expect((await db.select(db.opDedupe).get()).where((d) => d.operationId == 'op2'), isEmpty);
    expect(delivered, isEmpty);
  });

  test('GS-12: concurrent writers with same expectedVersion -> one wins, one conflict', () async {
    await gateway().execute(cmd('c0', 't3', 'v1'), _TaskHandler()); // now at v1
    // Two updates both expecting v1.
    final r1 = await gateway().execute(cmd('c1', 't3', 'A', expected: Version.initial), _TaskHandler());
    final r2 = await gateway().execute(cmd('c2', 't3', 'B', expected: Version.initial), _TaskHandler());
    final oks = [r1, r2].whereType<CommandOk>().length;
    final conflicts = [r1, r2]
        .whereType<CommandFailure>()
        .where((f) => f.kind == CommandFailureKind.versionConflict)
        .length;
    expect(oks, 1);
    expect(conflicts, 1);
    final t = await (db.select(db.tasks)..where((x) => x.id.equals('t3'))).getSingle();
    expect(t.version, 2); // exactly one increment
  });

  test('idempotency: same operationId twice -> duplicate, one state change', () async {
    final r1 = await gateway().execute(cmd('dup', 't4', 'once'), _TaskHandler());
    final r2 = await gateway().execute(cmd('dup', 't4', 'twice'), _TaskHandler());
    expect(r1, isA<CommandOk>());
    expect(r2, isA<CommandFailure>());
    expect((r2 as CommandFailure).kind, CommandFailureKind.duplicateOperation);
    final t = await (db.select(db.tasks)..where((x) => x.id.equals('t4'))).getSingle();
    expect(t.title, 'once'); // second was not applied
  });

  test('GS-06: crash between commit and dispatch loses no event', () async {
    // Simulate "crash before dispatch": a gateway whose event sink throws, so
    // delivery fails but the committed event-log row remains undispatched.
    final crashing = DriftCommandGateway(db, AllowAll(),
        onEvent: (e) async => throw StateError('crash before dispatch'));
    try {
      await crashing.execute(cmd('op6', 't6', 'persist me'), _TaskHandler());
    } catch (_) {/* delivery failed, but the mutation committed */}
    // The mutation committed; the event is durably logged, undispatched.
    expect((await db.select(db.tasks).get()).where((t) => t.id == 't6').length, 1);
    final logged = await db.select(db.eventLog).get();
    expect(logged.where((e) => e.operationId == 'op6').length, 1);
    // Recovery: a healthy gateway drains pending events exactly once.
    final recovered = <DomainEvent>[];
    final healthy = DriftCommandGateway(db, AllowAll(),
        onEvent: (e) async => recovered.add(e));
    await healthy.dispatchPendingEvents();
    await healthy.dispatchPendingEvents(); // idempotent: no double delivery
    expect(recovered.where((e) => e.type == 'TaskCreated').length, 1);
  });

  test('authorize-before-domain: deny writes nothing', () async {
    final r = await gateway(authz: DenyAll()).execute(cmd('op7', 't7', 'nope'), _TaskHandler());
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
    expect((await db.select(db.tasks).get()).where((t) => t.id == 't7'), isEmpty);
    expect((await db.select(db.auditLog).get()), isEmpty);
  });
}
