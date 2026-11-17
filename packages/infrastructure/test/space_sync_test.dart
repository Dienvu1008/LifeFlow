// P04b T11 (ADR-0063): two (or three) people sync one shared space through
// the in-memory server, each on their own store, keys and account.
//   two people   GS-17 (offline changes on both arrive), SYNC-003 (fields
//                merged per type), GS-14 (delete and purge reach everyone);
//                "changed by" says who
//   viewer       pulls; never pushes (the device sends nothing, and the
//                server refuses it) (SHARE-002)
//   not taken    a member's device cannot put a personal kind (B2) into the
//                space, nor overwrite another workspace's record by its id
//   rotation     after a removal the owner's device seals everything again
//                with the new key and drops the old rows; an editor offline
//                meanwhile catches up and pushes its change; the removed
//                member's device stops syncing the space
//   status       on while a space is shown; the personal sync is untouched
import 'package:application/application.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'profile_harness.dart' show MemoryKeys;

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

/// One person's device: their store, signed in to their account.
class Person {
  Person._(this.account, this.server, this.db) : gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)) {
    remote = MemoryRemoteGateway(server, accountId: account);
    keyring = WorkspaceKeyring(slots.call);
    keys = SpaceKeyService(server: remote, keyring: keyring, slots: slots.call);
    sync = DriftSpaceSyncService(db: db, gateway: gw, remote: remote, spaces: remote, keyring: keyring, keys: keys);
    tasks = DriftTaskService(db, gw);
    spaces = DriftSpaceService(db, gw);
  }
  final String account;
  final MemoryRemoteServer server;
  final AppDatabase db;
  final DriftCommandGateway gw;
  final slots = MemoryKeys();
  late final MemoryRemoteGateway remote;
  late final WorkspaceKeyring keyring;
  late final SpaceKeyService keys;
  late final DriftSpaceSyncService sync;
  late final DriftTaskService tasks;
  late final DriftSpaceService spaces;
  late String personal;

  static Future<Person> open(String account, MemoryRemoteServer server, {SecretKey? personalKey, bool publish = true}) async {
    final p = Person._(account, server, AppDatabase(NativeDatabase.memory()));
    final profile = await ProfileStore(p.db).ensureFirstProfile();
    p.personal = profile.activeWorkspaceId.value;
    await (p.db.update(p.db.profiles)..where((x) => x.id.equals(profile.profileId.value)))
        .write(ProfilesCompanion(accountId: Value(account), accountProvider: const Value('github')));
    // The account's key pair, as turning sync on makes it (B5).
    if (publish) await p.keys.ensureAccountKeys(account, personalKey ?? await newWorkspaceKey());
    return p;
  }

  Future<SyncReport> syncNow() => sync.syncNow();
  Future<Map<String, dynamic>?> task(String id) => recordKindByName['task']!.readOne(db, id);
  Future<void> show(String ws) async => ok(await spaces.show(ws));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MemoryRemoteServer server;
  late String ws;
  final people = <Person>[];

  setUp(() {
    server = MemoryRemoteServer();
    ws = const Uuid().v4();
  });
  tearDown(() async {
    for (final p in people) {
      await p.db.close();
    }
    people.clear();
  });

  Future<Person> person(String account) async {
    final p = await Person.open(account, server);
    people.add(p);
    return p;
  }

  /// The owner makes the space; the others join by "approve" invitations;
  /// everyone's device learns of it and shows it.
  Future<List<Person>> space(List<(String, SpaceRole)> who) async {
    final owner = await person(who.first.$1);
    await owner.keys.createSpace(owner.account, ws);
    final out = [owner];
    for (final (account, role) in who.skip(1)) {
      final p = await person(account);
      final inv = await owner.keys.invite(ws, role, InviteKind.approve);
      await p.keys.accept(account, inv.code);
      await owner.keys.approve(ws, account);
      out.add(p);
    }
    for (final p in out) {
      expect(await p.sync.refresh(), isNull);
      await p.show(ws);
    }
    return out;
  }

  Future<void> syncAll(List<Person> ps) async {
    for (var i = 0; i < 2; i++) {
      for (final p in ps) {
        final r = await p.syncNow();
        expect(r.outcome, SyncOutcome.upToDate, reason: '${p.account}: $r');
      }
    }
  }

  test('two people: changes made offline on both arrive, fields merge, and "changed by" says who (GS-17, SYNC-003)',
      () async {
    final [lan, minh] = await space([('lan', SpaceRole.owner), ('minh', SpaceRole.editor)]);
    final a = ok(await lan.tasks.create('Plan the trip'));
    await syncAll([lan, minh]);
    expect((await minh.task(a))!['title'], 'Plan the trip');
    expect((await minh.task(a))!['changedBy'], 'lan');

    // Both offline: Lan renames, Minh writes notes and adds a task.
    ok(await lan.tasks.rename(a, 'Plan the trip to Hue'));
    ok(await minh.tasks.setNotes(a, 'Train or bus?'));
    final b = ok(await minh.tasks.create('Book the hotel'));
    await syncAll([lan, minh]);
    for (final p in [lan, minh]) {
      final row = (await p.task(a))!;
      expect((row['title'], row['notes']), ('Plan the trip to Hue', 'Train or bus?'), reason: p.account);
      expect((await p.task(b))!['title'], 'Book the hotel');
    }
    expect((await lan.task(b))!['changedBy'], 'minh');
    expect((await lan.task(b))!['workspaceId'], ws);
  });

  test('a delete reaches everyone; after the retention the purge does too (GS-14)', () async {
    final [lan, minh] = await space([('lan', SpaceRole.owner), ('minh', SpaceRole.editor)]);
    final t = ok(await lan.tasks.create('Temporary'));
    await syncAll([lan, minh]);
    ok(await minh.tasks.trash(t));
    await syncAll([lan, minh]);
    expect((await lan.task(t))!['deletedAt'], isNotNull);

    final sid = await (await RecordSealer.of((await lan.keyring.keyOf(ws))!)).serverId('task', t);
    server.age(ws, sid, const Duration(days: 100));
    await syncAll([lan, minh]);
    expect(await lan.task(t), isNull);
    expect(await minh.task(t), isNull);
  });

  test('a viewer pulls and never pushes; the server refuses a viewer\'s push too (SHARE-002)', () async {
    final [lan, vy] = await space([('lan', SpaceRole.owner), ('vy', SpaceRole.viewer)]);
    final t = ok(await lan.tasks.create('Read only for Vy'));
    await syncAll([lan, vy]);
    expect((await vy.task(t))!['title'], 'Read only for Vy');
    final r = await vy.tasks.rename(t, 'Changed by a viewer');
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);

    // A change waiting on the viewer's device (made while Vy was an editor,
    // or crafted): it is not sent.
    await vy.db.customStatement("UPDATE tasks SET title = 'Sneaky', version = version + 1 WHERE id = ?", [t]);
    await vy.db.into(vy.db.outbox).insert(OutboxCompanion.insert(
        operationId: const Uuid().v7(), entityId: t, entityType: 'task', workspaceId: ws,
        actorId: 'member:vy', operationType: 'update', payload: '{}', createdAt: DateTime.now().toUtc()));
    final report = await vy.syncNow();
    expect((report.outcome, report.pushed), (SyncOutcome.upToDate, 0));
    await lan.syncNow();
    expect((await lan.task(t))!['title'], 'Read only for Vy');

    final key = await RecordSealer.of((await vy.keyring.keyOf(ws))!);
    final sid = await key.serverId('task', 'crafted');
    await expectLater(
        vy.remote.push(ws, 'vy', [
          RecordPush(id: sid, base: null, version: 1, deleted: false, sealed: await key.seal(sid, 1, {}), operationId: 'op')
        ], keyId: key.keyId),
        throwsA(isA<RemoteFailure>().having((e) => e.kind, 'kind', RemoteFailureKind.notYours)));
  });

  test('a member cannot put a personal kind into the space, nor overwrite another workspace\'s record (B2)', () async {
    final [lan, minh] = await space([('lan', SpaceRole.owner), ('minh', SpaceRole.editor)]);
    // Lan's own personal task, whose id Minh happens to know.
    await lan.show(lan.personal);
    final mine = ok(await lan.tasks.create('Lan\'s private task'));
    await lan.show(ws);

    final sealer = await RecordSealer.of((await minh.keyring.keyOf(ws))!);
    Future<RecordPush> crafted(String kind, String id, Map<String, Object?> row) async {
      final sid = await sealer.serverId(kind, id);
      return RecordPush(
          id: sid,
          base: null,
          version: 9,
          deleted: false,
          sealed: await sealer.seal(sid, 9, {'kind': kind, 'id': id, 'schemaVersion': AppDatabase.recordSchemaVersion, 'row': row}),
          operationId: const Uuid().v4());
    }

    final hijack = {...(await lan.task(mine))!, 'workspaceId': ws, 'title': 'Taken over', 'version': 9};
    await minh.remote.push(ws, 'minh', [
      await crafted('task', mine, hijack),
      await crafted('reminder', 'r1', {'id': 'r1', 'workspaceId': ws}),
    ], keyId: sealer.keyId);
    final r = await lan.syncNow();
    expect((r.outcome, r.notTaken), (SyncOutcome.upToDate, 2), reason: '$r');
    final row = (await lan.task(mine))!;
    expect((row['title'], row['workspaceId']), ('Lan\'s private task', lan.personal));
    expect(await recordKindByName['reminder']!.readOne(lan.db, 'r1'), isNull);
  });

  test('rotation: the owner seals everything again; an editor offline meanwhile catches up; the removed member stops',
      () async {
    final [lan, minh, vy] =
        await space([('lan', SpaceRole.owner), ('minh', SpaceRole.editor), ('vy', SpaceRole.editor)]);
    final t = ok(await lan.tasks.create('Shared plan'));
    final gone = ok(await lan.tasks.create('Done and deleted'));
    await syncAll([lan, minh, vy]);
    ok(await lan.tasks.trash(gone));
    await syncAll([lan, minh, vy]);
    final oldKeyId = (await RecordSealer.of((await lan.keyring.keyOf(ws))!)).keyId;

    // Minh edits while offline; Vy is removed and the key rotated.
    ok(await minh.tasks.rename(t, 'Shared plan, by Minh'));
    await lan.remote.removeMember(ws, 'vy');
    final newKeyId = await lan.keys.rotate(ws);

    final r = await lan.syncNow();
    expect(r.outcome, SyncOutcome.upToDate, reason: '$r');
    expect(await lan.keyring.previousKeyOf(ws), isNull, reason: 'the rotation is finished');
    expect({for (final s in server.dump(ws)) s.id}.length, server.dump(ws).length);
    final onServer = await lan.remote.pull(ws, 0);
    expect({for (final s in onServer) s.keyId}, {newKeyId}, reason: 'only the new key\'s rows are left');
    expect(onServer.where((s) => s.deleted), isNotEmpty, reason: 'the delete is sealed again too');

    final m = await minh.syncNow();
    expect(m.outcome, SyncOutcome.upToDate, reason: '$m');
    expect((await RecordSealer.of((await minh.keyring.keyOf(ws))!)).keyId, newKeyId);
    await lan.syncNow();
    expect((await lan.task(t))!['title'], 'Shared plan, by Minh');
    expect((await minh.task(gone))!['deletedAt'], isNotNull);
    expect(oldKeyId, isNot(newKeyId));
    // GS-14 after a rotation: the purge of the sealed-again tombstone still
    // reaches Minh (who knew the record under its old server id).
    final newSid = await (await RecordSealer.of((await lan.keyring.keyOf(ws))!)).serverId('task', gone);
    server.age(ws, newSid, const Duration(days: 100));
    await lan.syncNow();
    await minh.syncNow();
    expect(await minh.task(gone), isNull);

    // Vy's device: the space is no longer Vy's; it stops syncing there, and
    // under the default leaving rule (B8 (a)) its data and key go.
    final vyKey = (await vy.keyring.keyOf(ws))!;
    expect(await vy.sync.refresh(), isNull);
    expect((await vy.syncNow()).pushed, 0);
    expect(await vy.db.select(vy.db.syncState).get(), isEmpty);
    expect([for (final s in await vy.spaces.spaces()) s.shared], [false], reason: 'no longer listed');
    expect(await vy.task(t), isNull);
    expect(await vy.keyring.keyOf(ws), isNull);
    final after = onServer.firstWhere((s) => !s.deleted);
    await expectLater((await RecordSealer.of(vyKey)).open(after.id, after.version, after.sealed!), throwsA(isA<SealBroken>()),
        reason: 'the key Vy had opens nothing sealed after the removal (SHARE-004)');
  });

  test('a rotation not finished yet: old-key rows open with the previous key, or are skipped by a newcomer', () async {
    final [lan, minh, vy] =
        await space([('lan', SpaceRole.owner), ('minh', SpaceRole.editor), ('vy', SpaceRole.editor)]);
    final t = ok(await lan.tasks.create('Groceries'));
    await syncAll([lan, minh, vy]);
    // Vy changes it and syncs; Minh has not pulled it yet.
    ok(await vy.tasks.setNotes(t, 'Milk, eggs'));
    expect((await vy.syncNow()).outcome, SyncOutcome.upToDate);
    // Vy is removed and the key rotated; Lan's device is offline before it
    // seals everything again.
    await lan.remote.removeMember(ws, 'vy');
    await lan.keys.rotate(ws);

    final m = await minh.syncNow();
    expect(m.outcome, SyncOutcome.upToDate, reason: '$m');
    expect((await minh.task(t))!['notes'], 'Milk, eggs', reason: 'opened with the previous key');
    expect(await minh.db.select(minh.db.syncReviews).get(), isEmpty, reason: 'nothing unreadable');

    // A newcomer joins now: the old rows are not theirs to open; skipped.
    final an = await person('an');
    final inv = await lan.keys.invite(ws, SpaceRole.editor, InviteKind.approve);
    await an.keys.accept('an', inv.code);
    await lan.keys.approve(ws, 'an');
    expect(await an.sync.refresh(), isNull);
    await an.show(ws);
    final first = await an.syncNow();
    expect(first.outcome, SyncOutcome.upToDate, reason: '$first');
    expect(await an.task(t), isNull, reason: 'nothing of the old key yet');
    // Lan's device comes back: everything sealed again; the newcomer gets it.
    expect((await lan.syncNow()).outcome, SyncOutcome.upToDate);
    await an.syncNow();
    expect((await an.task(t))!['notes'], 'Milk, eggs');
  });

  test('a rotation during a sync: the pull stops before the new key\'s rows and an old-key push is not set aside', () async {
    final [lan, minh] = await space([('lan', SpaceRole.owner), ('minh', SpaceRole.editor)]);
    final t = ok(await lan.tasks.create('Before'));
    await syncAll([lan, minh]);
    final oldKey = (await minh.keyring.keyOf(ws))!;
    ok(await minh.tasks.rename(t, 'Minh\'s change'));
    await lan.keys.rotate(ws);
    final after = ok(await lan.tasks.create('After the rotation'));
    expect((await lan.syncNow()).outcome, SyncOutcome.upToDate);

    // Minh's engine still holds the old key, and its check has passed.
    final state = (await (minh.db.select(minh.db.syncState)..where((s) => s.workspaceId.equals(ws))).getSingle());
    final engine = SyncEngine(
      db: minh.db,
      gateway: minh.gw,
      remote: minh.remote,
      sealer: await RecordSealer.of(oldKey),
      workspaceId: ws,
      deviceId: state.deviceId,
      space: SpaceSyncMode(check: () async => null, currentKeyId: () async => 'f' * 64),
    );
    final r = await engine.sync();
    expect(r.outcome, SyncOutcome.keyChanged);
    expect(r.failedRecords, 0);
    final pending = await (minh.db.select(minh.db.outbox)
          ..where((o) => o.entityId.equals(t) & o.status.equals('pending')))
        .get();
    expect(pending, isNotEmpty, reason: 'the change waits for the new key');
    expect(await minh.task(after), isNull, reason: 'the new key\'s rows wait too');
    final cursor = (await (minh.db.select(minh.db.syncState)..where((s) => s.workspaceId.equals(ws))).getSingle()).cursor;

    // The service fetches the new key and goes on from there.
    final again = await minh.syncNow();
    expect(again.outcome, SyncOutcome.upToDate, reason: '$again');
    expect((await minh.task(after))!['title'], 'After the rotation');
    expect(cursor, lessThan((await (minh.db.select(minh.db.syncState)..where((s) => s.workspaceId.equals(ws))).getSingle()).cursor));
    await lan.syncNow();
    expect((await lan.task(t))!['title'], 'Minh\'s change');
  });

  test('a personal kind made in a space is not sent; a pulled row of another workspace is not taken', () async {
    final [lan, minh] = await space([('lan', SpaceRole.owner), ('minh', SpaceRole.editor)]);
    final t = ok(await lan.tasks.create('Shared'));
    // A reminder row in the space and its outbox row (as a bug elsewhere
    // might leave them): withheld.
    final now = DateTime.now().toUtc();
    await lan.db.into(lan.db.reminders).insert(RemindersCompanion.insert(
          id: 'r-space', workspaceId: ws, ownerId: 'lan', createdAt: now, updatedAt: now,
          subjectType: 'task', subjectId: t, offsetMinutes: const Value(10)));
    await lan.db.into(lan.db.outbox).insert(OutboxCompanion.insert(
        operationId: const Uuid().v7(), entityId: 'r-space', entityType: 'reminder', workspaceId: ws,
        actorId: 'member:lan', operationType: 'create', payload: '{}', createdAt: now));
    final r = await lan.syncNow();
    expect(r.withheld, 1, reason: '$r');
    final sealer = await RecordSealer.of((await lan.keyring.keyOf(ws))!);
    expect(server.dump(ws).map((s) => s.id), isNot(contains(await sealer.serverId('reminder', 'r-space'))));

    // A row that says it is of Minh's personal workspace.
    final sid = await sealer.serverId('task', 'elsewhere');
    final row = {...(await lan.task(t))!, 'id': 'elsewhere', 'workspaceId': minh.personal, 'version': 1};
    await lan.remote.push(ws, 'lan', [
      RecordPush(id: sid, base: null, version: 1, deleted: false,
          sealed: await sealer.seal(sid, 1, {'kind': 'task', 'id': 'elsewhere', 'schemaVersion': AppDatabase.recordSchemaVersion, 'row': row}),
          operationId: const Uuid().v4())
    ], keyId: sealer.keyId);
    final m = await minh.syncNow();
    expect((m.outcome, m.notTaken), (SyncOutcome.upToDate, 1), reason: '$m');
    expect(await minh.task('elsewhere'), isNull);
  });

  test('the space\'s sync is on while a space is shown; personal sync state is never touched', () async {
    final [lan] = await space([('lan', SpaceRole.owner)]);
    expect((await lan.sync.status()).on, isTrue);
    await lan.show(lan.personal);
    // P04b T13: still on (the spaces are refreshed); nothing is synced.
    expect((await lan.sync.status()).on, isTrue);
    expect((await lan.syncNow()).outcome, SyncOutcome.upToDate);
    await lan.show(ws);
    final states = await lan.db.select(lan.db.syncState).get();
    expect([for (final s in states) s.workspaceId], [ws]);
  });

  test('without the account\'s keys (personal sync off, B5) nothing is refreshed', () async {
    final lan = await person('lan');
    final fresh = Person._('lan-2', server, AppDatabase(NativeDatabase.memory()));
    people.add(fresh);
    final p = await ProfileStore(fresh.db).ensureFirstProfile();
    await (fresh.db.update(fresh.db.profiles)..where((x) => x.id.equals(p.profileId.value)))
        .write(const ProfilesCompanion(accountId: Value('lan-2'), accountProvider: Value('github')));
    expect(await fresh.sync.refresh(), SyncOutcome.notOn);
    expect(await lan.sync.refresh(), isNull);
  });

  test('the space sync\'s scheduler: every minute (B12); with Personal shown it only refreshes; not for a guest', () async {
    final [lan] = await space([('lan', SpaceRole.owner)]);
    final scheduler = SyncScheduler(service: lan.sync, when: () async => SyncWhen.automatic, every: spaceSyncEvery);
    expect(spaceSyncEvery, const Duration(minutes: 1));
    expect((await scheduler.run())?.pushed, greaterThanOrEqualTo(0));
    final t = ok(await lan.tasks.create('Not sent while Personal is shown'));
    await lan.show(lan.personal);
    expect((await scheduler.run())?.pushed, 0);
    expect(server.dump(ws).length, lessThan(3), reason: '$t waits until the space is shown');
    await (lan.db.update(lan.db.profiles)).write(const ProfilesCompanion(signedOut: Value(true)));
    expect(await scheduler.run(), isNull, reason: 'signed out: off');
    await scheduler.stop();
  });

  test('a second device of the account opens the account\'s keys with the personal workspace key (B5)', () async {
    final personalKey = await newWorkspaceKey();
    final pc = await Person.open('lan', server, personalKey: personalKey);
    people.add(pc);
    final published = (await pc.remote.myKeys())!.publicKey;
    final phone = await Person.open('lan', server, publish: false);
    people.add(phone);
    // Personal sync is on on the phone: its state and the personal key.
    const accountWorkspace = '40000000-0000-4000-8000-000000000001';
    await phone.db.into(phone.db.syncState).insert(SyncStateCompanion.insert(workspaceId: accountWorkspace, deviceId: 'phone'));
    await phone.keyring.keepKey(accountWorkspace, personalKey);
    expect(await phone.keys.accountKeyPair('lan'), isNull);
    expect(await phone.sync.refresh(), isNull);
    expect((await phone.keys.accountKeyPair('lan'))!.publicKey, published);
  });
}
