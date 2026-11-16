// P04 T4 (ADR-0057; p04-plan.md D5, D11, D15): turning sync on, joining,
// undoing a join, turning off and deleting the server copy. Two devices of
// one account, each with its own profile store and workspace (as today:
// ADR-0025 T7c), its own secure storage, one in-memory server.
//   start      a recovery key shown, confirmed by two words, then the server
//              workspace (wrapped key, key fingerprint) and the first upload
//   join       merge keeps both devices' records with their ids in the
//              account's workspace; "use the account's data" exports first
//              and can be undone; wrong or mistyped keys are refused
//   passphrase the same with a passphrase, with its minimum
//   off/delete sync off keeps the data; deleting the server copy is noticed
//              by the other device, and so is a new key
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'profile_harness.dart' show MemoryKeys;

class _Time implements DeviceTime {
  @override
  Instant now() => Instant.now();
  @override
  String zone() => 'UTC';
}

/// Exports the store as the app's data transfer would (D5).
class _Export implements DataTransferService {
  _Export(this.db);
  final AppDatabase db;
  int calls = 0;
  @override
  Future<ExportFile> exportActiveProfile() async {
    calls++;
    return ExportFile(suggestedName: 'before-sync.lifeflow.json', contents: await ProfileExport.build(db), taskCount: 0);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class Device {
  Device(this.name, this.db, MemoryRemoteServer server, {String account = 'acc'})
      : gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)),
        remote = MemoryRemoteGateway(server, accountId: account),
        keys = MemoryKeys() {
    tasks = DriftTaskService(db, gw);
    habits = DriftHabitService(db, gw, _Time());
    habitQueries = DriftHabitQueries(db, _Time());
    export = _Export(db);
    sync = DriftSyncService(db: db, gateway: gw, remote: remote, keyring: WorkspaceKeyring(keys.call), transfer: export);
  }
  final String name;
  final AppDatabase db;
  final DriftCommandGateway gw;
  final MemoryRemoteGateway remote;
  final MemoryKeys keys;
  late final DriftTaskService tasks;
  late final DriftHabitService habits;
  late final DriftHabitQueries habitQueries;
  late final _Export export;
  late final DriftSyncService sync;

  Future<String> ws() async => (await ProfileStore(db).getActiveProfile())!.activeWorkspaceId.value;
  Future<List<String>> titles() async =>
      [for (final r in await recordKindByName['task']!.readAll(db)) if (r['deletedAt'] == null) r['title'] as String]..sort();
}

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

void expectOk(SyncSetupResult r) {
  expect(r.problem, isNull, reason: '${r.problem} ${r.message}');
  if (r.firstSync != null) expect(r.firstSync!.outcome, SyncOutcome.upToDate, reason: '${r.firstSync}');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late MemoryRemoteServer server;
  final open = <AppDatabase>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lifeflow_sync_setup_');
    server = MemoryRemoteServer();
  });
  tearDown(() async {
    for (final db in open) {
      await db.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  Future<Device> device(String name) async {
    final db = AppDatabase(NativeDatabase(File('${dir.path}/$name.db')));
    open.add(db);
    await ProfileStore(db).ensureFirstProfile();
    return Device(name, db, server);
  }

  /// A turns sync on with a recovery key; returns its words.
  Future<List<String>> startWithKey(Device a) async {
    expect(await a.sync.prepare(), isA<SyncStartFresh>());
    final offer = await a.sync.offerRecoveryKey();
    final (p1, p2) = offer.check;
    expectOk(await a.sync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1])));
    return offer.words;
  }

  test('start: the recovery key must be confirmed; then the server workspace and the first upload', () async {
    final a = await device('a');
    ok(await a.tasks.create('Call the bank'));
    ok(await a.tasks.create('Buy milk'));
    final offer = await a.sync.offerRecoveryKey();
    expect(offer.words, hasLength(24));
    expect(offer.qrText, startsWith('LIFEFLOW RECOVERY 1'));
    final (p1, p2) = offer.check;
    final wrong = await a.sync.startWithRecoveryKey((offer.words[p1 - 1], 'zzz'));
    expect(wrong.problem, SyncSetupProblem.recoveryKeyNotConfirmed);
    expect(await a.remote.workspaces(), isEmpty, reason: 'nothing on the server before the confirmation');
    expect((await a.sync.status()).on, isFalse);

    expectOk(await a.sync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1])));
    final ws = await a.ws();
    final remote = (await a.remote.workspaces()).single;
    expect((remote.workspaceId, remote.unlockKind, remote.keyId.length), (ws, 'recoveryKey', 64));
    expect(server.dump(ws).length, greaterThanOrEqualTo(2), reason: 'everything uploaded');
    final s = await a.sync.status();
    expect((s.on, s.lastResult, s.pending), (true, SyncOutcome.upToDate, 0));
    expect(await a.sync.prepare(), isA<SyncStartAlreadyOn>());
  });

  test('join and merge: both devices\' records, with their ids, in the account\'s workspace', () async {
    final a = await device('a');
    final ta = ok(await a.tasks.create('From A'));
    final words = await startWithKey(a);
    final b = await device('b');
    final tb = ok(await b.tasks.create('From B'));
    final oldWs = await b.ws();

    expect(await b.sync.prepare(), isA<SyncStartJoin>().having((j) => j.unlock, 'unlock', SyncUnlock.recoveryKey));
    final typo = await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: [...words.take(23), 'notaword'].join(' '));
    expect(typo.problem, SyncSetupProblem.recoveryKeyInvalid);
    expect(typo.message, contains('Word 24'));
    final other = await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: RecoveryKey.generate().words.join(' '));
    expect(other.problem, SyncSetupProblem.wrongRecoveryKey);
    expect((await b.sync.status()).on, isFalse);

    expectOk(await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: words.join(' ')));
    expect(await b.ws(), await a.ws(), reason: 'B now uses the account\'s workspace');
    expect(await (b.db.select(b.db.workspaces)..where((w) => w.id.equals(oldWs))).get(), isEmpty);
    expect(await b.titles(), ['From A', 'From B']);
    expect((await recordKindByName['task']!.readOne(b.db, tb))!['workspaceId'], await a.ws(), reason: 'ids kept, moved');
    expectOk(SyncSetupResult(firstSync: await a.sync.syncNow()));
    expect(await a.titles(), ['From A', 'From B']);
    expect(await recordKindByName['task']!.readOne(a.db, tb), isNotNull);
    expect(await recordKindByName['task']!.readOne(b.db, ta), isNotNull);
    // B goes on working in the new workspace.
    ok(await b.tasks.create('After joining'));
    await b.sync.syncNow();
    await a.sync.syncNow();
    expect(await a.titles(), contains('After joining'));
    expect((await b.sync.status()).canUndoJoin, isTrue);
  });

  test('settings: a joining device\'s result policy moves into the account\'s workspace and reaches the other device', () async {
    final a = await device('a');
    final words = await startWithKey(a);
    final b = await device('b');
    ok(await b.habits.setManualResults(ManualResults.tick));
    expectOk(await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: words.join(' ')));
    final ws = await a.ws();
    expect((await b.db.select(b.db.workspaceSettings).getSingle()).id, ws);
    expect(await b.habitQueries.manualResults(), ManualResults.tick);
    await a.sync.syncNow();
    expect(await a.habitQueries.manualResults(), ManualResults.tick);
  });

  test('use the account\'s data: exported first, replaced, and the join can be undone', () async {
    final a = await device('a');
    ok(await a.tasks.create('From A'));
    final words = await startWithKey(a);
    final b = await device('b');
    ok(await b.tasks.create('Only on B'));
    final oldWs = await b.ws();

    final r = await b.sync.join(JoinChoice.useAccountOnly, recoveryKey: words.join(' '));
    expectOk(r);
    expect(r.export!.contents, contains('Only on B'), reason: 'saved before it was replaced');
    expect(await b.titles(), ['From A']);
    expect(server.dump(await a.ws()).length, lessThan(5), reason: 'B\'s own data was not uploaded');

    expectOk(await b.sync.undoJoin());
    expect(await b.titles(), ['Only on B']);
    expect(await b.ws(), oldWs);
    expect((await b.sync.status()).on, isFalse);
    expect(
        [for (final o in await b.db.select(b.db.outbox).get()) if (o.status == 'pending' && recordKindByName.containsKey(o.entityType)) o],
        isEmpty,
        reason: 'no record waits to be sent while sync is off');
    expect(b.keys.values, isEmpty, reason: 'the key is forgotten');
    ok(await b.tasks.create('Back as before'));
    expect((await b.sync.undoJoin()).problem, SyncSetupProblem.nothingToUndo);
    await a.sync.syncNow();
    expect(await a.titles(), ['From A'], reason: 'A is untouched');
  });

  test('passphrase: the minimum is checked; a second device joins with it; a wrong one is refused', () async {
    final a = await device('a');
    ok(await a.tasks.create('From A'));
    expect((await a.sync.startWithPassphrase('short')).problem, SyncSetupProblem.passphraseTooShort);
    expect((await a.sync.startWithPassphrase('password2024!')).problem, SyncSetupProblem.passphraseTooCommon);
    expect(await a.remote.workspaces(), isEmpty);
    expectOk(await a.sync.startWithPassphrase('mèo con đi học sớm'));
    final b = await device('b');
    expect(await b.sync.prepare(), isA<SyncStartJoin>().having((j) => j.unlock, 'unlock', SyncUnlock.passphrase));
    expect((await b.sync.join(JoinChoice.mergeThisDevice, passphrase: 'mèo con đi học muộn')).problem,
        SyncSetupProblem.wrongPassphrase);
    expectOk(await b.sync.join(JoinChoice.mergeThisDevice, passphrase: ' mèo con đi học sớm '));
    expect(await b.titles(), ['From A']);
  });

  test('turning off keeps the data and forgets the key; deleting the server copy is noticed elsewhere', () async {
    final a = await device('a');
    ok(await a.tasks.create('Kept'));
    final words = await startWithKey(a);
    final b = await device('b');
    expectOk(await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: words.join(' ')));

    expectOk(await b.sync.turnOff());
    expect((await b.sync.status()).on, isFalse);
    expect(await b.titles(), ['Kept']);
    expect(b.keys.values, isEmpty);
    expect((await b.sync.syncNow()).outcome, SyncOutcome.notOn);
    expect((await b.sync.undoJoin()).problem, SyncSetupProblem.nothingToUndo, reason: 'not after turning off');

    expectOk(await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: words.join(' ')));
    expectOk(await a.sync.deleteServerData());
    expect(await a.remote.workspaces(), isEmpty);
    expect((await a.sync.status()).on, isFalse);
    expect(await a.titles(), ['Kept'], reason: 'the device keeps its data');
    expect((await b.sync.syncNow()).outcome, SyncOutcome.workspaceGone);
  });

  test('starting again after deleting the server copy uploads everything, not only what is new', () async {
    final a = await device('a');
    ok(await a.tasks.create('Already sent once'));
    await startWithKey(a);
    expectOk(await a.sync.deleteServerData());
    expect(server.dump(await a.ws()), isEmpty);
    final words = await startWithKey(a);
    final b = await device('b');
    expectOk(await b.sync.join(JoinChoice.useAccountOnly, recoveryKey: words.join(' ')));
    expect(await b.titles(), ['Already sent once'], reason: 'the old records were uploaded again');
  });

  test('a new key on the account is noticed: the other device must join again', () async {
    final a = await device('a');
    final words = await startWithKey(a);
    final b = await device('b');
    expectOk(await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: words.join(' ')));
    expectOk(await a.sync.deleteServerData());
    final again = await startWithKey(a);
    expect(again, isNot(words));
    expect((await b.sync.syncNow()).outcome, SyncOutcome.keyChanged);
    expectOk(await b.sync.turnOff());
    expectOk(await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: again.join(' ')));
  });

  test('offline or signed out: nothing is set up', () async {
    final a = await device('a');
    server.unavailable = true;
    await expectLater(a.sync.prepare(), throwsA(isA<SyncSetupException>()));
    final offer = await a.sync.offerRecoveryKey();
    final (p1, p2) = offer.check;
    final r = await a.sync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1]));
    expect(r.problem, SyncSetupProblem.offline);
    expect((await a.sync.status()).on, isFalse);
    expect(a.keys.values, isEmpty, reason: 'no key kept without the server workspace');
    server.unavailable = false;
    a.remote.accountId = null;
    await expectLater(a.sync.prepare(),
        throwsA(isA<SyncSetupException>().having((e) => e.problem, 'problem', SyncSetupProblem.signedOut)));
  });

  test('the setup commands go through the gateway, audited, and refuse what does not fit', () async {
    final a = await device('a');
    await startWithKey(a);
    final audit = await a.db.select(a.db.auditLog).get();
    expect(audit.map((x) => x.action), contains(turnSyncOnAction));
    final p = (await ProfileStore(a.db).getActiveProfile())!;
    Future<CommandResult> run(Map<String, Object?> payload) => a.gw.execute(
        Command(
            operationId: 'op-${payload['op']}-${payload['mode']}',
            actor: ActorRef(ActorKind.owner, p.profileId.value),
            workspaceId: p.activeWorkspaceId.value,
            type: joinSyncAction,
            payload: payload,
            issuedAt: Instant.now()),
        const SyncSetupHandler());
    expect(await run({'op': 'turnOn', 'id': await a.ws(), 'deviceId': 'x'}), isA<CommandFailure>(), reason: 'already on');
    expect(await run({'op': 'join', 'id': await a.ws(), 'accountWorkspaceId': 'w2', 'deviceId': 'x', 'mode': 'merge'}),
        isA<CommandFailure>());
    expect(await run({'op': 'turnOff', 'id': 'another-workspace'}), isA<CommandFailure>());
    final sync = await a.gw.execute(
        Command(
            operationId: 'op-as-sync',
            actor: const ActorRef(ActorKind.sync, 'whoever'),
            workspaceId: await a.ws(),
            type: turnSyncOffAction,
            payload: {'op': 'turnOff', 'id': await a.ws()},
            issuedAt: Instant.now()),
        const SyncSetupHandler());
    expect((sync as CommandFailure).kind, CommandFailureKind.unauthorized);
  });
}
