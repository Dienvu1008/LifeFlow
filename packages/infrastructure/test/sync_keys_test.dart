// P04 T1b (p04-plan.md D12/D15, ADR-0052 §5, ADR-0054): keys for end-to-end
// encrypted sync.
//   seal        only the right key opens a record, for its own id and
//               version; changed bytes are refused; a fresh nonce each time;
//               server ids say nothing about the record
//   recovery    24 words with a checksum, a QR text, typing two words back
//   passphrase  at least 12 characters, not a common password (also with
//               digits or symbols added at either end)
//   keyring     set up, keep after confirming, unlock on a second device,
//               switch between recovery key and passphrase without sealing
//               again, forget; reset makes the old server copy unreadable
//   end to end  device A turns sync on; device B joins with the words; the
//               server holds nothing readable
//   speed       10 000 records sealed and opened; one Argon2id derivation
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:crypto/crypto.dart' as hash;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:infrastructure/src/sync/bip39_english.dart';
import 'package:test/test.dart';

import 'profile_harness.dart' show MemoryKeys;
import 'sync_spike/fake_server.dart';
import 'sync_spike/replica.dart';

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const ws = '10000000-0000-4000-8000-00000000000a';

  group('sealing', () {
    late RecordSealer sealer;
    setUp(() async => sealer = await RecordSealer.of(await newWorkspaceKey()));
    final content = {'kind': 'task', 'id': 'local-1', 'row': {'title': 'Call the bank', 'notes': 'about the loan'}};

    test('round trip; a fresh nonce each time', () async {
      final sid = await sealer.serverId('task', 'local-1');
      final a = await sealer.seal(sid, 3, content);
      final b = await sealer.seal(sid, 3, content);
      expect(a, isNot(b));
      expect(await sealer.open(sid, 3, a), content);
      expect(await sealer.open(sid, 3, b), content);
    });

    test('another key, id or version, a changed byte or junk is refused', () async {
      final sid = await sealer.serverId('task', 'local-1');
      final sealed = await sealer.seal(sid, 3, content);
      final stranger = await RecordSealer.of(await newWorkspaceKey());
      await expectLater(stranger.open(sid, 3, sealed), throwsA(isA<SealBroken>()));
      await expectLater(sealer.open(await sealer.serverId('task', 'local-2'), 3, sealed), throwsA(isA<SealBroken>()));
      await expectLater(sealer.open(sid, 4, sealed), throwsA(isA<SealBroken>()));
      for (final at in [0, 12, sealed.length ~/ 2, sealed.length - 1]) {
        final bad = Uint8List.fromList(sealed)..[at] ^= 1;
        await expectLater(sealer.open(sid, 3, bad), throwsA(isA<SealBroken>()), reason: 'byte $at');
      }
      await expectLater(sealer.open(sid, 3, [1, 2, 3]), throwsA(isA<SealBroken>()));
    });

    test('server ids say nothing about the record', () async {
      final a = await sealer.serverId('task', 'local-1');
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')), reason: 'the S-03 id format');
      expect(await sealer.serverId('task', 'local-1'), a);
      expect(await sealer.serverId('schedule', 'local-1'), isNot(a));
      expect(await (await RecordSealer.of(await newWorkspaceKey())).serverId('task', 'local-1'), isNot(a));
      expect(a, isNot(hash.sha256.convert(utf8.encode('task:local-1')).toString()));
    });
  });

  group('recovery key', () {
    test('the bundled word list is BIP-39\'s English list', () {
      expect(bip39English, hasLength(2048));
      expect(hash.sha256.convert(utf8.encode('${bip39English.join('\n')}\n')).toString(),
          '2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda');
    });

    test('24 words and a QR text both give the key back; a wrong word is refused', () {
      final key = RecoveryKey.generate();
      final words = key.words;
      expect(words, hasLength(24));
      expect(RecoveryKey.parse(words.join(' ')).bytes, key.bytes);
      expect(RecoveryKey.parse('  ${words.join('\n').toUpperCase()}  ').bytes, key.bytes);
      expect(key.qrText, startsWith('LIFEFLOW RECOVERY 1 '));
      expect(key.qrText, matches(RegExp(r'^[A-Z0-9 ]+$')), reason: 'QR alphanumeric mode');
      expect(RecoveryKey.parse(key.qrText).bytes, key.bytes);
      expect(() => RecoveryKey.parse(words.take(23).join(' ')),
          throwsA(isA<RecoveryKeyInvalid>().having((e) => e.message, 'message', contains('24 words'))));
      expect(() => RecoveryKey.parse([...words.take(5), 'notaword', ...words.skip(6)].join(' ')),
          throwsA(isA<RecoveryKeyInvalid>().having((e) => e.message, 'message', contains('Word 6'))));
      var caught = 0;
      for (final w in bip39English.take(256)) {
        if (w == words.last) continue;
        try {
          RecoveryKey.parse([...words.take(23), w].join(' '));
        } on RecoveryKeyInvalid {
          caught++;
        }
      }
      expect(caught, greaterThan(230), reason: 'the checksum catches almost every swapped word');
    });

    test('typing two words back confirms the key', () {
      final key = RecoveryKey.generate();
      final w = key.words;
      for (var seed = 0; seed < 50; seed++) {
        final (a, b) = RecoveryKey.checkPositions(Random(seed));
        expect(a, inInclusiveRange(1, 23));
        expect(b, inInclusiveRange(a + 1, 24));
        expect(key.confirms((a, b), (w[a - 1], ' ${w[b - 1].toUpperCase()} ')), isTrue);
        expect(key.confirms((a, b), (w[b - 1], w[a - 1])), w[a - 1] == w[b - 1]);
        // One right word is not enough.
        expect(key.confirms((a, b), (w[a - 1], 'zzz')), isFalse);
        expect(key.confirms((a, b), ('zzz', w[b - 1])), isFalse);
      }
    });
  });

  test('passphrase: 12 characters or more, and not a common password', () {
    expect(checkPassphrase('short one'), PassphraseProblem.tooShort);
    expect(checkPassphrase('   eleven ch   '), PassphraseProblem.tooShort, reason: 'spaces at the ends do not count');
    expect(checkPassphrase('passwordpassword'), PassphraseProblem.tooCommon);
    expect(checkPassphrase('Password2024!'), PassphraseProblem.tooCommon, reason: 'digits and symbols added at the end');
    expect(checkPassphrase('!!qwertyuiop12'), PassphraseProblem.tooCommon);
    expect(checkPassphrase('aaaaaaaaaaaaaa'), PassphraseProblem.tooCommon);
    expect(checkPassphrase('correct horse battery staple'), isNull);
    expect(checkPassphrase('mèo con đi học sớm'), isNull, reason: 'any script');
    expect(checkPassphrase('học bài 2024!!'), isNull);
  });

  group('keyring', () {
    late MemoryKeys slots;
    late WorkspaceKeyring a;
    setUp(() {
      slots = MemoryKeys();
      a = WorkspaceKeyring(slots.call);
    });

    test('a setup is kept only when the user confirms it; the key is in secure storage only', () async {
      final setup = await a.setUpWithRecoveryKey(ws);
      expect(await a.keyOf(ws), isNull, reason: 'not before the confirmation');
      await a.keep(ws, setup);
      expect(await (await a.keyOf(ws))!.extractBytes(), await setup.workspaceKey.extractBytes());
      expect(slots.values.keys, ['lifeflow.sync.key.$ws']);
      expect(setup.wrapped.kind, UnlockKind.recoveryKey);
      expect(setup.wrapped.bytes.first, wrapFormat);
      final raw = base64Encode(await setup.workspaceKey.extractBytes());
      expect(base64Encode(setup.wrapped.bytes).contains(raw), isFalse, reason: 'the wrapped key is not the key');
      await a.forget(ws);
      expect(await a.keyOf(ws), isNull);
    });

    test('a second device unlocks with the recovery key; a wrong one or another workspace is refused', () async {
      final setup = await a.setUpWithRecoveryKey(ws);
      await a.keep(ws, setup);
      final b = WorkspaceKeyring(MemoryKeys().call);
      await expectLater(b.unlock(ws, setup.wrapped, recoveryKey: RecoveryKey.generate()), throwsA(isA<SealBroken>()));
      expect(await b.keyOf(ws), isNull, reason: 'nothing kept after a failure');
      await expectLater(b.unlock('another', setup.wrapped, recoveryKey: setup.recoveryKey), throwsA(isA<SealBroken>()));
      final typed = RecoveryKey.parse(setup.recoveryKey!.words.join(' '));
      final key = await b.unlock(ws, setup.wrapped, recoveryKey: typed);
      expect(await key.extractBytes(), await setup.workspaceKey.extractBytes());
      expect(await b.keyOf(ws), isNotNull);
    });

    test('a passphrase: refused below the minimum; unlocks with the same words, spaces at the ends aside', () async {
      await expectLater(a.setUpWithPassphrase(ws, 'password2024'),
          throwsA(isA<PassphraseRejected>().having((e) => e.problem, 'problem', PassphraseProblem.tooCommon)));
      final setup = await a.setUpWithPassphrase(ws, 'correct horse battery staple');
      expect((setup.wrapped.kind, setup.wrapped.salt!.length, setup.recoveryKey), (UnlockKind.passphrase, 16, null));
      final b = WorkspaceKeyring(MemoryKeys().call);
      await expectLater(b.unlock(ws, setup.wrapped, passphrase: 'correct horse battery stapler'), throwsA(isA<SealBroken>()));
      final key = await b.unlock(ws, setup.wrapped, passphrase: ' correct horse battery staple ');
      expect(await key.extractBytes(), await setup.workspaceKey.extractBytes());
      expect(() => b.unlock(ws, setup.wrapped, recoveryKey: RecoveryKey.generate()), throwsArgumentError,
          reason: 'this key is unlocked by its passphrase');
    });

    test('switching recovery key <-> passphrase re-wraps only: old records still open', () async {
      final setup = await a.setUpWithRecoveryKey(ws);
      await a.keep(ws, setup);
      final sealer = await RecordSealer.of(setup.workspaceKey);
      final sid = await sealer.serverId('task', 't');
      final record = await sealer.seal(sid, 1, {'kind': 'task', 'id': 't', 'row': {'title': 'x'}});

      final byPass = await a.rewrap(ws, passphrase: 'correct horse battery staple');
      final b = WorkspaceKeyring(MemoryKeys().call);
      final key = await b.unlock(ws, byPass, passphrase: 'correct horse battery staple');
      expect(await (await RecordSealer.of(key)).open(sid, 1, record), isNotEmpty);
      await expectLater(b.unlock(ws, byPass, passphrase: 'wrong horse battery staple'), throwsA(isA<SealBroken>()));

      final newer = RecoveryKey.generate();
      final byNew = await a.rewrap(ws, recoveryKey: newer);
      await expectLater(WorkspaceKeyring(MemoryKeys().call).unlock(ws, byNew, recoveryKey: setup.recoveryKey),
          throwsA(isA<SealBroken>()), reason: 'the old recovery key no longer opens the new wrapping');
      expect(await (await RecordSealer.of(await WorkspaceKeyring(MemoryKeys().call).unlock(ws, byNew, recoveryKey: newer)))
          .open(sid, 1, record), isNotEmpty);
      expect(() => WorkspaceKeyring(MemoryKeys().call).rewrap(ws, recoveryKey: newer), throwsStateError,
          reason: 'only a device with the key can re-wrap it');
    });

    test('reset: a new key; what was sealed under the old one cannot be opened with it', () async {
      final first = await a.setUpWithRecoveryKey(ws);
      await a.keep(ws, first);
      final old = await RecordSealer.of(first.workspaceKey);
      final sid = await old.serverId('task', 't');
      final record = await old.seal(sid, 1, {'kind': 'task', 'id': 't', 'row': {'title': 'x'}});
      final again = await a.setUpWithRecoveryKey(ws);
      await a.keep(ws, again);
      final fresh = await RecordSealer.of((await a.keyOf(ws))!);
      await expectLater(fresh.open(sid, 1, record), throwsA(isA<SealBroken>()));
      expect(await fresh.serverId('task', 't'), isNot(sid), reason: 'new server ids too: a fresh upload');
      await expectLater(WorkspaceKeyring(MemoryKeys().call).unlock(ws, first.wrapped, recoveryKey: again.recoveryKey),
          throwsA(isA<SealBroken>()));
    });

    test('a wrapping of a newer format is refused, not misread', () async {
      final setup = await a.setUpWithRecoveryKey(ws);
      final newer = WrappedKey(Uint8List.fromList([2, ...setup.wrapped.bytes.skip(1)]), UnlockKind.recoveryKey);
      await expectLater(a.unlock(ws, newer, recoveryKey: setup.recoveryKey),
          throwsA(isA<SealBroken>().having((e) => e.why, 'why', contains('newer'))));
    });
  });

  test('end to end: A turns sync on, B joins with the 24 words; the server holds nothing readable', () async {
    final dir = Directory.systemTemp.createTempSync('lifeflow_keys_');
    final server = FakeServer();
    final fa = File('${dir.path}/a.db');
    final dbA = AppDatabase(NativeDatabase(fa));
    final profile = await ProfileStore(dbA).ensureFirstProfile();
    final wsA = profile.activeWorkspaceId.value;
    final gwA = DriftCommandGateway(dbA, WorkspaceOwnerAuthorization(dbA));
    final keysA = WorkspaceKeyring(MemoryKeys().call);
    final setup = await keysA.setUpWithRecoveryKey(wsA);
    final words = setup.recoveryKey!.words;
    final (p1, p2) = RecoveryKey.checkPositions();
    expect(setup.recoveryKey!.confirms((p1, p2), (words[p1 - 1], words[p2 - 1])), isTrue);
    await keysA.keep(wsA, setup);
    final a = Replica('a', dbA, server, sealer: await RecordSealer.of((await keysA.keyOf(wsA))!));
    final t = ok(await DriftTaskService(dbA, gwA).create('Call the bank'));
    ok(await DriftTaskService(dbA, gwA).setNotes(t, 'about the loan, account 12-345'));
    await a.sync();
    await dbA.close();

    final dbB = AppDatabase(NativeDatabase(fa.copySync('${dir.path}/b.db')));
    addTearDown(() async {
      await dbB.close();
      dir.deleteSync(recursive: true);
    });
    await dbB.customStatement('DELETE FROM tasks'); // B gets everything from the server
    final keysB = WorkspaceKeyring(MemoryKeys().call);
    final key = await keysB.unlock(wsA, setup.wrapped, recoveryKey: RecoveryKey.parse(words.join(' ')));
    final b = Replica('b', dbB, server, sealer: await RecordSealer.of(key));
    await b.pull();
    final row = (await recordKindByName['task']!.readAll(dbB)).single;
    expect((row['title'], row['notes']), ('Call the bank', 'about the loan, account 12-345'));

    for (final r in server.records.values) {
      expect(r.id, matches(RegExp(r'^[0-9a-f]{64}$')));
      final asText = latin1.decode(base64Decode(r.sealed!));
      for (final secret in ['Call the bank', 'loan', '12-345', t, 'task', 'title', wsA]) {
        expect(asText.contains(secret), isFalse, reason: '"$secret" is readable on the server');
      }
    }
    expect(base64Encode(setup.wrapped.bytes).contains(base64Encode(await key.extractBytes())), isFalse);
  });

  test('speed: 10 000 records sealed and opened; one Argon2id derivation', () async {
    final sealer = await RecordSealer.of(await newWorkspaceKey());
    final row = {'title': 'A task with a title of some length', 'notes': 'n' * 200, 'status': 'todo', 'colorIndex': 3};
    final sw = Stopwatch()..start();
    final sealed = <(String, Uint8List)>[];
    for (var i = 0; i < 10000; i++) {
      final sid = await sealer.serverId('task', 'id-$i');
      sealed.add((sid, await sealer.seal(sid, 1, {'kind': 'task', 'id': 'id-$i', 'row': row})));
    }
    final sealMs = sw.elapsedMilliseconds;
    sw.reset();
    for (final (sid, s) in sealed) {
      await sealer.open(sid, 1, s);
    }
    final openMs = sw.elapsedMilliseconds;
    sw.reset();
    await unlockFromPassphrase('correct horse battery staple', List.filled(16, 7));
    // ignore: avoid_print
    print('T1b speed: seal 10k = $sealMs ms, open 10k = $openMs ms, Argon2id = ${sw.elapsedMilliseconds} ms');
    expect(sealMs + openMs, lessThan(60000));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
