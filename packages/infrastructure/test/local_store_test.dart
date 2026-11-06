// P01 T6b: opening the local store with real SQLite3MultipleCiphers on disk.
//   GS-19 / LF-INV-SEC-011  encrypted file is not a plain SQLite DB, data
//                           unreadable without the key, FTS5 still works
//   LF-INV-SEC-001 / OQ-DATA-1  random 256-bit key, stored before use
//   ADR-0021                Windows plain stays plain; never silently downgraded
//   upgrade path            an existing plain DB is encrypted in place, no loss
import 'dart:io';
import 'dart:math';

import 'package:application/application.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

class MemoryKeyStore implements DatabaseKeyStore {
  String? value;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async {
    writes++;
    value = key;
  }
}

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lifeflow_store_');
    file = File('${dir.path}${Platform.pathSeparator}lifeflow.sqlite');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<OpenedStore> open(AtRestPolicy policy, DatabaseKeyStore keys) =>
      openLocalStore(file: file, policy: policy, keys: keys, background: false);

  Future<void> seed(OpenedStore s, String title) async {
    final p = await ProfileStore(s.db).ensureFirstProfile();
    final gw = DriftCommandGateway(s.db, WorkspaceOwnerAuthorization(s.db));
    final r = await DriftTaskService(s.db, gw).create(title);
    expect(r, isA<CommandOk>(), reason: 'seed failed for ${p.profileId}: $r');
  }

  group('generateDatabaseKey (OQ-DATA-1)', () {
    test('is 256 bits of hex and differs each time', () {
      final a = generateDatabaseKey();
      final b = generateDatabaseKey();
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(a, isNot(b));
    });

    test('is deterministic for a seeded source (so the format is testable)', () {
      expect(generateDatabaseKey(Random(1)), generateDatabaseKey(Random(1)));
    });
  });

  group('encrypt policy (Android, GS-19)', () {
    test('first launch: key stored before use, file encrypted, data readable',
        () async {
      final keys = MemoryKeyStore();
      final s = await open(AtRestPolicy.encrypt, keys);
      await seed(s, 'Pay rent');
      await s.db.close();

      expect(keys.writes, 1);
      expect(keys.value, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(s.migratedToEncrypted, isFalse);

      // At rest: not a plain SQLite file and no plaintext title in the bytes.
      expect(isPlainSqliteFile(file), isFalse);
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes).contains('Pay rent'), isFalse);
      expect(await fileCipherProbe(file)(), isNotNull);

      // Reopen with the stored key: data and FTS5 search work.
      final again = await open(AtRestPolicy.encrypt, keys);
      final ws = (await ProfileStore(again.db).getActiveProfile())!
          .activeWorkspaceId
          .value;
      expect(await again.db.searchTaskIds(ws, 'rent'), hasLength(1));
      await again.db.close();
      expect(keys.writes, 1); // the key is reused, not regenerated
    });

    test('without the key the file cannot be read', () async {
      final keys = MemoryKeyStore();
      final s = await open(AtRestPolicy.encrypt, keys);
      await seed(s, 'Secret');
      await s.db.close();

      final raw = sqlite3.open(file.path);
      addTearDown(raw.close);
      expect(() => raw.select('SELECT count(*) FROM tasks'),
          throwsA(isA<SqliteException>()));
    });

    test('a lost key is reported and the encrypted file is left untouched',
        () async {
      final keys = MemoryKeyStore();
      final s = await open(AtRestPolicy.encrypt, keys);
      await seed(s, 'Keep me');
      await s.db.close();
      final before = file.readAsBytesSync();

      await expectLater(open(AtRestPolicy.encrypt, MemoryKeyStore()),
          throwsA(isA<StoreUnavailable>()));
      expect(file.readAsBytesSync(), before); // nothing rewritten or deleted
    });

    test('a wrong key is rejected before any migration runs', () async {
      final keys = MemoryKeyStore();
      final s = await open(AtRestPolicy.encrypt, keys);
      await seed(s, 'X');
      await s.db.close();

      final wrong = MemoryKeyStore()..value = generateDatabaseKey();
      final opened = await open(AtRestPolicy.encrypt, wrong);
      await expectLater(opened.db.select(opened.db.tasks).get(),
          throwsA(anything));
      await opened.db.close();
    });

    test('a malformed stored key is refused', () async {
      final keys = MemoryKeyStore()..value = "abc'; DROP TABLE tasks; --";
      await expectLater(
          open(AtRestPolicy.encrypt, keys), throwsA(isA<StoreUnavailable>()));
    });
  });

  group('upgrade: existing plain DB on an encrypting build', () {
    test('is encrypted in place with no data loss', () async {
      // T6a installs created a plain DB.
      final plain = await open(AtRestPolicy.plain, MemoryKeyStore());
      await seed(plain, 'From T6a');
      await plain.db.close();
      expect(isPlainSqliteFile(file), isTrue);

      final keys = MemoryKeyStore();
      final s = await open(AtRestPolicy.encrypt, keys);
      expect(s.migratedToEncrypted, isTrue);
      expect(isPlainSqliteFile(file), isFalse);
      final rows = await s.db.select(s.db.tasks).get();
      expect(rows.single.title, 'From T6a');
      final profiles = await s.db.select(s.db.profiles).get();
      expect(profiles, hasLength(1)); // same profile, nothing re-created
      await s.db.close();
    });

    test('an interrupted upgrade (key stored, file still plain) resumes',
        () async {
      final plain = await open(AtRestPolicy.plain, MemoryKeyStore());
      await seed(plain, 'Resume me');
      await plain.db.close();

      // Simulate a crash after the key was stored but before rekey ran.
      final keys = MemoryKeyStore()..value = generateDatabaseKey();
      final s = await open(AtRestPolicy.encrypt, keys);
      expect(s.migratedToEncrypted, isTrue);
      expect((await s.db.select(s.db.tasks).get()).single.title, 'Resume me');
      await s.db.close();
    });
  });

  group('plain policy (Windows MVP, ADR-0021)', () {
    test('stays plain, uses no key, and the probe says so', () async {
      final keys = MemoryKeyStore();
      final s = await open(AtRestPolicy.plain, keys);
      await seed(s, 'Plain');
      await s.db.close();
      expect(isPlainSqliteFile(file), isTrue);
      expect(keys.writes, 0);
      expect(await fileCipherProbe(file)(), isNull);

      // StorageSecurity then reports the tracked exception (non-silent).
      final status = await const StorageSecurity(
              platform: StoragePlatform.windows)
          .evaluate(fileCipherProbe(file));
      expect(status.encrypted, isFalse);
      expect(status.isTrackedException, isTrue);
    });

    test('refuses to open an encrypted file rather than downgrade it',
        () async {
      final s = await open(AtRestPolicy.encrypt, MemoryKeyStore());
      await seed(s, 'Encrypted');
      await s.db.close();
      final before = file.readAsBytesSync();
      await expectLater(open(AtRestPolicy.plain, MemoryKeyStore()),
          throwsA(isA<StoreUnavailable>()));
      expect(file.readAsBytesSync(), before);
    });
  });

  test('atRestPolicyFor follows ADR-0021', () {
    expect(atRestPolicyFor(StoragePlatform.android), AtRestPolicy.encrypt);
    expect(atRestPolicyFor(StoragePlatform.windows), AtRestPolicy.plain);
    expect(atRestPolicyFor(StoragePlatform.other), AtRestPolicy.encrypt);
  });

  test('isPlainSqliteFile treats a missing or empty file as plain', () {
    expect(isPlainSqliteFile(file), isTrue);
    file.writeAsBytesSync(const []);
    expect(isPlainSqliteFile(file), isTrue);
  });
}
