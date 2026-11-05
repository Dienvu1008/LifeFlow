// THROWAWAY spike S-01. Headless check of CRUD + transaction + rollback on an
// in-memory Drift NativeDatabase. This runs under `flutter test` without a
// device; it verifies the Drift logic. Platform build/run on Windows+Android
// is verified separately by the owner (see RUNBOOK).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s01_drift_spike/database.dart';

void main() {
  late SpikeDb db;

  setUp(() => db = SpikeDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('create in a transaction, then read', () async {
    await db.createDeckWithCards('d1', 'Deck 1');
    expect((await db.allDecks()).length, 1);
    expect(await db.countCards(), 2);
  });

  test('failing transaction rolls back entirely', () async {
    try {
      await db.transaction(() async {
        await db.into(db.decks).insert(
            DecksCompanion.insert(id: 'dup', title: 'first'));
        await db.into(db.decks).insert(
            DecksCompanion.insert(id: 'dup', title: 'second')); // PK clash
      });
      fail('expected the duplicate insert to throw');
    } catch (_) {
      // expected
    }
    // Nothing from the failed transaction should persist.
    expect((await db.allDecks()).where((d) => d.id == 'dup'), isEmpty);
  });
}
