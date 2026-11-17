// P04b T11 (ADR-0063): people sharing a space on the real stack: their own
// encrypted stores, the real HttpRemoteGateway, a local Supabase with the
// project's migrations, one account each, personal sync turned on first
// (B5: the account's key pair is opened with the personal key).
//   share    "join at once" and "approve"; an edit reaches the others; a
//            viewer reads and pushes nothing
//   rotate   a member removed, the key rotated; the owner's device seals
//            everything again; the others catch up; the removed member stops
// Runs only with LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY
// (CI job supabase-db).
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'profile_harness.dart' show MemoryKeys;

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

class Person {
  Person(this.db, this.account, this.remote) : gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)) {
    keyring = WorkspaceKeyring(slots.call);
    keys = SpaceKeyService(server: remote, keyring: keyring, slots: slots.call);
    personalSync = DriftSyncService(db: db, gateway: gw, remote: remote, keyring: keyring);
    spaceSync = DriftSpaceSyncService(db: db, gateway: gw, remote: remote, spaces: remote, keyring: keyring, keys: keys);
    tasks = DriftTaskService(db, gw);
    spaces = DriftSpaceService(db, gw);
  }
  final AppDatabase db;
  final String account;
  final HttpRemoteGateway remote;
  final DriftCommandGateway gw;
  final slots = MemoryKeys();
  late final WorkspaceKeyring keyring;
  late final SpaceKeyService keys;
  late final DriftSyncService personalSync;
  late final DriftSpaceSyncService spaceSync;
  late final DriftTaskService tasks;
  late final DriftSpaceService spaces;

  Future<Map<String, dynamic>?> task(String id) => recordKindByName['task']!.readOne(db, id);
  Future<SyncReport> now() async {
    final r = await spaceSync.syncNow();
    expect(r.outcome, SyncOutcome.upToDate, reason: '$account: $r');
    return r;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final url = Platform.environment['LIFEFLOW_TEST_SUPABASE_URL'];
  final anon = Platform.environment['LIFEFLOW_TEST_SUPABASE_ANON_KEY'];
  if (url == null || anon == null) {
    test('a shared space on local Supabase', () {}, skip: 'set LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY');
    return;
  }
  final client = http.Client();
  tearDownAll(client.close);
  late Directory dir;
  final open = <AppDatabase>[];

  setUp(() => dir = Directory.systemTemp.createTempSync('lifeflow_space_e2e_'));
  tearDown(() async {
    for (final db in open) {
      await db.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  /// A new account with personal sync on, on its own device.
  Future<Person> person(String name) async {
    final res = await client.post(Uri.parse('$url/auth/v1/signup'),
        headers: {'apikey': anon, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': 'space-e2e-${const Uuid().v4()}@example.test', 'password': 'correct horse battery staple'}));
    if (res.statusCode != 200) throw StateError('sign-up failed: ${res.statusCode}');
    final body = jsonDecode(res.body) as Map;
    final token = body['access_token'] as String;
    final account = (body['user'] as Map)['id'] as String;
    final db = AppDatabase(NativeDatabase(File('${dir.path}/$name.db')));
    open.add(db);
    final p = await ProfileStore(db).ensureFirstProfile();
    await (db.update(db.profiles)..where((x) => x.id.equals(p.profileId.value)))
        .write(ProfilesCompanion(accountId: Value(account), accountProvider: const Value('github')));
    final person = Person(db, account,
        HttpRemoteGateway(baseUrl: url, anonKey: anon, accessToken: () async => token, client: client));
    final offer = await person.personalSync.offerRecoveryKey();
    final (p1, p2) = offer.check;
    expect((await person.personalSync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1]))).problem, isNull);
    expect(await person.spaceSync.refresh(), isNull, reason: 'the account\'s keys are made with the personal key');
    return person;
  }

  test('share: "join at once" and "approve"; edits reach the others; a viewer pushes nothing', () async {
    final lan = await person('lan');
    final minh = await person('minh');
    final vy = await person('vy');
    final ws = const Uuid().v4();
    await lan.keys.createSpace(lan.account, ws);
    final atOnce = await lan.keys.invite(ws, SpaceRole.editor, InviteKind.joinAtOnce);
    await minh.keys.accept(minh.account, parseInvitation(atOnce.link)!);
    final approve = await lan.keys.invite(ws, SpaceRole.viewer, InviteKind.approve);
    expect((await vy.keys.peek(approve.code)).role, SpaceRole.viewer);
    await vy.keys.accept(vy.account, approve.code);
    await lan.keys.approve(ws, vy.account);
    for (final p in [lan, minh, vy]) {
      expect(await p.spaceSync.refresh(), isNull);
      ok(await p.spaces.show(ws));
    }

    final t = ok(await lan.tasks.create('Family dinner'));
    await lan.now();
    await minh.now();
    expect((await minh.task(t))!['title'], 'Family dinner');
    ok(await minh.tasks.setNotes(t, 'Saturday at 7'));
    await minh.now();
    await lan.now();
    await vy.now();
    for (final p in [lan, vy]) {
      final row = (await p.task(t))!;
      expect((row['notes'], row['changedBy']), ('Saturday at 7', minh.account), reason: p.account);
    }
    expect((await vy.tasks.rename(t, 'Viewer edit')) is CommandFailure, isTrue);
    expect((await vy.now()).pushed, 0);
    // The personal sync of each is untouched by the space.
    expect((await lan.personalSync.syncNow()).outcome, SyncOutcome.upToDate);
  });

  test('T12: a named space; a personal task moved in after confirming; the member sees both', () async {
    final lan = await person('lan');
    final minh = await person('minh');
    final lanShare = DriftSharingService(
        db: lan.db, gateway: lan.gw, server: lan.remote, keys: lan.keys, keyring: lan.keyring, sync: lan.spaceSync);
    final minhShare = DriftSharingService(
        db: minh.db, gateway: minh.gw, server: minh.remote, keys: minh.keys, keyring: minh.keyring, sync: minh.spaceSync);
    final made = await lanShare.createSpace('Family');
    expect(made.problem, isNull, reason: made.detail);
    final ws = made.spaceId!;
    final inv = await lanShare.invite(ws, SpaceRole.editor, InviteKind.joinAtOnce);
    expect((await minhShare.join(inv.invitation!.link)).problem, isNull);
    ok(await minh.spaces.show(ws));

    ok(await lan.spaces.show((await ProfileStore(lan.db).personalWorkspaceId())!));
    final t = ok(await lan.tasks.create('Dinner on Saturday'));
    final preview = await lanShare.previewMove('task', t, ws);
    expect(preview.titles, ['Dinner on Saturday']);
    expect((await lanShare.move(preview)).problem, isNull);
    expect((await lan.personalSync.syncNow()).outcome, SyncOutcome.upToDate);
    ok(await lan.spaces.show(ws));
    await lan.now();
    await minh.now();
    expect((await minh.task(t))!['title'], 'Dinner on Saturday');
    expect((await minh.spaces.spaces()).singleWhere((s) => s.shared).name, 'Family');
  });

  test('rotate: a member removed; the owner seals everything again; the others catch up; the removed one stops', () async {
    final lan = await person('lan');
    final minh = await person('minh');
    final vy = await person('vy');
    final ws = const Uuid().v4();
    await lan.keys.createSpace(lan.account, ws);
    for (final p in [minh, vy]) {
      final inv = await lan.keys.invite(ws, SpaceRole.editor, InviteKind.approve);
      await p.keys.accept(p.account, inv.code);
      await lan.keys.approve(ws, p.account);
    }
    for (final p in [lan, minh, vy]) {
      expect(await p.spaceSync.refresh(), isNull);
      ok(await p.spaces.show(ws));
    }
    final t = ok(await lan.tasks.create('Budget'));
    for (final p in [lan, minh, vy]) {
      await p.now();
    }
    ok(await minh.tasks.rename(t, 'Budget for December'));

    await lan.remote.removeMember(ws, vy.account);
    final newKey = await lan.keys.rotate(ws);
    await lan.now();
    expect(await lan.keyring.previousKeyOf(ws), isNull);
    expect({for (final r in await lan.remote.pull(ws, 0)) r.keyId}, {newKey});

    await minh.now();
    await lan.now();
    expect((await lan.task(t))!['title'], 'Budget for December');
    expect(await vy.spaceSync.refresh(), isNull);
    expect((await vy.spaceSync.syncNow()).outcome, SyncOutcome.notOn);
    expect(await vy.remote.pull(ws, 0), isEmpty);
  });
}
