// THROWAWAY spike S-01. A minimal Drift database with two tables to prove
// Flutter + Drift NativeDatabase on Windows and Android with bundled sqlite3.
//
// Table names avoid Dart core names (e.g. not `Lists`, whose row class would
// shadow `List`). We use Decks/Cards as neutral, unambiguous names.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get label => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Decks, Cards])
class SpikeDb extends _$SpikeDb {
  SpikeDb() : super(driftDatabase(name: 's01_spike'));

  // Test seam: pass an in-memory executor for a quick headless check.
  SpikeDb.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // Enforce foreign keys (off by default in sqlite). P01 will need this.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Creates a deck and two cards in ONE transaction (atomicity check).
  Future<void> createDeckWithCards(String deckId, String title) {
    return transaction(() async {
      await into(decks).insert(DecksCompanion.insert(id: deckId, title: title));
      await into(cards).insert(
          CardsCompanion.insert(id: '$deckId-a', deckId: deckId, label: 'card A'));
      await into(cards).insert(
          CardsCompanion.insert(id: '$deckId-b', deckId: deckId, label: 'card B'));
    });
  }

  Future<List<Deck>> allDecks() => select(decks).get();

  Future<int> countCards() async => (await select(cards).get()).length;

  /// Clears all rows (test convenience).
  Future<void> clearAll() => transaction(() async {
        await delete(cards).go();
        await delete(decks).go();
      });
}
