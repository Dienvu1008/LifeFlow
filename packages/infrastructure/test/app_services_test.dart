// P01 T6a: the services the UI consumes, on the REAL store + gateway + the
// production authorization policy (no fakes for authz).
//   GS-11 / LF-INV-GOV-002  non-owner / unknown workspace / non-owner actor denied
//   (profile switching + isolation across stores: profile_directory_test)
//   LF-INV-TASK-011         trashed tasks leave the stream
//   OQ-R3                   complete with / without descendants
//   LF-INV-TASK-002         depth rejection is returned, not thrown
import 'dart:async';

import 'package:application/application.dart';
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

Future<void> pumpUntil(bool Function() cond) async {
  for (var i = 0; i < 200; i++) {
    if (cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition not reached in time');
}

void main() {
  late AppDatabase db;
  late DriftCommandGateway gw;
  late DriftTaskService tasks;
  late DriftTaskQueries queries;
  late ProfileStore store;
  final subs = <StreamSubscription<Object?>>[];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    tasks = DriftTaskService(db, gw);
    queries = DriftTaskQueries(db);
    store = ProfileStore(db);
    await store.ensureFirstProfile(displayName: 'A');
  });

  tearDown(() async {
    for (final s in subs) {
      await s.cancel();
    }
    subs.clear();
    await db.close();
  });

  Future<List<TaskView>> current() => queries.watchTasks().first;

  group('WorkspaceOwnerAuthorization (GS-11, LF-INV-GOV-002)', () {
    late String wsId;
    late String ownerId;
    setUp(() async {
      final p = (await store.getActiveProfile())!;
      wsId = p.activeWorkspaceId.value;
      ownerId = p.profileId.value;
    });
    final policy = () => WorkspaceOwnerAuthorization(db);

    test('the workspace owner is allowed', () async {
      expect(
          await policy().denyReason(ActorRef(ActorKind.owner, ownerId), 'x',
              ResourceRef(wsId, 'task', 't')),
          isNull);
    });

    test('another owner is denied', () async {
      expect(
          await policy().denyReason(const ActorRef(ActorKind.owner, 'intruder'),
              'x', ResourceRef(wsId, 'task', 't')),
          isNotNull);
    });

    test('a non-owner actor kind (AI) is denied even with the owner id',
        () async {
      expect(
          await policy().denyReason(ActorRef(ActorKind.aiAssistant, ownerId),
              'x', ResourceRef(wsId, 'task', 't')),
          isNotNull);
    });

    test('an unknown workspace is denied', () async {
      expect(
          await policy().denyReason(ActorRef(ActorKind.owner, ownerId), 'x',
              const ResourceRef('nope', 'task', 't')),
          isNotNull);
    });
  });

  group('DriftTaskService + DriftTaskQueries', () {
    test('create / rename / trash are reflected in the stream (TASK-011)',
        () async {
      final seen = <List<TaskView>>[];
      subs.add(queries.watchTasks().listen(seen.add));
      await pumpUntil(() => seen.isNotEmpty);
      expect(seen.last, isEmpty);

      final r = await tasks.create('  Buy milk  ');
      expect(r, isA<CommandOk>(), reason: '$r');
      await pumpUntil(() => seen.last.length == 1);
      expect(seen.last.single.title, 'Buy milk'); // trimmed
      final id = seen.last.single.id;

      expect(await tasks.rename(id, 'Buy oat milk'), isA<CommandOk>());
      await pumpUntil(() => seen.last.single.title == 'Buy oat milk');

      expect(await tasks.trash(id), isA<CommandOk>());
      await pumpUntil(() => seen.last.isEmpty);
    });

    test('empty title is rejected and nothing is written', () async {
      final r = await tasks.create('   ');
      expect(r, isA<CommandFailure>());
      expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
      expect(await current(), isEmpty);
      expect(await db.select(db.auditLog).get(), isEmpty);
    });

    test('depth limit surfaces as a returned failure (LF-INV-TASK-002)',
        () async {
      String? parent;
      for (var i = 1; i <= 4; i++) {
        final r = await tasks.create('L$i', parentId: parent);
        expect(r, isA<CommandOk>(), reason: 'level $i: $r');
        parent = (r as CommandOk).entityId;
      }
      final r5 = await tasks.create('L5', parentId: parent);
      expect(r5, isA<CommandFailure>());
      expect((r5 as CommandFailure).kind, CommandFailureKind.validationFailed);
      expect((await current()).length, 4);
    });

    test('complete: only vs with descendants (OQ-R3)', () async {
      final p = (await tasks.create('Parent') as CommandOk).entityId;
      await tasks.create('Child', parentId: p);
      expect(await tasks.complete(p, withDescendants: false), isA<CommandOk>());
      var list = await current();
      expect(list.firstWhere((t) => t.id == p).isDone, isTrue);
      expect(list.firstWhere((t) => t.parentId == p).isDone, isFalse);

      final p2 = (await tasks.create('Parent2') as CommandOk).entityId;
      await tasks.create('Child2', parentId: p2);
      expect(await tasks.complete(p2, withDescendants: true), isA<CommandOk>());
      list = await current();
      expect(list.firstWhere((t) => t.parentId == p2).isDone, isTrue);
    });

    test('renaming a task that does not exist returns notFound', () async {
      final r = await tasks.rename('missing', 'x');
      expect((r as CommandFailure).kind, CommandFailureKind.notFound);
    });
  });

  test('storageNoticeFrom maps the Windows fallback tracked exception',
      () async {
    final status = await const StorageSecurity(
            platform: StoragePlatform.windows, windowsPlainFallback: true)
        .evaluate(() async => null);
    final n = storageNoticeFrom(status);
    expect(n.atRestEncrypted, isFalse);
    expect(n.trackedException, isTrue);
    expect(n.needsAttention, isTrue);

    final ok = storageNoticeFrom(
        await const StorageSecurity(platform: StoragePlatform.android)
            .evaluate(() async => 'sqlite3mc'));
    expect(ok.needsAttention, isFalse);
  });
}
