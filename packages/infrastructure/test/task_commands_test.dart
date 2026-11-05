// P01 T3 integration: Task commands through the real gateway (single mutation
// path). Covers create/rename/complete(cascade)/reparent(cycle rejected)/trash,
// and cross-workspace denial (GS-11). Invariants: LF-INV-TASK-001/002/003/004/
// 010/011, GS-18 (reparent cycle rejected on the real store).
import 'package:application/application.dart';
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

/// Owner-of-workspace policy (MVP): allow only the workspace owner.
class OwnerPolicy implements AuthorizationService {
  OwnerPolicy(this.ownerId);
  final String ownerId;
  @override
  Future<String?> denyReason(ActorRef a, String action, ResourceRef r) async =>
      (a.kind == ActorKind.owner && a.id == ownerId) ? null : 'not the owner';
}

void main() {
  late AppDatabase db;
  late DriftCommandGateway gw;
  final handler = TaskCommandHandler();
  var seq = 0;

  Command c(String op, Map<String, Object?> payload, {Version? expected, ActorRef? actor}) => Command(
        operationId: 'op${seq++}',
        actor: actor ?? const ActorRef(ActorKind.owner, 'owner1'),
        workspaceId: 'ws1',
        type: op,
        payload: {'op': op, ...payload},
        expectedVersion: expected,
        issuedAt: Instant.now(),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, OwnerPolicy('owner1'));
    await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
        id: 'ws1', ownerId: 'owner1', createdAt: DateTime.now().toUtc()));
    seq = 0;
  });
  tearDown(() => db.close());

  Future<void> create(String id, String title, {String? parent}) async {
    final r = await gw.execute(c('create', {'id': id, 'title': title, 'parentId': parent}), handler);
    expect(r, isA<CommandOk>(), reason: 'create $id failed: $r');
  }

  test('create + rename + trash go through the gateway', () async {
    await create('t1', 'Draft');
    final r = await gw.execute(c('rename', {'id': 't1', 'title': 'Final'}, expected: Version.initial), handler);
    expect(r, isA<CommandOk>());
    final t = await (db.select(db.tasks)..where((x) => x.id.equals('t1'))).getSingle();
    expect(t.title, 'Final');
    expect(t.version, 2);
    // trash -> tombstone, excluded from search (LF-INV-TASK-011)
    await gw.execute(c('trash', {'id': 't1'}, expected: const Version(2)), handler);
    final t2 = await (db.select(db.tasks)..where((x) => x.id.equals('t1'))).getSingle();
    expect(t2.deletedAt, isNotNull);
    expect(await db.searchTaskIds('ws1', 'Final'), isEmpty);
  });

  test('reparent cycle is rejected on the real store (GS-18 / LF-INV-TASK-003)', () async {
    await create('a', 'A');
    await create('b', 'B', parent: 'a'); // b under a
    await create('c', 'C', parent: 'b'); // c under b
    // Try to put a under c -> cycle (a is an ancestor of c).
    final r = await gw.execute(c('reparent', {'id': 'a', 'newParentId': 'c'},
        expected: Version.initial), handler);
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
    // a is unchanged (still root).
    final a = await (db.select(db.tasks)..where((x) => x.id.equals('a'))).getSingle();
    expect(a.parentTaskId, isNull);
  });

  test('create beyond max depth is rejected (LF-INV-TASK-002)', () async {
    await create('d1', 'L1');
    await create('d2', 'L2', parent: 'd1');
    await create('d3', 'L3', parent: 'd2');
    await create('d4', 'L4', parent: 'd3'); // depth 4 = allowed
    final r = await gw.execute(c('create', {'id': 'd5', 'title': 'L5', 'parentId': 'd4'}), handler);
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
    expect(await (db.select(db.tasks)..where((x) => x.id.equals('d5'))).getSingleOrNull(), isNull);
  });

  test('complete: parentOnly records open subtasks; all cascades (OQ-R3)', () async {
    await create('p', 'Parent');
    await create('c1', 'Child1', parent: 'p');
    // parentOnly: parent done, child still open; changeSet notes the open child.
    await gw.execute(c('complete', {'id': 'p', 'cascade': 'parentOnly'}, expected: Version.initial), handler);
    final parent = await (db.select(db.tasks)..where((x) => x.id.equals('p'))).getSingle();
    final child = await (db.select(db.tasks)..where((x) => x.id.equals('c1'))).getSingle();
    expect(parent.status, 'done');
    expect(child.status, isNot('done'));
    // The outbox change set recorded the open subtask at completion (audit-visible, OQ-R3).
    final outboxRows = await db.select(db.outbox).get();
    final completeRow = outboxRows.firstWhere((o) => o.entityId == 'p' && o.payload.contains('status'));
    expect(completeRow.payload.contains('openSubtasksAtCompletion'), isTrue);
    expect(completeRow.payload.contains('c1'), isTrue);
    // complete-all on a fresh parent cascades.
    await create('p2', 'Parent2');
    await create('c2', 'Child2', parent: 'p2');
    await gw.execute(c('complete', {'id': 'p2', 'cascade': 'all'}, expected: Version.initial), handler);
    final c2 = await (db.select(db.tasks)..where((x) => x.id.equals('c2'))).getSingle();
    expect(c2.status, 'done');
  });

  test('cross-workspace command denied (GS-11)', () async {
    // An actor who is not the owner of ws1 is denied; nothing is written.
    final r = await gw.execute(
        c('create', {'id': 'x1', 'title': 'intruder'}, actor: const ActorRef(ActorKind.owner, 'intruder')),
        handler);
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
    expect(await (db.select(db.tasks)..where((x) => x.id.equals('x1'))).getSingleOrNull(), isNull);
  });
}
