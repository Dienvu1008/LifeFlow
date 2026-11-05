// P01 T1 headless tests: the local store opens, the governance-ready schema
// exists with shared columns, FTS5 search over task titles works, and
// tombstone/version columns behave. Ties to LF-INV-ID-001 (stable id),
// LF-INV-SEC-010 groundwork (all fields present for export), GS-19 (FTS, plain
// part). Uses an in-memory NativeDatabase.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedWorkspace() async {
    final now = DateTime.now().toUtc();
    await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
          id: 'ws1',
          ownerId: 'owner1',
          createdAt: now,
        ));
  }

  TasksCompanion task(String id, String title, {String? parent}) {
    final now = DateTime.now().toUtc();
    return TasksCompanion.insert(
      id: id,
      workspaceId: 'ws1',
      ownerId: 'owner1',
      createdAt: now,
      updatedAt: now,
      title: title,
      parentTaskId: Value(parent),
    );
  }

  test('schema opens; shared columns + governance tables exist', () async {
    await seedWorkspace();
    await db.into(db.tasks).insert(task('t1', 'Buy milk'));
    final t = await (db.select(db.tasks)..where((x) => x.id.equals('t1'))).getSingle();
    expect(t.workspaceId, 'ws1');
    expect(t.ownerId, 'owner1');
    expect(t.version, 1); // default initial version (ADR-0009)
    expect(t.deletedAt, isNull); // tombstone empty
    // governance tables are queryable (empty)
    expect(await db.select(db.auditLog).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.select(db.eventLog).get(), isEmpty);
    expect(await db.select(db.opDedupe).get(), isEmpty);
  });

  test('FTS5 search over task titles returns the right task', () async {
    await seedWorkspace();
    await db.into(db.tasks).insert(task('t1', 'Grocery shopping'));
    await db.into(db.tasks).insert(task('t2', 'Prepare roadmap review'));
    expect(await db.searchTaskIds('ws1', 'roadmap'), ['t2']);
    expect(await db.searchTaskIds('ws1', 'grocery'), ['t1']);
    expect(await db.searchTaskIds('ws1', 'bicycle'), isEmpty);
  });

  test('FTS reflects updates and tombstone excludes from search', () async {
    await seedWorkspace();
    await db.into(db.tasks).insert(task('t1', 'old title'));
    await (db.update(db.tasks)..where((x) => x.id.equals('t1')))
        .write(const TasksCompanion(title: Value('new searchable title')));
    expect(await db.searchTaskIds('ws1', 'searchable'), ['t1']);
    expect(await db.searchTaskIds('ws1', 'old'), isEmpty);
    // Soft-delete (tombstone): excluded from search (deleted_at set).
    await (db.update(db.tasks)..where((x) => x.id.equals('t1')))
        .write(TasksCompanion(deletedAt: Value(DateTime.now().toUtc())));
    expect(await db.searchTaskIds('ws1', 'searchable'), isEmpty);
  });

  test('id is stable across an update (LF-INV-ID-001 groundwork)', () async {
    await seedWorkspace();
    await db.into(db.tasks).insert(task('t1', 'x'));
    await (db.update(db.tasks)..where((x) => x.id.equals('t1')))
        .write(const TasksCompanion(title: Value('y'), version: Value(2)));
    final t = await (db.select(db.tasks)..where((x) => x.id.equals('t1'))).getSingle();
    expect(t.id, 't1');
    expect(t.version, 2);
  });
}
