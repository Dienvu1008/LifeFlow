// P01 T6c: one database file + one key per LocalProfile (SR-03, ADR-0023).
//   SR-03 / LF-INV-ID-002  each profile has its own file and key; data cannot
//                          cross because it lives in a different file (GS-11)
//   ADR-0008 / WA-001      first launch: one guest profile, one workspace
//   ADR-0023               registry intent + reconcile after an interrupted change
//   migration              the pre-SR-03 shared DB is split by profile with
//                          every id, task, audit and outbox row preserved
import 'dart:io';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show isValidOrderKey;
import 'package:drift/drift.dart' show TableInfo, Value;
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

void main() {
  late Directory base;
  late MemoryKeys keys;

  setUp(() {
    base = Directory.systemTemp.createTempSync('lifeflow_dir_');
    keys = MemoryKeys();
  });
  tearDown(() {
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  group('layout (SR-03)', () {
    test('first launch: one active guest with its own file and key', () async {
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final all = await dir.list();
      expect(all, hasLength(1));
      final guest = all.single;
      expect(guest.isActive, isTrue);
      expect(guest.isBound, isFalse);

      expect(dir.profileFile(guest.id).existsSync(), isTrue);
      expect(isPlainSqliteFile(dir.profileFile(guest.id)), isFalse);
      expect(keys.values.keys,
          containsAll([ProfileDirectory.registryKeyName, ProfileDirectory.profileKeyName(guest.id)]));
      expect(isPlainSqliteFile(File('${base.path}${Platform.pathSeparator}${ProfileDirectory.registryFileName}')),
          isFalse);

      final store = await dir.openProfile(guest.id);
      addTearDown(store.db.close);
      expect(await store.db.select(store.db.profiles).get(), hasLength(1));
      expect(await store.db.select(store.db.workspaces).get(), hasLength(1));
    });

    test('reopening keeps the same profile (no duplicate guest)', () async {
      final first = await openDirectory(base, keys);
      final id = (await first.active())!.id;
      await first.close();
      final again = await openDirectory(base, keys);
      addTearDown(again.close);
      expect((await again.list()).map((e) => e.id), [id]);
    });

    test('each new profile gets a different file AND a different key', () async {
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final a = (await dir.active())!;
      final b = await dir.createProfile(displayName: 'B');
      expect(dir.profileFile(a.id).path, isNot(dir.profileFile(b.id).path));
      final ka = keys.values[ProfileDirectory.profileKeyName(a.id)];
      final kb = keys.values[ProfileDirectory.profileKeyName(b.id)];
      expect(ka, isNotNull);
      expect(kb, isNotNull);
      expect(ka, isNot(kb));
      expect(b.isActive, isFalse); // created, not switched to
    });

    test('a missing profile file is reported, never replaced by an empty DB',
        () async {
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final b = await dir.createProfile(displayName: 'B');
      dir.profileFile(b.id).deleteSync();
      await expectLater(dir.openProfile(b.id), throwsA(isA<StoreUnavailable>()));
      expect(dir.profileFile(b.id).existsSync(), isFalse);
    });

    test('plain fallback: A\'s data is physically absent from B\'s file', () async {
      final dir = await openDirectory(base, keys, policy: AtRestPolicy.plain);
      addTearDown(dir.close);
      final host = TestHost(dir);
      await host.openActive();
      await Services(host, FakeAuthGateway()).tasks.create('Only-in-A-zx91');
      final b = await dir.createProfile(displayName: 'B');
      await host.close();
      final bBytes = String.fromCharCodes(dir.profileFile(b.id).readAsBytesSync());
      expect(bBytes.contains('Only-in-A-zx91'), isFalse);
      final aBytes = String.fromCharCodes(
          dir.profileFile((await dir.list()).firstWhere((e) => e.id != b.id).id)
              .readAsBytesSync());
      expect(aBytes.contains('Only-in-A-zx91'), isTrue); // sanity: plain build
    });
  });

  group('switching (OQ-S7, LF-INV-ID-002)', () {
    test('switchTo swaps the store; each profile sees only its own tasks',
        () async {
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final host = TestHost(dir);
      addTearDown(host.close);
      await host.openActive();
      final a = host.currentId!;
      var s = Services(host, FakeAuthGateway());
      await s.tasks.create('A-task');

      final b = await dir.createProfile(displayName: 'B');
      expect(await s.profiles.switchTo(b.id), isA<CommandOk>());
      expect(host.activations, [b.id]);
      s = Services(host, FakeAuthGateway());
      expect(await s.titles(), isEmpty);
      await s.tasks.create('B-task');

      await s.profiles.switchTo(a);
      s = Services(host, FakeAuthGateway());
      expect(await s.titles(), ['A-task']);
      final list = await s.profiles.list();
      expect(list.where((p) => p.isActive).single.id, a);
    });

    test('switching to the active profile does not reopen anything', () async {
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final host = TestHost(dir);
      addTearDown(host.close);
      await host.openActive();
      await Services(host, FakeAuthGateway()).profiles.switchTo(host.currentId!);
      expect(host.activations, isEmpty);
    });

    test('switching to an unknown profile returns notFound', () async {
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final host = TestHost(dir);
      addTearDown(host.close);
      await host.openActive();
      final r = await Services(host, FakeAuthGateway()).profiles.switchTo('nope');
      expect((r as CommandFailure).kind, CommandFailureKind.notFound);
    });
  });

  group('schema v1 -> v2 on existing files (ADR-0024)', () {
    test('an existing v1 profile store and registry upgrade, data intact',
        () async {
      var dir = await openDirectory(base, keys);
      final id = (await dir.active())!.id;
      final host = TestHost(dir);
      await host.openActive();
      await Services(host, FakeAuthGateway()).tasks.create('Kept across upgrade');
      // Turn both files back into what T6c-before-ADR-0024 builds wrote.
      await rewindProfileStore(host.db, 1);
      await host.close();
      await dir.close();
      final reg = await openRegistryStore(
          file: File('${base.path}${Platform.pathSeparator}${ProfileDirectory.registryFileName}'),
          policy: AtRestPolicy.encrypt,
          keys: keys(ProfileDirectory.registryKeyName),
          background: false);
      await reg.customStatement('ALTER TABLE registry_profiles DROP COLUMN signed_out');
      await reg.customStatement('PRAGMA user_version = 1');
      await reg.close();

      dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final entry = (await dir.active())!;
      expect(entry.id, id);
      expect(entry.signedOut, isFalse);
      final store = await dir.openProfile(id);
      addTearDown(store.db.close);
      expect((await store.db.select(store.db.tasks).get()).single.title,
          'Kept across upgrade');
      expect((await store.db.select(store.db.profiles).getSingle()).signedOut,
          isFalse);
      final v = await store.db.customSelect('PRAGMA user_version').getSingle();
      expect(v.data.values.first, AppDatabase.currentSchemaVersion); // on to the latest
      expect(await store.db.select(store.db.restoreSnapshots).get(), isEmpty);
      expect(await store.db.select(store.db.schedules).get(), isEmpty);
    });

    for (final from in [2, 3, 4, 5, 6, 7]) {
      test('an existing v$from profile store upgrades to the latest schema, '
          'data intact (ADR-0025, ADR-0029)', () async {
        var dir = await openDirectory(base, keys);
        final id = (await dir.active())!.id;
        final host = TestHost(dir);
        await host.openActive();
        await Services(host, FakeAuthGateway()).tasks.create('Kept across upgrade');
        await rewindProfileStore(host.db, from);
        await host.close();
        await dir.close();

        dir = await openDirectory(base, keys);
        addTearDown(dir.close);
        final store = await dir.openProfile(id);
        addTearDown(store.db.close);
        final db = store.db;
        expect((await db.select(db.tasks).get()).single.title, 'Kept across upgrade');
        expect(await db.select(db.restoreSnapshots).get(), isEmpty);
        for (final TableInfo t in [db.calendars, db.events, db.schedules,
            db.occurrenceExceptions, db.occurrenceCompletions, db.reminders,
            db.focusSessions, db.executionRecords, db.measurements, db.periodResults,
            db.goals, db.milestones, db.goalLinks]) {
          expect(await db.select(t).get(), isEmpty, reason: t.actualTableName);
        }
        // The planning (v4) and execution (v5) indexes exist after the
        // upgrade, as on a new store.
        final idx = await db.customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN "
            "('schedules_range','exceptions_subject','completions_task','reminders_subject',"
            "'measurements_task_date','focus_sessions_state','execution_records_task','period_results_task',"
            "'milestones_goal','goal_links_goal','goal_links_item')").get();
        expect(idx, hasLength(11));
        // P03 task columns get their defaults on existing rows (ADR-0037).
        final task = (await db.select(db.tasks).get()).single;
        expect((task.targetAggregation, task.isHabit, task.trackedSince), ('sum', false, null));
        final v = await db.customSelect('PRAGMA user_version').getSingle();
        expect(v.data.values.first, AppDatabase.currentSchemaVersion);
        // The upgraded store works: a task with a schedule can be written.
        await db.into(db.schedules).insert(SchedulesCompanion.insert(
            id: 'task:x', workspaceId: 'w', ownerId: 'o', subjectType: 'task',
            subjectId: 'x', firstDate: '2026-11-09',
            createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026)));
        expect(await db.select(db.schedules).get(), hasLength(1));
        // P03 UX U2 (v7): no colour; a valid order key (ADR-0046).
        expect((task.colorIndex, isValidOrderKey(task.orderKey)), (null, true));
      });
    }

    test('v6 -> v7 keys every list, task and event in the order shown so far (ADR-0046)', () async {
      var dir = await openDirectory(base, keys);
      final id = (await dir.active())!.id;
      final host = TestHost(dir);
      await host.openActive();
      final svc = Services(host, FakeAuthGateway());
      Future<String> task(String t, {String? parent}) async =>
          (await svc.tasks.create(t, parentId: parent) as CommandOk).entityId;
      await task('A');
      final b = await task('B');
      await task('B1', parent: b);
      await task('B2', parent: b);
      await task('C');
      final now = DateTime.utc(2026, 11, 12);
      for (final (lid, title) in [('l1', 'Work'), ('l2', 'Home')]) {
        await host.db.into(host.db.taskLists).insert(TaskListsCompanion.insert(
            id: lid, workspaceId: (await host.db.select(host.db.workspaces).getSingle()).id, ownerId: 'o',
            createdAt: now, updatedAt: now, title: title));
      }
      await rewindProfileStore(host.db, 6);
      await host.close();
      await dir.close();

      dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final store = await dir.openProfile(id);
      addTearDown(store.db.close);
      final db = store.db;
      final tasks = {for (final t in await db.select(db.tasks).get()) t.title: t.orderKey};
      expect(tasks.values.every(isValidOrderKey), isTrue);
      // Each container in creation order: A < B < C at the top, B1 < B2 under B.
      expect(tasks['A']!.compareTo(tasks['B']!) < 0 && tasks['B']!.compareTo(tasks['C']!) < 0, isTrue);
      expect(tasks['B1']!.compareTo(tasks['B2']!) < 0, isTrue);
      final lists = (await db.select(db.taskLists).get())..sort((a, b) => a.orderKey.compareTo(b.orderKey));
      expect(lists.map((l) => l.title), ['Work', 'Home']);
      expect(lists.every((l) => l.colorIndex == null), isTrue);
    });

    test('a locked profile can never become active', () async {
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final b = await dir.createProfile(displayName: 'B');
      final store = await dir.openProfile(b.id);
      await store.db.customStatement(
          "UPDATE profiles SET account_id = 'acc', account_provider = 'github', signed_out = 1");
      await dir.syncFromStore(b.id, store.db);
      await store.db.close();
      expect(() => dir.setActive(b.id), throwsStateError);
      expect((await dir.active())!.id, isNot(b.id));
    });
  });

  group('cross-store ordering (ADR-0023)', () {
    test('an interrupted change (store committed, registry not) is reconciled',
        () async {
      final dir = await openDirectory(base, keys);
      final id = (await dir.active())!.id;
      // Simulate a crash after the store committed but before syncFromStore.
      await dir.beginStoreChange(id);
      final store = await dir.openProfile(id);
      final row = await store.db.select(store.db.profiles).getSingle();
      final gw = DriftCommandGateway(store.db, WorkspaceOwnerAuthorization(store.db));
      final r = await gw.execute(
        Command(
          operationId: 'op-bind',
          actor: ActorRef(ActorKind.owner, id),
          workspaceId: row.activeWorkspaceId,
          type: 'BindAccount',
          payload: {
            'op': 'bind', 'id': id, 'accountId': 'acc-9', 'provider': 'github',
            'hasData': false, 'moveData': true,
          },
          expectedVersion: Version(row.version),
          issuedAt: Instant.now(),
        ),
        const ProfileCommandHandler(),
      );
      expect(r, isA<CommandOk>());
      await store.db.close();
      expect((await dir.active())!.isBound, isFalse); // registry is stale
      await dir.close();

      final reopened = await openDirectory(base, keys);
      addTearDown(reopened.close);
      final e = (await reopened.active())!;
      expect(e.isBound, isTrue);
      expect(e.accountId, 'acc-9');
      expect(e.provider, 'github');
    });
  });

  group('migration of the pre-SR-03 shared database', () {
    late File legacy;
    late String aId, bId, aWs, bWs;

    /// Builds a shared DB the way T4-T6b builds did: guest A (active) and an
    /// account profile B, each with tasks written through the gateway.
    Future<void> seedLegacy({AtRestPolicy policy = AtRestPolicy.encrypt}) async {
      legacy = File('${base.path}${Platform.pathSeparator}${ProfileDirectory.legacyFileName}');
      final opened = await openLocalStore(
          file: legacy, policy: policy, keys: keys(ProfileDirectory.legacyKeyName), background: false);
      final db = opened.db;
      final a = await ProfileStore(db).ensureFirstProfile(displayName: 'Guest');
      aId = a.profileId.value;
      aWs = a.activeWorkspaceId.value;
      bId = EntityId.generate().value;
      bWs = EntityId.generate().value;
      final now = DateTime.now().toUtc();
      await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(id: bWs, ownerId: bId, createdAt: now));
      await db.into(db.profiles).insert(ProfilesCompanion.insert(
          id: bId,
          activeWorkspaceId: bWs,
          accountId: const Value('acc-b'),
          accountProvider: const Value('github'),
          createdAt: now.add(const Duration(seconds: 1))));
      final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
      Future<void> create(String owner, String ws, String id, String title,
          {String? parent}) async {
        final r = await gw.execute(
          Command(
            operationId: 'op-$id',
            actor: ActorRef(ActorKind.owner, owner),
            workspaceId: ws,
            type: 'CreateTask',
            payload: {'op': 'create', 'id': id, 'title': title, 'parentId': parent},
            issuedAt: Instant.now(),
          ),
          TaskCommandHandler(),
        );
        expect(r, isA<CommandOk>(), reason: '$r');
      }

      await create(aId, aWs, 'a1', 'Learn English');
      await create(aId, aWs, 'a2', 'Chapter one', parent: 'a1');
      await create(bId, bWs, 'b1', 'Work report');
      await db.close();
    }

    test('splits by profile, keeps every id and row, keeps a backup', () async {
      await seedLegacy();
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);

      expect(dir.lastMigration!.profiles, 2);
      expect(dir.lastMigration!.unmappedGovernanceRows, 0);
      final all = await dir.list();
      expect(all.map((e) => e.id), [aId, bId]); // same ids, creation order
      expect(all.firstWhere((e) => e.id == aId).isActive, isTrue);
      expect(all.firstWhere((e) => e.id == bId).accountId, 'acc-b');

      // The shared file is kept as an encrypted backup, not deleted.
      expect(legacy.existsSync(), isFalse);
      expect(dir.legacyBackupFile.existsSync(), isTrue);
      expect(isPlainSqliteFile(dir.legacyBackupFile), isFalse);

      final a = (await dir.openProfile(aId)).db;
      addTearDown(a.close);
      expect((await a.select(a.tasks).get()).map((t) => t.id), unorderedEquals(['a1', 'a2']));
      expect((await a.select(a.tasks).get()).firstWhere((t) => t.id == 'a2').parentTaskId, 'a1');
      expect((await a.select(a.workspaces).get()).single.id, aWs);
      expect((await a.select(a.profiles).get()).single.id, aId);
      expect(await a.select(a.auditLog).get(), hasLength(2));
      expect(await a.select(a.outbox).get(), hasLength(2));
      expect(await a.searchTaskIds(aWs, 'English'), ['a1']); // FTS rebuilt

      final b = (await dir.openProfile(bId)).db;
      addTearDown(b.close);
      expect((await b.select(b.tasks).get()).map((t) => t.id), ['b1']);
      expect(await b.select(b.auditLog).get(), hasLength(1));
      expect((await b.select(b.profiles).get()).single.accountId, 'acc-b');
      expect(await b.searchTaskIds(bWs, 'English'), isEmpty); // no A data
    });

    test('runs once: reopening does not migrate again', () async {
      await seedLegacy();
      await (await openDirectory(base, keys)).close();
      final again = await openDirectory(base, keys);
      addTearDown(again.close);
      expect(again.lastMigration, isNull);
      expect(await again.list(), hasLength(2));
    });

    test('a partial copy from an interrupted attempt is redone from the source',
        () async {
      await seedLegacy();
      // A stray, incomplete store for A exists (crash before the registry
      // commit); the legacy source is still intact.
      final stray = await openLocalStore(
          file: File('${base.path}${Platform.pathSeparator}profiles${Platform.pathSeparator}$aId.sqlite')
            ..parent.createSync(recursive: true),
          policy: AtRestPolicy.encrypt,
          keys: keys(ProfileDirectory.profileKeyName(aId)),
          background: false);
      await stray.db.customStatement('SELECT 1');
      await stray.db.close();

      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      final a = (await dir.openProfile(aId)).db;
      addTearDown(a.close);
      expect(await a.select(a.tasks).get(), hasLength(2));
      expect(await a.select(a.profiles).get(), hasLength(1));
    });

    test('migrated but not yet renamed: only the rename is finished', () async {
      await seedLegacy();
      await (await openDirectory(base, keys)).close();
      // Put the file back under the legacy name (as if the rename was lost).
      final dirPath = base.path;
      File('$dirPath${Platform.pathSeparator}${ProfileDirectory.legacyFileName}${ProfileDirectory.legacyBackupSuffix}')
          .renameSync(legacy.path);
      final dir = await openDirectory(base, keys);
      addTearDown(dir.close);
      expect(dir.lastMigration, isNull);
      expect(legacy.existsSync(), isFalse);
      expect(dir.legacyBackupFile.existsSync(), isTrue);
      expect(await dir.list(), hasLength(2));
    });

    test('a plain shared DB (fallback build) migrates to plain stores', () async {
      await seedLegacy(policy: AtRestPolicy.plain);
      final dir = await openDirectory(base, keys, policy: AtRestPolicy.plain);
      addTearDown(dir.close);
      expect(isPlainSqliteFile(dir.profileFile(aId)), isTrue);
      final a = (await dir.openProfile(aId)).db;
      addTearDown(a.close);
      expect(await a.select(a.tasks).get(), hasLength(2));
    });
  });
}
