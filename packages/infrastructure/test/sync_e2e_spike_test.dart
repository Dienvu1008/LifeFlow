// P04 spike S-15 (p04-plan.md D12, D15): end-to-end encryption of synced
// records, with the prototype in test/sync_spike/e2e.dart.
//   seal       only the right key opens a record, for its own id and version;
//              changed bytes are refused; the same record seals differently
//              each time
//   ids        server ids are keyed hashes: no kind, no local id, no link
//   unlock     a recovery key (24 words, with a checksum) or a passphrase
//              (Argon2id) unwraps the workspace key; switching between them
//              re-wraps the key only
//   end to end device A turns sync on; device B joins with the 24 words; the
//              server holds nothing readable
//   speed      10 000 records sealed and opened; one Argon2id derivation
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'sync_spike/e2e.dart';
import 'sync_spike/fake_server.dart';
import 'sync_spike/replica.dart';

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('sealing', () {
    late RecordSealer sealer;
    setUp(() async => sealer = await RecordSealer.of(await newWorkspaceKey()));
    final content = {'kind': 'task', 'id': 'local-1', 'row': {'title': 'Call the bank', 'notes': 'about the loan'}};

    test('round trip; a fresh nonce each time', () async {
      final sid = await sealer.serverId('task', 'local-1');
      final a = await sealer.seal(sid, 3, content);
      final b = await sealer.seal(sid, 3, content);
      expect(a, isNot(b), reason: 'the same record seals differently each time');
      expect(await sealer.open(sid, 3, a), content);
      expect(await sealer.open(sid, 3, b), content);
    });

    test('another key, another id, another version or a changed byte is refused', () async {
      final sid = await sealer.serverId('task', 'local-1');
      final other = await sealer.serverId('task', 'local-2');
      final sealed = await sealer.seal(sid, 3, content);
      final stranger = await RecordSealer.of(await newWorkspaceKey());
      await expectLater(stranger.open(sid, 3, sealed), throwsA(isA<SealBroken>()));
      await expectLater(sealer.open(other, 3, sealed), throwsA(isA<SealBroken>()), reason: 'moved to another id');
      await expectLater(sealer.open(sid, 4, sealed), throwsA(isA<SealBroken>()), reason: 'replayed as another version');
      for (final at in [0, 12, sealed.length ~/ 2, sealed.length - 1]) {
        final bad = Uint8List.fromList(sealed)..[at] ^= 1;
        await expectLater(sealer.open(sid, 3, bad), throwsA(isA<SealBroken>()), reason: 'byte $at changed');
      }
    });

    test('server ids say nothing about the record', () async {
      final a = await sealer.serverId('task', 'local-1');
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')), reason: 'the S-03 id format');
      expect(await sealer.serverId('task', 'local-1'), a, reason: 'stable for one workspace');
      expect(await sealer.serverId('schedule', 'local-1'), isNot(a), reason: 'the kind is hidden in the hash');
      final other = await RecordSealer.of(await newWorkspaceKey());
      expect(await other.serverId('task', 'local-1'), isNot(a), reason: 'without the key the id cannot be guessed');
      expect(a, isNot(opaqueId('task', 'local-1')), reason: 'not a plain hash anyone can compute');
    });
  });

  group('unlocking', () {
    test('the recovery key as 24 words: round trip; a misspelt or swapped word is refused', () {
      final key = newRecoveryKey();
      final words = toWords(key);
      expect(words, hasLength(24));
      expect(fromWords(words), key);
      expect(fromWords([for (final w in words) ' ${w.toUpperCase()} ']), key, reason: 'case and spaces do not matter');
      expect(() => fromWords([...words.take(23), 'notaword']), throwsFormatException);
      expect(() => fromWords(words.take(23).toList()), throwsFormatException);
      // Swapping one word for another: refused by the checksum (8 bits, so
      // about 255 of 256 swaps; count them over the last word).
      var caught = 0;
      for (final w in bip39.take(256)) {
        if (w == words.last) continue;
        try {
          fromWords([...words.take(23), w]);
        } on FormatException {
          caught++;
        }
      }
      expect(caught, greaterThan(230));
    });

    test('recovery key and passphrase both unwrap the workspace key; switching re-wraps only', () async {
      const ws = '10000000-0000-4000-8000-00000000000a';
      final workspaceKey = await newWorkspaceKey();
      final sealer = await RecordSealer.of(workspaceKey);
      final sid = await sealer.serverId('task', 't');
      final record = await sealer.seal(sid, 1, {'kind': 'task', 'id': 't', 'row': {'title': 'x'}});

      final recovery = newRecoveryKey();
      final wrapped = await wrapKey(await unlockFromRecoveryKey(recovery), workspaceKey, ws);
      final back = await unwrapKey(await unlockFromRecoveryKey(fromWords(toWords(recovery))), wrapped, ws);
      expect(await back.extractBytes(), await workspaceKey.extractBytes());
      await expectLater(unwrapKey(await unlockFromRecoveryKey(newRecoveryKey()), wrapped, ws), throwsA(isA<SealBroken>()));
      await expectLater(unwrapKey(await unlockFromRecoveryKey(recovery), wrapped, 'another-workspace'),
          throwsA(isA<SealBroken>()), reason: 'a wrapped key belongs to its workspace');

      // Switch to a passphrase: the workspace key is re-wrapped, records stay.
      final salt = newRecoveryKey().sublist(0, 16);
      final byPass = await wrapKey(await unlockFromPassphrase('correct horse battery staple', salt), back, ws);
      final again = await unwrapKey(await unlockFromPassphrase('correct horse battery staple', salt), byPass, ws);
      expect(await (await RecordSealer.of(again)).open(sid, 1, record), isNotEmpty,
          reason: 'old records open with the re-wrapped key; nothing is sealed again');
      await expectLater(unwrapKey(await unlockFromPassphrase('correct horse battery stapler', salt), byPass, ws),
          throwsA(isA<SealBroken>()));
    });
  });

  test('end to end: A turns sync on, B joins with the 24 words; the server holds nothing readable', () async {
    final dir = Directory.systemTemp.createTempSync('lifeflow_e2e_spike_');
    final server = FakeServer();
    final fa = File('${dir.path}/a.db');
    final dbA = AppDatabase(NativeDatabase(fa));
    final profile = await ProfileStore(dbA).ensureFirstProfile();
    final ws = profile.activeWorkspaceId.value;
    final gwA = DriftCommandGateway(dbA, WorkspaceOwnerAuthorization(dbA));

    // A: a new workspace key, a recovery key shown as words, the wrapped key
    // stored with the workspace on the server.
    final workspaceKey = await newWorkspaceKey();
    final recovery = newRecoveryKey();
    final words = toWords(recovery);
    final wrapped = await wrapKey(await unlockFromRecoveryKey(recovery), workspaceKey, ws);
    final a = Replica('a', dbA, server, sealer: await RecordSealer.of(workspaceKey));
    final t = ok(await DriftTaskService(dbA, gwA).create('Call the bank'));
    ok(await DriftTaskService(dbA, gwA).setNotes(t, 'about the loan, account 12-345'));
    await a.sync();
    await dbA.close();

    // B: a copy of the workspace (as after joining), unlocked with the words.
    final dbB = AppDatabase(NativeDatabase(fa.copySync('${dir.path}/b.db')));
    final dbA2 = AppDatabase(NativeDatabase(fa));
    addTearDown(() async {
      await dbB.close();
      await dbA2.close();
      dir.deleteSync(recursive: true);
    });
    await dbB.customStatement("DELETE FROM tasks"); // B starts empty: everything comes from the server
    final unlocked = await unwrapKey(await unlockFromRecoveryKey(fromWords(words)), wrapped, ws);
    final b = Replica('b', dbB, server, sealer: await RecordSealer.of(unlocked));
    await b.pull();
    final row = (await recordKindByName['task']!.readAll(dbB)).single;
    expect((row['title'], row['notes']), ('Call the bank', 'about the loan, account 12-345'));

    // An edit on B reaches A, still sealed.
    final gwB = DriftCommandGateway(dbB, WorkspaceOwnerAuthorization(dbB));
    ok(await DriftTaskService(dbB, gwB).rename(t, 'Call the bank today'));
    await b.sync();
    final a2 = Replica('a', dbA2, server, sealer: await RecordSealer.of(workspaceKey))
      ..base.addAll(a.base)
      ..cursor = a.cursor;
    await a2.pull();
    expect((await recordKindByName['task']!.readAll(dbA2)).single['title'], 'Call the bank today');

    // What the server has: ids, versions, numbers and sealed bytes only.
    for (final r in server.records.values) {
      expect(r.id, matches(RegExp(r'^[0-9a-f]{64}$')));
      final bytes = base64Decode(r.sealed!);
      final asText = latin1.decode(bytes);
      for (final secret in ['Call the bank', 'loan', '12-345', t, 'task', 'title', ws]) {
        expect(asText.contains(secret), isFalse, reason: '"$secret" is readable on the server');
      }
    }
    expect(server.records.keys.any((k) => k.contains(t)), isFalse);
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
    final argonMs = sw.elapsedMilliseconds;
    final size = sealed.first.$2.length;
    // ignore: avoid_print
    print('S-15 speed: seal 10k = $sealMs ms, open 10k = $openMs ms, one sealed record = $size bytes, '
        'Argon2id (19 MiB, t=2) = $argonMs ms, AES-GCM = ${AesGcm.with256bits().runtimeType}');
    expect(sealMs + openMs, lessThan(60000));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
