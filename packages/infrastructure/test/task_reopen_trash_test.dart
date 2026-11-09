// P01 T7c (owner review 2026-11-07): undo a completion; trash a parent with
// or without its subtasks. Through the real gateway.
//   LF-INV-TASK-004  reopen follows the transition table (done -> todo)
//   LF-INV-VER-001   every task a command changes gets a new version
//   LF-INV-OUTBOX-001 one outbox row per changed task, same operation
//   LF-INV-TASK-011  trashed tasks leave the list
import 'package:application/application.dart';
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftTaskService tasks;
  late DriftTaskQueries queries;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ProfileStore(db).ensureFirstProfile();
    tasks = DriftTaskService(db, DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)));
    queries = DriftTaskQueries(db);
  });
  tearDown(() => db.close());

  Future<String> make(String title, {String? parent}) async =>
      (await tasks.create(title, parentId: parent) as CommandOk).entityId;
  Future<Task> row(String id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
  Future<List<String>> visible() async =>
      (await queries.watchTasks().first).map((t) => t.title).toList();
  Future<List<OutboxData>> outboxOf(String opId) =>
      (db.select(db.outbox)..where((o) => o.operationId.equals(opId))).get();
  Future<String> opOf(String action) async => (await (db.select(db.auditLog)
            ..where((a) => a.action.equals(action))))
          .get()
          .then((r) => r.last.operationId);

  group('reopen (undo a completion)', () {
    test('a done task becomes open again; version moves; audited', () async {
      final id = await make('Pay rent');
      await tasks.complete(id, withDescendants: false);
      final done = await row(id);
      expect(done.status, 'done');

      final r = await tasks.reopen(id);
      expect(r, isA<CommandOk>(), reason: '$r');
      final open = await row(id);
      expect(open.status, 'todo');
      expect(open.version, done.version + 1);
      final op = await opOf('ReopenTask');
      expect((await outboxOf(op)).single.entityId, id);
    });

    test('reopening a parent leaves its finished subtasks done', () async {
      final p = await make('Parent');
      final c = await make('Child', parent: p);
      await tasks.complete(p, withDescendants: true);
      await tasks.reopen(p);
      expect((await row(p)).status, 'todo');
      expect((await row(c)).status, 'done');
    });

    test('an open task cannot be reopened (returned, not thrown)', () async {
      final id = await make('Open');
      final r = await tasks.reopen(id);
      expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
      expect((await row(id)).version, 1);
    });

    test('complete -> reopen -> complete works', () async {
      final id = await make('Again');
      await tasks.complete(id, withDescendants: false);
      await tasks.reopen(id);
      expect(await tasks.complete(id, withDescendants: false), isA<CommandOk>());
      expect((await row(id)).status, 'done');
    });
  });

  group('complete with subtasks', () {
    test('every subtask changed gets a version and an outbox row', () async {
      final p = await make('P');
      final a = await make('A', parent: p);
      final b = await make('B', parent: p);
      await tasks.complete(p, withDescendants: true);
      expect((await row(a)).version, 2);
      expect((await row(b)).version, 2);
      final op = await opOf('CompleteTaskWithDescendants');
      expect((await outboxOf(op)).map((o) => o.entityId).toSet(), {p, a, b});
    });
  });

  group('trash a parent', () {
    late String root, mid, leaf, sibling;
    setUp(() async {
      root = await make('Root');
      mid = await make('Mid', parent: root);
      leaf = await make('Leaf', parent: mid);
      sibling = await make('Sibling', parent: root);
      await make('Other');
    });

    test('with subtasks: the whole subtree goes to the trash', () async {
      final r = await tasks.trash(root, withSubtasks: true);
      expect(r, isA<CommandOk>(), reason: '$r');
      expect(await visible(), ['Other']);
      for (final id in [root, mid, leaf, sibling]) {
        final t = await row(id);
        expect(t.deletedAt, isNotNull, reason: t.title);
        expect(t.version, greaterThan(1), reason: t.title);
      }
      final op = await opOf('TrashTaskWithSubtasks');
      final out = await outboxOf(op);
      expect(out.map((o) => o.entityId).toSet(), {root, mid, leaf, sibling});
      expect(out.every((o) => o.operationType == 'delete'), isTrue);
    });

    test('only this task: its direct subtasks move up one level', () async {
      // Mid is under Root; trashing Mid puts Leaf under Root.
      final r = await tasks.trash(mid);
      expect(r, isA<CommandOk>(), reason: '$r');
      expect((await row(mid)).deletedAt, isNotNull);
      final l = await row(leaf);
      expect(l.deletedAt, isNull);
      expect(l.parentTaskId, root);
      expect(l.version, 2);
      final op = await opOf('TrashTask');
      expect((await outboxOf(op)).map((o) => '${o.entityId}:${o.operationType}').toSet(),
          {'$mid:delete', '$leaf:update'});
    });

    test('only this task, at the top: subtasks become top-level tasks', () async {
      await tasks.trash(root);
      expect((await row(mid)).parentTaskId, isNull);
      expect((await row(sibling)).parentTaskId, isNull);
      expect((await row(leaf)).parentTaskId, mid); // grandchildren keep theirs
      expect(await visible(), unorderedEquals(['Mid', 'Leaf', 'Sibling', 'Other']));
    });

    test('a failure in between leaves nothing half-trashed', () async {
      // The parent's version changed meanwhile: the command is refused as a
      // whole, subtasks included.
      await tasks.rename(root, 'Root 2');
      final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
      final p = (await ProfileStore(db).getActiveProfile())!;
      final r = await gw.execute(
          Command(
            operationId: 'stale',
            actor: ActorRef(ActorKind.owner, p.profileId.value),
            workspaceId: p.activeWorkspaceId.value,
            type: 'TrashTaskWithSubtasks',
            payload: {'op': 'trash', 'id': root, 'cascade': 'all'},
            expectedVersion: Version.initial,
            issuedAt: Instant.now(),
          ),
          TaskCommandHandler());
      expect((r as CommandFailure).kind, CommandFailureKind.versionConflict);
      expect(await visible(), hasLength(5));
      expect((await row(mid)).version, 1);
    });
  });
}
