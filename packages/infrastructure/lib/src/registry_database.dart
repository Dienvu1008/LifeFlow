// P01 T6c (SR-03, ADR-0023): the device-level profile registry. Each
// LocalProfile has its own database file and key; this small database only
// lists the profiles on the device (for the chooser and account lookup) and
// remembers which one is active. It holds no user content. Encrypted with its
// own key under the same at-rest policy as the profile stores.
import 'package:drift/drift.dart';

part 'registry_database.g.dart';

@DataClassName('RegistryProfile')
class RegistryProfiles extends Table {
  TextColumn get id => text()(); // profileId (UUID v7), same id as in its store
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get accountId => text().nullable()(); // non-secret (OQ-WA-1)
  TextColumn get accountProvider => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  // Mirrors the profile store (ADR-0024): locked until its account signs in.
  BoolColumn get signedOut => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Small key/value facts about the device layout (e.g. that the pre-SR-03
/// shared database was migrated).
class RegistryMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [RegistryProfiles, RegistryMeta])
class RegistryDatabase extends _$RegistryDatabase {
  RegistryDatabase(super.e);

  /// v1 (T6c) initial; v2 (T6c, ADR-0024) registry_profiles.signed_out.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(registryProfiles, registryProfiles.signedOut);
          }
        },
      );
}
