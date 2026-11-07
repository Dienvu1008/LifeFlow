// P01 T7: export / restore of one profile (UC-20a, ADR-0025).
//   GS-20 / AC-20a.1   export -> restore into a CLEAN install gives equal data,
//                      with tombstones, hierarchy, measurable fields, audit
//   AC-20a.2           a newer-version file is rejected with a clear message
//   LF-INV-SEC-010     the export covers every table, tombstones and audit
//   LF-INV-SEC-001     no key or token in the export
//   SR-14 / threat T9  untrusted until validated; failure writes nothing
//   LF-INV-ID-001      ids survive a clean-install round trip
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

void main() {
  late Directory base;
  late MemoryKeys keys;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late DriftDataTransferService transfer;
  late String profileId;
  late String workspaceId;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_export_');
    keys = MemoryKeys();
    dir = await openDirectory(base, keys);
    host = TestHost(dir);
    await host.openActive();
    svc = Services(host, FakeAuthGateway());
    transfer = DriftDataTransferService(host.db, dir,
        clock: () => DateTime.utc(2026, 11, 7, 9));
    profileId = host.currentId!;
    workspaceId =
        (await host.db.select(host.db.workspaces).getSingle()).id;
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  /// Subtasks, a done task, a trashed task (tombstone), a measurable target,
  /// a task list, audit/outbox rows from the real gateway.
  Future<void> seed() async {
    final a = (await svc.tasks.create('Learn English') as CommandOk).entityId;
    await svc.tasks.create('Chapter 1', parentId: a);
    await svc.tasks.create('Chapter 2', parentId: a);
    final gone = (await svc.tasks.create('Old idea') as CommandOk).entityId;
    await svc.tasks.trash(gone);
    final done = (await svc.tasks.create('Pay rent') as CommandOk).entityId;
    await svc.tasks.complete(done, withDescendants: false);
    final db = host.db;
    await db.into(db.taskLists).insert(TaskListsCompanion.insert(
        id: 'list-1',
        workspaceId: workspaceId,
        ownerId: profileId,
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
        title: 'Study'));
    await (db.update(db.tasks)..where((t) => t.id.equals(a))).write(
        const TasksCompanion(
            targetType: Value('atLeast'),
            targetMin: Value(30.5),
            unit: Value('min'),
            taskListId: Value('list-1'),
            tags: Value('["language","daily"]')));
  }

  /// A comparable snapshot of a store, independent of the profile's local
  /// binding fields (a restore is always an unbound guest).
  Future<Map<String, List<String>>> snapshot(AppDatabase db) async {
    List<String> j(Iterable<Map<String, dynamic>> rows) =>
        (rows.map((r) => jsonEncode(r)).toList()..sort());
    final profiles = (await db.select(db.profiles).get()).map((p) {
      final m = p.toJson();
      for (final k in ['accountId', 'accountProvider', 'signedOut', 'isActive']) {
        m.remove(k);
      }
      return m;
    });
    return {
      'profiles': j(profiles),
      'workspaces': j((await db.select(db.workspaces).get()).map((r) => r.toJson())),
      'taskLists': j((await db.select(db.taskLists).get()).map((r) => r.toJson())),
      'tasks': j((await db.select(db.tasks).get()).map((r) => r.toJson())),
      'auditLog': j((await db.select(db.auditLog).get()).map((r) => r.toJson())),
      'outbox': j((await db.select(db.outbox).get()).map((r) => r.toJson())),
      'eventLog': j((await db.select(db.eventLog).get()).map((r) => r.toJson())),
      'opDedupe': j((await db.select(db.opDedupe).get()).map((r) => r.toJson())),
    };
  }

  Future<(Directory, MemoryKeys, ProfileDirectory)> cleanInstall() async {
    final b = Directory.systemTemp.createTempSync('lifeflow_clean_');
    final k = MemoryKeys();
    final d = await openDirectory(b, k);
    addTearDown(() async {
      await d.close();
      if (b.existsSync()) b.deleteSync(recursive: true);
    });
    return (b, k, d);
  }

  Map<String, Object?> envelope(String text) =>
      (jsonDecode(text) as Map).cast<String, Object?>();
  Map<String, Object?> payloadOf(String text) =>
      (envelope(text)['payload'] as Map).cast<String, Object?>();
  ParsedExport parse(String text) => ProfileExport.parse(text, currentSchemaVersion: 3);
  void expectRejected(String text, RestoreRejection kind, {String? mentions}) {
    try {
      parse(text);
      fail('expected the file to be rejected');
    } on ExportRejected catch (e) {
      expect(e.kind, kind, reason: e.message);
      if (mentions != null) expect(e.message, contains(mentions));
    }
  }

  group('export content', () {
    test('covers every table of the schema (guard for LF-INV-SEC-010)',
        () async {
      // A new table must be added to the export (or deliberately listed as
      // not exported), or this test fails.
      expect(host.db.allTables.map((t) => t.entityName).toSet(), {
        ...['profiles', 'workspaces', 'task_lists', 'tasks', 'audit_log',
            'outbox', 'event_log', 'op_dedupe'],
        'restore_snapshots',
      });
      expect(host.db.allTables.length,
          exportedTables.length + notExportedTables.length);
      final text = await ProfileExport.build(host.db);
      expect(payloadOf(text).keys, unorderedEquals(exportedTables));
    });

    test('is versioned and checksummed, and includes tombstones + audit',
        () async {
      await seed();
      final f = await transfer.exportActiveProfile();
      final env = envelope(f.contents);
      expect(env['format'], 'lifeflow-export');
      expect(env['formatVersion'], 1);
      expect(env['schemaVersion'], 3);
      expect(env['checksumSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(env['notice'], contains('unencrypted'));
      final tasks = (payloadOf(f.contents)['tasks'] as List).cast<Map>();
      expect(tasks, hasLength(5));
      expect(f.taskCount, 5);
      expect(tasks.where((t) => t['deletedAt'] != null), hasLength(1)); // tombstone
      expect((payloadOf(f.contents)['auditLog'] as List), isNotEmpty);
      expect((payloadOf(f.contents)['outbox'] as List), isNotEmpty);
    });

    test('suggested file name is safe and dated', () async {
      final f = await transfer.exportActiveProfile();
      expect(f.suggestedName, 'lifeflow-profile-2026-11-07.lifeflow.json');
    });

    test('contains no key, token or password (SEC-001)', () async {
      final auth = FakeAuthGateway();
      final s = Services(host, auth);
      await s.accounts.signIn(const OAuthSignIn('github'));
      await seed();
      final text = (await DriftDataTransferService(host.db, dir).exportActiveProfile()).contents;
      for (final key in keys.values.values) {
        expect(text.contains(key), isFalse, reason: 'a database key leaked');
      }
      expect(text.contains(auth.secretToken!), isFalse);
      expect(text.contains('tok_'), isFalse);
    });
  });

  group('round trip into a clean install (GS-20, AC-20a.1)', () {
    test('restored data equals the original and keeps every id', () async {
      await seed();
      final original = await snapshot(host.db);
      final file = await transfer.exportActiveProfile();

      final (cleanBase, cleanKeys, cleanDir) = await cleanInstall();
      final cleanHost = TestHost(cleanDir);
      await cleanHost.openActive();
      addTearDown(cleanHost.close);
      final cleanTransfer = DriftDataTransferService(cleanHost.db, cleanDir);

      final r = await cleanTransfer.restore(file.contents);
      expect(r, isA<Restored>(), reason: '$r');
      final restored = r as Restored;
      expect(restored.profile.id, profileId); // clean install: original ids
      expect(restored.taskCount, 5);

      final store = await cleanDir.openProfile(profileId);
      addTearDown(store.db.close);
      expect(await snapshot(store.db), original);

      // Own file and own key under the clean install's policy (SR-03).
      expect(isPlainSqliteFile(cleanDir.profileFile(profileId)), isFalse);
      expect(cleanKeys.values.containsKey(ProfileDirectory.profileKeyName(profileId)), isTrue);
      expect(cleanBase.existsSync(), isTrue);
    });

    test('the hierarchy, tombstone, measurable fields and FTS survive',
        () async {
      await seed();
      final file = await transfer.exportActiveProfile();
      final (_, _, cleanDir) = await cleanInstall();
      final h = TestHost(cleanDir);
      await h.openActive();
      addTearDown(h.close);
      await DriftDataTransferService(h.db, cleanDir).restore(file.contents);

      final store = await cleanDir.openProfile(profileId);
      addTearDown(store.db.close);
      final db = store.db;
      final byTitle = {for (final t in await db.select(db.tasks).get()) t.title: t};
      expect(byTitle['Chapter 1']!.parentTaskId, byTitle['Learn English']!.id);
      expect(byTitle['Old idea']!.deletedAt, isNotNull); // still a tombstone
      expect(byTitle['Learn English']!.targetMin, 30.5);
      expect(byTitle['Learn English']!.tags, '["language","daily"]');
      expect(byTitle['Pay rent']!.status, 'done');
      expect(await db.searchTaskIds(workspaceId, 'English'),
          [byTitle['Learn English']!.id]); // index rebuilt
      expect(await db.searchTaskIds(workspaceId, 'idea'), isEmpty); // trash hidden
    });

    test('a bound profile is restored as an unbound guest (never two for one account)',
        () async {
      final s = Services(host, FakeAuthGateway());
      await s.accounts.signIn(const OAuthSignIn('github'));
      await seed();
      expect((await dir.active())!.isBound, isTrue);
      final file = await DriftDataTransferService(host.db, dir).exportActiveProfile();

      final (_, _, cleanDir) = await cleanInstall();
      final h = TestHost(cleanDir);
      await h.openActive();
      addTearDown(h.close);
      await DriftDataTransferService(h.db, cleanDir).restore(file.contents);

      final entry = (await cleanDir.list()).firstWhere((e) => e.id == profileId);
      expect(entry.isBound, isFalse);
      expect(entry.isLocked, isFalse);
      expect(await cleanDir.findByAccount('acc-123'), isNull);
      // The profile's OWN store is the source of truth (ADR-0023): it must not
      // keep the binding either, or store and registry would disagree.
      final store = await cleanDir.openProfile(profileId);
      addTearDown(store.db.close);
      final row = await store.db.select(store.db.profiles).getSingle();
      expect(row.accountId, isNull);
      expect(row.accountProvider, isNull);
      expect(row.signedOut, isFalse);
      // The original keeps its account.
      expect((await dir.active())!.accountId, 'acc-123');
    });
  });

  group('the same profile is never restored as a second profile', () {
    test('without a choice nothing is written and no profile is added',
        () async {
      await seed();
      final before = await snapshot(host.db);
      final file = await transfer.exportActiveProfile();
      final r = await transfer.restore(file.contents);
      expect(r, isA<RestoreRejected>());
      expect((r as RestoreRejected).kind, RestoreRejection.notApplicable);
      expect(await dir.list(), hasLength(1));
      expect(await snapshot(host.db), before);
      // The directory refuses it too (defence in depth).
      await expectLater(
          dir.restoreFromExport(parse(file.contents)), throwsStateError);
      expect(await dir.list(), hasLength(1));
      expect(dir.profileFile(profileId).existsSync(), isTrue);
    });
  });

  group('untrusted input (SR-14, T9)', () {
    late String good;
    setUp(() async {
      await seed();
      good = (await transfer.exportActiveProfile()).contents;
    });

    test('a newer file version is rejected with a clear message (AC-20a.2)', () {
      final env = envelope(good)..['formatVersion'] = 2;
      expectRejected(jsonEncode(env), RestoreRejection.newerVersion,
          mentions: 'newer version of LifeFlow');
    });

    test('a file from a newer schema is rejected (AC-20a.2)', () {
      final env = envelope(good)..['schemaVersion'] = 4;
      expectRejected(jsonEncode(env), RestoreRejection.newerVersion);
    });

    test('a changed byte fails the checksum', () {
      final env = envelope(good);
      ((env['payload'] as Map)['tasks'] as List).first['title'] = 'Tampered';
      expectRejected(jsonEncode(env), RestoreRejection.corrupted);
    });

    test('a changed checksum fails too', () {
      final env = envelope(good)..['checksumSha256'] = 'a' * 64;
      expectRejected(jsonEncode(env), RestoreRejection.corrupted);
    });

    test('not JSON, wrong JSON, or truncated is "not an export"', () {
      expectRejected('', RestoreRejection.notAnExport);
      expectRejected('hello', RestoreRejection.notAnExport);
      expectRejected('{"a":1}', RestoreRejection.notAnExport);
      expectRejected('[1,2,3]', RestoreRejection.notAnExport);
      expectRejected(good.substring(0, good.length ~/ 2), RestoreRejection.notAnExport);
    });

    test('an oversized file is refused before parsing', () {
      try {
        ProfileExport.parse(good, currentSchemaVersion: 3, maxBytes: 100);
        fail('expected rejection');
      } on ExportRejected catch (e) {
        expect(e.kind, RestoreRejection.tooLarge);
      }
    });

    test('row counts that do not match are rejected', () {
      final env = envelope(good);
      (env['counts'] as Map)['tasks'] = 99;
      expectRejected(jsonEncode(env), RestoreRejection.invalidContents);
    });

    Map<String, Object?> sealedPayload() => payloadOf(good);
    String reseal(Map<String, Object?> p) => ProfileExport.seal(p, schemaVersion: 3);

    test('a correctly sealed file with a parent cycle is rejected', () {
      final p = sealedPayload();
      final tasks = (p['tasks'] as List).cast<Map>();
      final a = tasks.firstWhere((t) => t['title'] == 'Learn English');
      final c1 = tasks.firstWhere((t) => t['title'] == 'Chapter 1');
      a['parentTaskId'] = c1['id']; // a -> c1 -> a
      expectRejected(reseal(p), RestoreRejection.invalidContents, mentions: 'cycle');
    });

    test('a task in an unknown workspace is rejected', () {
      final p = sealedPayload();
      (p['tasks'] as List).first['workspaceId'] = 'not-a-workspace';
      expectRejected(reseal(p), RestoreRejection.invalidContents);
    });

    test('a dangling parent or list reference is rejected', () {
      final p = sealedPayload();
      (p['tasks'] as List).first['parentTaskId'] = 'ghost';
      expectRejected(reseal(p), RestoreRejection.invalidContents);
      final q = sealedPayload();
      (q['tasks'] as List).first['taskListId'] = 'ghost-list';
      expectRejected(reseal(q), RestoreRejection.invalidContents);
    });

    test('two profiles or a duplicate task id is rejected', () {
      final p = sealedPayload();
      (p['profiles'] as List).add((p['profiles'] as List).first);
      expectRejected(reseal(p), RestoreRejection.invalidContents);
      final q = sealedPayload();
      final tasks = (q['tasks'] as List);
      tasks.add(Map.of(tasks.first as Map));
      expectRejected(reseal(q), RestoreRejection.invalidContents);
    });

    test('a profile whose workspace belongs to someone else is rejected', () {
      final p = sealedPayload();
      (p['workspaces'] as List).first['ownerId'] = 'someone-else';
      expectRejected(reseal(p), RestoreRejection.invalidContents);
    });

    test('a rejected file writes NOTHING (atomic)', () async {
      final filesBefore = Directory('${base.path}${Platform.pathSeparator}profiles')
          .listSync().length;
      final listBefore = (await dir.list()).map((e) => e.id).toList();
      final env = envelope(good);
      ((env['payload'] as Map)['tasks'] as List).first['title'] = 'Tampered';
      final r = await transfer.restore(jsonEncode(env));
      expect(r, isA<RestoreRejected>());
      expect((r as RestoreRejected).kind, RestoreRejection.corrupted);
      expect(Directory('${base.path}${Platform.pathSeparator}profiles').listSync().length,
          filesBefore);
      expect((await dir.list()).map((e) => e.id).toList(), listBefore);
    });

    test('the rejection message never echoes file contents', () async {
      final env = envelope(good);
      ((env['payload'] as Map)['tasks'] as List).first['title'] = 'Secret-zx91';
      final r = await transfer.restore(jsonEncode(env)) as RestoreRejected;
      expect(r.message.contains('Secret-zx91'), isFalse);
    });
  });

  group('older files (additive migrations)', () {
    test('a schema-1 export (no signed_out column) restores', () async {
      await seed();
      final file = (await transfer.exportActiveProfile()).contents;
      final p = payloadOf(file);
      for (final row in (p['profiles'] as List).cast<Map>()) {
        row.remove('signedOut');
      }
      final v1 = ProfileExport.seal(p, schemaVersion: 1);
      final (_, _, cleanDir) = await cleanInstall();
      final h = TestHost(cleanDir);
      await h.openActive();
      addTearDown(h.close);
      final r = await DriftDataTransferService(h.db, cleanDir).restore(v1);
      expect(r, isA<Restored>(), reason: '$r');
      expect((await cleanDir.list()).any((e) => e.id == profileId), isTrue);
    });
  });

  group('service', () {
    test('garbage is rejected with a user message and nothing is added',
        () async {
      final r = await transfer.restore('this is not a backup');
      expect(r, isA<RestoreRejected>());
      expect((r as RestoreRejected).kind, RestoreRejection.notAnExport);
      expect(await dir.list(), hasLength(1));
    });
  });
}
