import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

// Hide Drift's generated `Workspace` row class so the domain `Workspace`
// (returned by getPersonalWorkspace) is unambiguous. Table access still works
// via db.workspaces.
import 'app_database.dart' hide Workspace;

/// Device-local profile read/bootstrap, scoped so one profile's data is never
/// visible to another (LF-INV-ID-002). None of these methods touch the auth
/// gateway or the network: the read path works offline (LF-INV-SEC-002).
class ProfileStore {
  ProfileStore(this.db);
  final AppDatabase db;

  /// First-launch bootstrap (CreateLocalProfile, workspace-and-access.md §6).
  /// Idempotent: if a profile already exists, returns it; otherwise creates a
  /// LocalProfile + its single Personal Workspace, both active. No actor and
  /// no authorization are involved (this runs before any account exists).
  Future<LocalProfile> ensureFirstProfile({String displayName = ''}) async {
    final existing = await getActiveProfile();
    if (existing != null) return existing;

    // A pre-existing (inactive) profile means the app already bootstrapped;
    // activate the earliest one rather than creating a duplicate.
    final any = await (db.select(db.profiles)
          ..orderBy([(p) => OrderingTerm(expression: p.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    if (any != null) {
      await _setActive(any.id);
      return _toDomain(any.copyWith(isActive: true));
    }

    final profileId = EntityId.generate();
    final workspaceId = EntityId.generate();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
            id: workspaceId.value,
            ownerId: profileId.value, // the profile owns its workspace
            createdAt: now,
          ));
      await db.into(db.profiles).insert(ProfilesCompanion.insert(
            id: profileId.value,
            activeWorkspaceId: workspaceId.value,
            displayName: Value(displayName),
            isActive: const Value(true),
            createdAt: now,
          ));
    });
    return LocalProfile(
      profileId: profileId,
      activeWorkspaceId: workspaceId,
      displayName: displayName,
    );
  }

  /// The active profile (the one the UI is showing), or null before bootstrap.
  Future<LocalProfile?> getActiveProfile() async {
    final row = await (db.select(db.profiles)
          ..where((p) => p.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// All profiles on the device (for the profile chooser after sign-out).
  Future<List<LocalProfile>> listProfiles() async {
    final rows = await (db.select(db.profiles)
          ..orderBy([(p) => OrderingTerm(expression: p.createdAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// The Personal Workspace owned by [profileId].
  Future<Workspace?> getPersonalWorkspace(String profileId) async {
    final row = await (db.select(db.workspaces)
          ..where((w) => w.ownerId.equals(profileId))
          ..limit(1))
        .getSingleOrNull();
    return row == null
        ? null
        : Workspace(
            workspaceId: EntityId(row.id),
            ownerId: row.ownerId,
            kind: row.kind,
          );
  }

  Future<void> _setActive(String profileId) async {
    await db.transaction(() async {
      await db.update(db.profiles).write(const ProfilesCompanion(
            isActive: Value(false),
          ));
      await (db.update(db.profiles)..where((p) => p.id.equals(profileId)))
          .write(const ProfilesCompanion(isActive: Value(true)));
    });
  }

  LocalProfile _toDomain(Profile row) => LocalProfile(
        profileId: EntityId(row.id),
        activeWorkspaceId: EntityId(row.activeWorkspaceId),
        displayName: row.displayName,
        binding: (row.accountId != null && row.accountProvider != null)
            ? AccountBinding(
                accountId: row.accountId!,
                provider: AccountProvider.fromName(row.accountProvider!),
                boundAt: Instant(row.createdAt), // bind time not separately stored in MVP
              )
            : null,
      );
}
