// P01 T7b: restoring a file INTO the profile it came from (ADR-0025, owner
// decision 2026-11-07). Never a second profile for the same data.
//   compare    identical -> nothing to restore; counts of each kind of difference
//   overwrite  profile becomes the file; device-only rows become tombstones
//   merge      (a) newer by updatedAt then version; (b) add file-only rows
//   hierarchy  a merge that breaks the tree is refused, or fixed by keeping
//              this device's parents (owner chose: offer both)
//   undo       the pre-restore state is kept in the encrypted store
//   governance one command: audit + dedupe + event, one outbox row per record
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
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

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_restore_');
    keys = MemoryKeys();
    dir = await openDirectory(base, keys);
    host = TestHost(dir);
    await host.openActive();
    svc = Services(host, FakeAuthGateway());
    transfer = DriftDataTransferService(host.db, dir);
    profileId = host.currentId!;
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  final ser = driftRuntimeOptions.defaultSerializer;
  Object? later() => ser.toJson<DateTime>(DateTime.now().toUtc().add(const Duration(days: 1)));

  Future<Map<String, String>> seed() async {
    final ids = <String, String>{};
    Future<String> make(String title, {String? parent}) async =>
        ids[title] = (await svc.tasks.create(title, parentId: parent) as CommandOk).entityId;
    final a = await make('Learn English');
    await make('Chapter 1', parent: a);
    await make('Chapter 2', parent: a);
    await make('Pay rent');
    return ids;
  }

  Future<String> export() async => (await transfer.exportActiveProfile()).contents;

  /// Edits the payload of [text] and seals it again (a valid, newer-looking
  /// file, as another device would have produced).
  String craft(String text, void Function(List<Map<String, dynamic>> tasks) edit) {
    final env = (jsonDecode(text) as Map).cast<String, Object?>();
    final payload = (env['payload'] as Map).cast<String, Object?>();
    edit((payload['tasks'] as List).cast<Map<String, dynamic>>());
    return ProfileExport.seal(payload, schemaVersion: 3);
  }

  Map<String, dynamic> byTitle(List<Map<String, dynamic>> tasks, String t) =>
      tasks.firstWhere((r) => r['title'] == t);

  Map<String, dynamic> newRow(List<Map<String, dynamic>> tasks, String id, String title,
          {String? parent}) =>
      Map.of(tasks.first)
        ..['id'] = id
        ..['title'] = title
        ..['parentTaskId'] = parent
        ..['deletedAt'] = null
        ..['version'] = 1;

  Future<List<Task>> rows() => host.db.select(host.db.tasks).get();
  Future<Task> row(String title) async =>
      (await rows()).firstWhere((t) => t.title == title);
  Future<List<String>> visible() async => (await svc.titles())..sort();

  Future<List<String>> state() async =>
      [for (final t in await rows()) jsonEncode(t.toJson())]..sort();

  Future<List<int>> governanceCounts() async => [
        (await host.db.select(host.db.auditLog).get()).length,
        (await host.db.select(host.db.outbox).get()).length,
        (await host.db.select(host.db.eventLog).get()).length,
        (await host.db.select(host.db.opDedupe).get()).length,
      ];

  /// The usual "two devices drifted apart" situation:
  ///   device: + 'Device only'; 'Pay rent' renamed (device is newer)
  ///   file:   + 'File only';   'Chapter 2' renamed with a newer updatedAt
  Future<String> drifted() async {
    final ids = await seed();
    final exported = await export();
    await svc.tasks.create('Device only');
    await svc.tasks.rename(ids['Pay rent']!, 'Pay rent (device)');
    return craft(exported, (tasks) {
      tasks.add(newRow(tasks, 'file-only-1', 'File only'));
      byTitle(tasks, 'Chapter 2')
        ..['title'] = 'Chapter 2 (file)'
        ..['updatedAt'] = later();
    });
  }

  group('compare', () {
    test('an identical file: nothing to restore, nothing written', () async {
      await seed();
      final file = await export();
      expect(await transfer.inspect(file), isA<RestoreIdentical>());
      final before = await state();
      final gov = await governanceCounts();
      final r = await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect((r as RestoredInto).changedNothing, isTrue);
      expect(await state(), before);
      expect(await governanceCounts(), gov);
      expect(await transfer.canUndoRestore(), isFalse);
      expect(await dir.list(), hasLength(1));
    });

    test('only version/updatedAt differing is still identical', () async {
      await seed();
      final file = craft(await export(), (tasks) {
        byTitle(tasks, 'Pay rent')
          ..['version'] = 9
          ..['updatedAt'] = later();
      });
      expect(await transfer.inspect(file), isA<RestoreIdentical>());
    });

    test('a record deleted on one side and absent on the other is not a difference',
        () async {
      await seed();
      final file = craft(await export(), (tasks) {
        tasks.add(newRow(tasks, 'gone-1', 'Gone')..['deletedAt'] = later());
      });
      expect(await transfer.inspect(file), isA<RestoreIdentical>());
    });

    test('counts each kind of difference', () async {
      final file = await drifted();
      final p = await transfer.inspect(file);
      final d = (p as RestoreDifferent).diff;
      expect(d.onlyInFile, 1);
      expect(d.onlyOnDevice, 1);
      expect(d.differing, 2);
      expect(d.newerInFile, 1);
      expect(d.isIdentical, isFalse);
    });

    test('newer = later updatedAt; on a tie, the higher version', () async {
      final ids = await seed();
      final device = await row('Pay rent');
      Map<String, dynamic> f(int version, Object? updatedAt) => {
            ...device.toJson(),
            'title': 'x',
            'version': version,
            'updatedAt': updatedAt
          };
      final d = device.toJson();
      expect(RestorePlanner.fileIsNewer(f(1, later()), d), isTrue);
      expect(RestorePlanner.fileIsNewer(f(99, ser.toJson<DateTime>(DateTime.utc(2000))), d), isFalse);
      expect(RestorePlanner.fileIsNewer(f(device.version + 1, d['updatedAt']), d), isTrue);
      expect(RestorePlanner.fileIsNewer(f(device.version, d['updatedAt']), d), isFalse);
      expect(ids, isNotEmpty);
    });
  });

  group('overwrite', () {
    test('the profile becomes the file; device-only records are trashed, not deleted',
        () async {
      final file = await drifted();
      final r = await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect(r, isA<RestoredInto>(), reason: '$r');
      final into = r as RestoredInto;
      expect((into.added, into.updated, into.removed), (1, 2, 1));
      expect(into.undoAvailable, isTrue);

      expect(await visible(),
          ['Chapter 1', 'Chapter 2 (file)', 'File only', 'Learn English', 'Pay rent']);
      final gone = await row('Device only');
      expect(gone.deletedAt, isNotNull); // a tombstone for sync, not a hard delete
      expect(gone.version, greaterThan(1));
      // Versions only move forward (LF-INV-VER-001), even when the file wins.
      expect((await row('Pay rent')).version, greaterThan(2));
      // Still one profile; the restore went INTO it.
      expect(await dir.list(), hasLength(1));
      // The title index follows (upsert fires the update trigger).
      final ws = (await host.db.select(host.db.workspaces).getSingle()).id;
      expect(await host.db.searchTaskIds(ws, 'device'), isEmpty);
      expect(await host.db.searchTaskIds(ws, 'file'), hasLength(2));
    });

    test('is ONE audited command with an outbox row per changed record', () async {
      final file = await drifted();
      await transfer.restore(file, choice: const RestoreChoice.overwrite());
      final db = host.db;
      final audit = await (db.select(db.auditLog)
            ..where((a) => a.action.equals('RestoreProfile')))
          .get();
      expect(audit, hasLength(1));
      final op = audit.single.operationId;
      expect(audit.single.resourceId, profileId);
      final outbox = await (db.select(db.outbox)..where((o) => o.operationId.equals(op))).get();
      // 4 records + the command's own row.
      expect(outbox, hasLength(5));
      expect(outbox.where((o) => o.operationType == 'delete').map((o) => o.entityType), ['task']);
      expect(await (db.select(db.opDedupe)..where((d) => d.operationId.equals(op))).get(),
          hasLength(1));
      final events = await (db.select(db.eventLog)..where((e) => e.operationId.equals(op))).get();
      expect(events.single.eventType, 'ProfileRestored');
      expect(events.single.dispatched, isTrue);
    });

    test('restoring the same file again finds nothing to do', () async {
      final file = await drifted();
      await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect(await transfer.inspect(file), isA<RestoreIdentical>());
    });

    test('keeps the account binding of the profile (never taken from a file)',
        () async {
      await seed();
      final file = await export(); // exported as a guest
      final s = await svc.accounts.signIn(const OAuthSignIn('github'));
      if (s is NeedsBindChoice) await svc.accounts.completeBind(moveData: true);
      await svc.tasks.create('After sign-in');
      expect((await dir.active())!.isBound, isTrue);
      final r = await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect(r, isA<RestoredInto>(), reason: '$r');
      final p = await host.db.select(host.db.profiles).getSingle();
      expect(p.accountId, 'acc-123');
      expect(p.signedOut, isFalse);
      expect((await dir.active())!.accountId, 'acc-123');
    });
  });

  group('merge', () {
    test('(a) only: the newer file record wins; nothing added or removed',
        () async {
      final file = await drifted();
      final r = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: false));
      final into = r as RestoredInto;
      expect((into.added, into.updated, into.removed), (0, 1, 0));
      expect(await visible(), [
        'Chapter 1', 'Chapter 2 (file)', 'Device only', 'Learn English',
        'Pay rent (device)', // the device's version is newer: kept
      ]);
    });

    test('(b) only: adds what is only in the file; changes nothing else',
        () async {
      final file = await drifted();
      final into = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: false, addMissing: true)) as RestoredInto;
      expect((into.added, into.updated, into.removed), (1, 0, 0));
      expect(await visible(), [
        'Chapter 1', 'Chapter 2', 'Device only', 'File only', 'Learn English',
        'Pay rent (device)',
      ]);
      // An added record keeps its id (LF-INV-ID-001).
      expect((await row('File only')).id, 'file-only-1');
    });

    test('(a) + (b)', () async {
      final file = await drifted();
      final into = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: true)) as RestoredInto;
      expect((into.added, into.updated, into.removed), (1, 1, 0));
      expect(await visible(), [
        'Chapter 1', 'Chapter 2 (file)', 'Device only', 'File only',
        'Learn English', 'Pay rent (device)',
      ]);
    });
  });

  group('hierarchy (owner chose: refuse, or keep this device\'s parents)', () {
    test('a merge that would make a cycle is refused and writes nothing; '
        'keeping device parents applies the rest', () async {
      final ids = await seed();
      // File: 'Learn English' moved under 'Chapter 1' (newer). Device still has
      // 'Chapter 1' under 'Learn English' -> merged, that is a cycle.
      final file = craft(await export(), (tasks) {
        byTitle(tasks, 'Chapter 1')['parentTaskId'] = null;
        byTitle(tasks, 'Learn English')
          ..['parentTaskId'] = ids['Chapter 1']
          ..['title'] = 'Learn English (file)'
          ..['updatedAt'] = later();
      });
      final before = await state();
      const choice = RestoreChoice.merge(takeNewer: true, addMissing: false);
      final r = await transfer.restore(file, choice: choice);
      expect(r, isA<RestoreHierarchyConflict>(), reason: '$r');
      expect((r as RestoreHierarchyConflict).taskTitles, ['Learn English (file)']);
      expect(await state(), before);
      expect(await transfer.canUndoRestore(), isFalse);

      final fixed = await transfer.restore(file, choice: choice.withDeviceParents());
      expect(fixed, isA<RestoredInto>(), reason: '$fixed');
      final root = await row('Learn English (file)'); // title from the file
      expect(root.parentTaskId, isNull); // parent from this device
      expect((await row('Chapter 1')).parentTaskId, ids['Learn English']);
    });

    test('a newer record pointing to a parent that is only in the file', () async {
      final ids = await seed();
      final file = craft(await export(), (tasks) {
        tasks.add(newRow(tasks, 'z-1', 'Z (file only)'));
        byTitle(tasks, 'Chapter 2')
          ..['parentTaskId'] = 'z-1'
          ..['title'] = 'Chapter 2 (file)'
          ..['updatedAt'] = later();
      });
      // (a) without (b): the parent would be missing.
      const a = RestoreChoice.merge(takeNewer: true, addMissing: false);
      final r = await transfer.restore(file, choice: a);
      expect((r as RestoreHierarchyConflict).taskTitles, ['Chapter 2 (file)']);
      await transfer.restore(file, choice: a.withDeviceParents());
      expect((await row('Chapter 2 (file)')).parentTaskId, ids['Learn English']);
    });

    test('with (b) the same file is consistent: no conflict', () async {
      await seed();
      final file = craft(await export(), (tasks) {
        tasks.add(newRow(tasks, 'z-1', 'Z (file only)'));
        byTitle(tasks, 'Chapter 2')
          ..['parentTaskId'] = 'z-1'
          ..['updatedAt'] = later();
      });
      final r = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: true));
      expect(r, isA<RestoredInto>(), reason: '$r');
      expect((await row('Chapter 2')).parentTaskId, 'z-1');
    });

    test('a merge that goes deeper than allowed is a conflict', () async {
      final ids = await seed();
      // Device: Learn English > Chapter 1. File: Chapter 1 at the top (older,
      // so not taken), Pay rent under it (newer), and D4 > D5 below. In the
      // file D5 is at depth 4; merged it would be at depth 5 (> max 4).
      final file = craft(await export(), (tasks) {
        byTitle(tasks, 'Chapter 1')['parentTaskId'] = null;
        byTitle(tasks, 'Pay rent')
          ..['parentTaskId'] = ids['Chapter 1']
          ..['updatedAt'] = later();
        tasks.add(newRow(tasks, 'd4', 'D4', parent: ids['Pay rent']));
        tasks.add(newRow(tasks, 'd5', 'D5', parent: 'd4'));
      });
      const choice = RestoreChoice.merge(takeNewer: true, addMissing: true);
      final r = await transfer.restore(file, choice: choice);
      expect((r as RestoreHierarchyConflict).taskTitles, ['D5']);
      // Keeping device parents: D5 is new from the file -> top-level.
      final fixed = await transfer.restore(file, choice: choice.withDeviceParents());
      expect(fixed, isA<RestoredInto>(), reason: '$fixed');
      expect((await row('D5')).parentTaskId, isNull);
      expect((await row('D4')).parentTaskId, ids['Pay rent']);
    });

    test('data as deep in the file as on the device stays valid (GS-18)',
        () async {
      final ids = await seed();
      // In the file itself D5 is at depth 5 (older data may be deeper than
      // the current limit); a merge that keeps that depth is accepted.
      final file = craft(await export(), (tasks) {
        byTitle(tasks, 'Pay rent')
          ..['parentTaskId'] = ids['Chapter 1']
          ..['updatedAt'] = later();
        tasks.add(newRow(tasks, 'd4', 'D4', parent: ids['Pay rent']));
        tasks.add(newRow(tasks, 'd5', 'D5', parent: 'd4'));
      });
      final ok = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: true));
      expect(ok, isA<RestoredInto>(), reason: '$ok');
    });
  });

  group('undo', () {
    test('brings back the state before the restore', () async {
      final file = await drifted();
      final before = await visible();
      await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect(await transfer.canUndoRestore(), isTrue);

      final r = await transfer.undoLastRestore();
      expect(r, isA<RestoredInto>(), reason: '$r');
      expect((r as RestoredInto).undoAvailable, isFalse);
      expect(await visible(), before);
      // What the restore added is now a tombstone, not hard-deleted.
      expect((await row('File only')).deletedAt, isNotNull);
      expect(await transfer.canUndoRestore(), isFalse);
      expect(await transfer.undoLastRestore(), isA<RestoreRejected>());
      final undoAudit = await (host.db.select(host.db.auditLog)
            ..where((a) => a.action.equals('UndoRestoreProfile')))
          .get();
      expect(undoAudit, hasLength(1));
    });

    test('only the latest restore is kept for undo', () async {
      final file = await drifted();
      await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: false, addMissing: true));
      await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect(await host.db.select(host.db.restoreSnapshots).get(), hasLength(1));
      await transfer.undoLastRestore();
      // Back to the state after the first restore.
      expect(await visible(), [
        'Chapter 1', 'Chapter 2', 'Device only', 'File only', 'Learn English',
        'Pay rent (device)',
      ]);
    });

    test('the undo copy stays inside the encrypted store and is never exported',
        () async {
      final file = await drifted();
      await transfer.restore(file, choice: const RestoreChoice.overwrite());
      final names = Directory('${base.path}${Platform.pathSeparator}profiles')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(names.every((n) => n.startsWith('$profileId.sqlite')), isTrue,
          reason: '$names');
      expect(isPlainSqliteFile(dir.profileFile(profileId)), isFalse);
      final exported = (jsonDecode(await export()) as Map)['payload'] as Map;
      expect(exported.keys, unorderedEquals(exportedTables));
    });
  });

  group('the same account on another device (T7c, owner report)', () {
    /// A second install (own folder, own keys) signed in with the SAME
    /// account. Until sync, it has its own profile and workspace ids.
    Future<({TestHost host, Services svc, DriftDataTransferService transfer})>
        otherDevice() async {
      final b = Directory.systemTemp.createTempSync('lifeflow_device2_');
      final d = await openDirectory(b, MemoryKeys());
      final h = TestHost(d);
      await h.openActive();
      addTearDown(() async {
        await h.close();
        await d.close();
        if (b.existsSync()) b.deleteSync(recursive: true);
      });
      final s = Services(h, FakeAuthGateway());
      final r = await s.accounts.signIn(const OAuthSignIn('github'));
      if (r is NeedsBindChoice) await s.accounts.completeBind(moveData: true);
      return (host: h, svc: s, transfer: DriftDataTransferService(h.db, d));
    }

    Future<void> signInHere() async {
      final r = await svc.accounts.signIn(const OAuthSignIn('github'));
      if (r is NeedsBindChoice) await svc.accounts.completeBind(moveData: true);
    }

    test('a file from the other device goes INTO this account\'s profile',
        () async {
      await signInHere();
      await svc.tasks.create('Windows task');
      final other = await otherDevice();
      await other.svc.tasks.create('Android task');
      final fileFromOther = (await other.transfer.exportActiveProfile()).contents;
      expect(other.host.currentId, isNot(profileId)); // different ids per device

      final p = await transfer.inspect(fileFromOther);
      expect(p, isA<RestoreDifferent>(), reason: '$p');
      final d = (p as RestoreDifferent).diff;
      expect((d.onlyInFile, d.onlyOnDevice), (1, 1));

      final r = await transfer.restore(fileFromOther,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: true));
      expect(r, isA<RestoredInto>(), reason: '$r');
      // In THIS profile, under its own workspace; no new profile.
      expect(await visible(), ['Android task', 'Windows task']);
      expect(await dir.list(), hasLength(1));
      final ws = (await host.db.select(host.db.workspaces).get());
      expect(ws, hasLength(1));
      final added = await row('Android task');
      expect(added.workspaceId, ws.single.id);
      expect(added.ownerId, profileId);
      // Comparing the same file again: nothing in it is missing or different
      // here any more; only this device's own task remains extra.
      final again = (await transfer.inspect(fileFromOther) as RestoreDifferent).diff;
      expect((again.onlyInFile, again.differing, again.onlyOnDevice), (0, 0, 1));
    });

    test('while a guest is open, it points to the account\'s profile', () async {
      await signInHere();
      final other = await otherDevice();
      await other.svc.tasks.create('Android task');
      final fileFromOther = (await other.transfer.exportActiveProfile()).contents;
      final accountProfile = host.currentId!;
      final guest = await dir.createProfile(displayName: 'Kid');
      await dir.setActive(guest.id);
      await host.activate(guest.id);
      final guestTransfer = DriftDataTransferService(host.db, dir);

      final p = await guestTransfer.inspect(fileFromOther);
      expect(p, isA<RestoreOtherProfile>(), reason: '$p');
      expect((await guestTransfer.restore(fileFromOther,
              choice: const RestoreChoice.overwrite())) as RestoreRejected,
          isA<RestoreRejected>());
      expect(await host.db.select(host.db.tasks).get(), isEmpty);
      expect(accountProfile, isNot(guest.id));
    });

    test('a different account is never merged in', () async {
      await signInHere();
      final b = Directory.systemTemp.createTempSync('lifeflow_device3_');
      final d = await openDirectory(b, MemoryKeys());
      final h = TestHost(d);
      await h.openActive();
      addTearDown(() async {
        await h.close();
        await d.close();
        b.deleteSync(recursive: true);
      });
      final s = Services(h, FakeAuthGateway(accountId: 'acc-other'));
      await s.accounts.signIn(const OAuthSignIn('github'));
      await s.tasks.create('Someone else');
      final file = (await DriftDataTransferService(h.db, d).exportActiveProfile()).contents;
      expect(await transfer.inspect(file), isA<RestoreAsNewProfile>());
    });
  });

  group('a file of another profile on this device', () {
    test('says to open that profile, and changes nothing', () async {
      await seed();
      final fileOfA = await export();
      final b = await dir.createProfile(displayName: 'Work');
      await dir.setActive(b.id);
      await host.activate(b.id);
      final transferB = DriftDataTransferService(host.db, dir);

      final p = await transferB.inspect(fileOfA);
      expect(p, isA<RestoreOtherProfile>());
      expect((p as RestoreOtherProfile).locked, isFalse);
      final r = await transferB.restore(fileOfA, choice: const RestoreChoice.overwrite());
      expect((r as RestoreRejected).kind, RestoreRejection.notApplicable);
      expect(await host.db.select(host.db.tasks).get(), isEmpty);
      expect(await dir.list(), hasLength(2));
    });
  });
}
