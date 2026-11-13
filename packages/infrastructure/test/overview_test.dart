// P03 UX U2 (ADR-0046): lists, colours and order on a real profile store.
//   ORDER-001  containers: lists; items in no list; items of a list; subtasks
//   ORDER-002  a drop rewrites one row; a stale position is refused
//   ORDER-003  an event is never under a task (U-D1)
//   ORDER-004  a list goes to the trash with its contents and comes back with
//              the same set; an item trashed before stays in the trash
//   TASK-002   the moved subtasks count for the depth limit
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late DriftOverviewService overview;
  late DriftOverviewQueries queries;
  late DriftEventService events;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_overview_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    svc = Services(host, FakeAuthGateway());
    overview = DriftOverviewService(host.db, gw);
    queries = DriftOverviewQueries(host.db);
    events = DriftEventService(host.db, gw);
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
    return (r as CommandOk).entityId;
  }

  void refused(CommandResult r, String mentions) {
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).reason, contains(mentions));
  }

  Future<String> task(String title, {String? parent, String? list}) async =>
      ok(await svc.tasks.create(title, parentId: parent, listId: list));
  Future<String> event(String title, {String? list}) async => ok(await events.create(EventInput(
      title: title, start: SchedulePointInput.date(LocalDate(2026, 11, 12)), listId: list)));
  Future<String> list(String title) async => ok(await overview.createList(title));
  Future<List<TaskView>> tasks() => svc.queries.watchTasks().first;
  Future<List<String>> lists() async => [for (final l in await queries.watchLists().first) l.title];

  /// The titles at the top level of [listId] (null: no list), tasks and
  /// events together, in display order.
  Future<List<String>> top(String? listId) async {
    final items = [
      for (final t in await tasks())
        if (t.parentId == null && t.listId == listId) (t.orderKey, t.id, t.title),
      for (final e in await queries.watchEvents().first)
        if (e.listId == listId) (e.orderKey, e.id, e.title),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final i in items) i.$3];
  }

  Future<List<String>> under(String parent) async => [
        for (final t in await tasks())
          if (t.parentId == parent) t.title
      ];

  Future<Map<String, int>> versions() async => {
        for (final t in await host.db.select(host.db.tasks).get()) t.id: t.version,
        for (final e in await host.db.select(host.db.events).get()) e.id: e.version,
        for (final l in await host.db.select(host.db.taskLists).get()) l.id: l.version,
      };

  Future<int> changedSince(Map<String, int> before) async {
    final now = await versions();
    return now.entries.where((e) => before[e.key] != e.value).length;
  }

  test('lists: create at the end, rename, colour, move', () async {
    final work = await list('Work');
    final home = await list('Home');
    final fun = await list('Fun');
    expect(await lists(), ['Work', 'Home', 'Fun']);
    ok(await overview.moveList(fun));
    expect(await lists(), ['Fun', 'Work', 'Home']);
    ok(await overview.moveList(fun, afterId: work));
    expect(await lists(), ['Work', 'Fun', 'Home']);
    ok(await overview.renameList(home, 'House'));
    ok(await overview.setListColor(home, 3));
    final house = (await queries.watchLists().first).last;
    expect((house.title, house.colorIndex), ('House', 3));
    refused(await overview.renameList(home, '  '), 'title is empty');
    refused(await overview.setListColor(home, 12), 'unknown colour');
    refused(await overview.moveList(fun, afterId: fun), 'out of date');
  });

  test('ORDER-001/002: tasks and events share a container; one drop rewrites one row', () async {
    final work = await list('Work');
    await task('A');
    final b = await task('B');
    final e = await event('Meeting');
    final c = await task('C', list: work);
    expect(await top(null), ['A', 'B', 'Meeting']);
    expect(await top(work), ['C']);

    var before = await versions();
    ok(await overview.moveEvent(e, const ItemPlace.loose()));
    expect(await top(null), ['Meeting', 'A', 'B']);
    expect(await changedSince(before), 1);

    before = await versions();
    ok(await overview.moveTask(b, ItemPlace.inList(work, afterId: c)));
    expect(await top(null), ['Meeting', 'A']);
    expect(await top(work), ['C', 'B']);
    expect(await changedSince(before), 1);

    ok(await overview.moveEvent(e, ItemPlace.inList(work)));
    expect(await top(work), ['Meeting', 'C', 'B']);
    // Out of the list again, after A.
    final a = (await tasks()).firstWhere((t) => t.title == 'A').id;
    ok(await overview.moveTask(c, ItemPlace.loose(afterId: a)));
    expect(await top(null), ['A', 'C']);
    // A stale position: B is not in no list.
    refused(await overview.moveTask(a, ItemPlace.loose(afterId: b)), 'out of date');
    refused(await overview.moveTask(a, const ItemPlace.inList('nope')), 'unknown list');
  });

  test('a subtask follows its top-level task: no list of its own; moving the parent moves them', () async {
    final work = await list('Work');
    final p = await task('Plan');
    final k1 = await task('Step 1', parent: p);
    await task('Step 2', parent: p);
    // A subtask created with a list ignores it.
    final k3 = await task('Step 3', parent: p, list: work);
    ok(await overview.moveTask(p, ItemPlace.inList(work)));
    final rows = {for (final t in await tasks()) t.title: t};
    expect(rows['Plan']!.listId, work);
    expect([rows['Step 1']!.listId, rows['Step 3']!.listId], [null, null]);
    // Stored too: a subtask keeps no list of its own (LF-INV-ORDER-001).
    final stored = await (host.db.select(host.db.tasks)..where((t) => t.id.equals(k3))).getSingle();
    expect(stored.taskListId, isNull);
    expect(await under(p), ['Step 1', 'Step 2', 'Step 3']);
    // Reorder subtasks; and a subtask to the top level of a list.
    ok(await overview.moveTask(k3, ItemPlace.under(p)));
    expect(await under(p), ['Step 3', 'Step 1', 'Step 2']);
    ok(await overview.moveTask(k1, ItemPlace.inList(work, afterId: p)));
    expect(await top(work), ['Plan', 'Step 1']);
    expect(await under(p), ['Step 3', 'Step 2']);
    // The task editor's reparent to the top level keeps the list.
    final r = await svc.tasks.create('Deep', parentId: k1);
    final deep = ok(r);
    final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    final profile = (await ProfileStore(host.db).getActiveProfile())!;
    final v = (await (host.db.select(host.db.tasks)..where((t) => t.id.equals(deep))).getSingle()).version;
    ok(await gw.execute(
        Command(
            operationId: 'reparent-deep',
            actor: ActorRef(ActorKind.owner, profile.profileId.value),
            workspaceId: profile.activeWorkspaceId.value,
            type: 'ReparentTask',
            payload: {'op': 'reparent', 'id': deep, 'newParentId': null},
            expectedVersion: Version(v),
            issuedAt: Instant.now()),
        TaskCommandHandler()));
    expect(await top(work), ['Plan', 'Step 1', 'Deep']);
  });

  test('TASK-002/003: the moved subtasks count for the depth; no cycle', () async {
    final a = await task('A');
    final b = await task('B', parent: a);
    final x = await task('X');
    final y = await task('Y', parent: x);
    await task('Z', parent: y); // X has 3 levels
    // Under B (depth 2) X would put Z at depth 5.
    refused(await overview.moveTask(x, ItemPlace.under(b)), 'max depth');
    // Under A (depth 1) Z lands at depth 4: allowed.
    ok(await overview.moveTask(x, ItemPlace.under(a)));
    refused(await overview.moveTask(a, ItemPlace.under(y)), 'cycle');
    refused(await overview.moveTask(a, ItemPlace.under(a)), 'cycle');
  });

  test('ORDER-003: an event is never under a task', () async {
    final t = await task('T');
    final e = await event('E');
    refused(await overview.moveEvent(e, ItemPlace.under(t)), 'cannot be under a task');
    // Also at the handler (the payload is untrusted).
    final profile = (await ProfileStore(host.db).getActiveProfile())!;
    final v = (await (host.db.select(host.db.events)..where((x) => x.id.equals(e))).getSingle()).version;
    final r = await DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db)).execute(
        Command(
            operationId: 'event-under',
            actor: ActorRef(ActorKind.owner, profile.profileId.value),
            workspaceId: profile.activeWorkspaceId.value,
            type: 'MoveEvent',
            payload: {'op': 'move', 'id': e, 'parentId': t},
            expectedVersion: Version(v),
            issuedAt: Instant.now()),
        const EventCommandHandler());
    refused(r, 'cannot be under a task');
    // Nor as a parent: an event id is not a task.
    refused(await overview.moveTask(t, ItemPlace.under(e)), 'unknown parent task');
  });

  test('colours: tasks and events, 0..11 or none', () async {
    final t = await task('T');
    final e = await event('E');
    ok(await overview.setTaskColor(t, 5));
    ok(await overview.setEventColor(e, 11));
    expect((await tasks()).single.colorIndex, 5);
    expect((await queries.watchEvents().first).single.colorIndex, 11);
    ok(await overview.setTaskColor(t, null));
    expect((await tasks()).single.colorIndex, isNull);
    refused(await overview.setTaskColor(t, -1), 'unknown colour');
    refused(await overview.setEventColor(e, 12), 'unknown colour');
  });

  test('ORDER-004: a list goes to the trash with its contents and comes back with the same set', () async {
    final work = await list('Work');
    final p = await task('Plan', list: work);
    await task('Step', parent: p);
    final old = await task('Old', list: work);
    await event('Meeting', list: work);
    await task('Elsewhere');
    // Trashed on its own first: stays in the trash after the list's restore.
    ok(await svc.tasks.trash(old));
    await Future<void>.delayed(const Duration(milliseconds: 1100)); // another tombstone second
    final before = await host.db.select(host.db.outbox).get();
    ok(await overview.trashList(work));
    expect(await lists(), isEmpty);
    expect([for (final t in await tasks()) t.title], ['Elsewhere']);
    expect(await queries.watchEvents().first, isEmpty);
    // One outbox row per row that changed (the list, Plan, Step, Meeting).
    expect((await host.db.select(host.db.outbox).get()).length - before.length, 4);

    ok(await overview.restoreList(work));
    expect(await lists(), ['Work']);
    expect(await top(work), ['Plan', 'Meeting']);
    expect(await under(p), ['Step']);
    expect((await tasks()).any((t) => t.title == 'Old'), isFalse);
    refused(await overview.restoreList(work), 'not found');
  });

  test('trashing a task: its subtasks take its place, in order', () async {
    final work = await list('Work');
    await task('A', list: work);
    final p = await task('P', list: work);
    await task('P1', parent: p);
    await task('P2', parent: p);
    await task('B', list: work);
    ok(await svc.tasks.trash(p));
    expect(await top(work), ['A', 'P1', 'P2', 'B']);
  });

  test('an event restored while its list is in the trash comes back in no list', () async {
    final work = await list('Work');
    final e = await event('Meeting', list: work);
    await task('Loose');
    ok(await events.trash(e));
    ok(await overview.trashList(work));
    ok(await events.restore(e));
    expect(await top(null), ['Loose', 'Meeting']);
    expect((await events.details(e))!.input.listId, isNull);
  });

  test('an item left in a trashed list (after a merge) shows and orders as in no list', () async {
    final work = await list('Work');
    final t = await task('Stranded', list: work);
    final e = await event('Stranded event', list: work);
    final a = await task('A');
    // As a merge restore can leave it: the list is a tombstone, its items live.
    await (host.db.update(host.db.taskLists)..where((l) => l.id.equals(work)))
        .write(TaskListsCompanion(deletedAt: Value(DateTime.utc(2026))));
    expect((await tasks()).firstWhere((x) => x.id == t).listId, isNull);
    expect((await queries.watchEvents().first).single.listId, isNull);
    expect(await top(null), ['Stranded', 'A', 'Stranded event']);
    ok(await overview.moveTask(a, const ItemPlace.loose()));
    expect(await top(null), ['A', 'Stranded', 'Stranded event']);
    // A drop after a stranded item is a valid position in no list.
    ok(await overview.moveTask(a, ItemPlace.loose(afterId: e)));
    expect(await top(null), ['Stranded', 'Stranded event', 'A']);
  });

  test('the expand state is a device setting', () async {
    final s = DirectorySettingsService(dir);
    expect(await s.expandedItems(), isEmpty);
    await s.setExpandedItems({'b', 'a'});
    expect(await DirectorySettingsService(dir).expandedItems(), {'a', 'b'});
    await dir.writeSetting('ui.overview.expanded', 'not json');
    expect(await s.expandedItems(), isEmpty);
  });
}
