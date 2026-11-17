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

  /// Initializes an EMPTY store as the store of one profile with the given ids
  /// (SR-03: one profile per store). Used when the directory creates a new
  /// profile, including a "new space" whose ids [ProfileBinder] chose.
  /// Throws [StateError] if the store already holds a profile.
  Future<LocalProfile> createProfile({
    required EntityId profileId,
    required EntityId workspaceId,
    String displayName = '',
  }) async {
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      final existing = await db.select(db.profiles).get();
      if (existing.isNotEmpty) {
        throw StateError('this store already belongs to a profile');
      }
      await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
            id: workspaceId.value,
            ownerId: profileId.value,
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
          ..where((w) => w.ownerId.equals(profileId) & w.kind.equals('personal'))
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

  /// P04b T8 (ADR-0060): the id of the active profile's personal workspace,
  /// whichever space is being shown. Sync, export and restore, reminders,
  /// focus and closing habit periods work on it.
  Future<String?> personalWorkspaceId() async {
    final p = await getActiveProfile();
    if (p == null) return null;
    return (await getPersonalWorkspace(p.profileId.value))?.workspaceId.value;
  }

  /// P04b T8: the workspace a command of the user acts on (the one being
  /// shown) and who acts there: the profile in its personal workspace, the
  /// account as a [ActorKind.member] in a shared space.
  Future<CommandContext?> commandContext() async {
    final p = await getActiveProfile();
    if (p == null) return null;
    final ws = p.activeWorkspaceId.value;
    final row = await (db.select(db.workspaces)..where((w) => w.id.equals(ws))).getSingleOrNull();
    if (row != null && row.kind == 'shared') {
      return CommandContext(ws, ActorRef(ActorKind.member, p.binding?.accountId ?? ''), shared: true);
    }
    return CommandContext(ws, ActorRef(ActorKind.owner, p.profileId.value));
  }

  /// The personal workspace's context, whichever space is shown.
  Future<CommandContext?> personalContext() async {
    final p = await getActiveProfile();
    final ws = await personalWorkspaceId();
    if (p == null || ws == null) return null;
    return CommandContext(ws, ActorRef(ActorKind.owner, p.profileId.value));
  }

  /// Every workspace of the store: the personal one first, then the shared
  /// spaces by name.
  Future<List<WorkspaceInfo>> workspaces() async {
    final rows = [
      for (final r in await db.select(db.workspaces).get())
        WorkspaceInfo(id: r.id, shared: r.kind == 'shared', name: r.name, ownerId: r.ownerId,
            leaveRule: r.leaveRule, exportRule: r.exportRule, rulesChangedAt: r.rulesChangedAt, rulesSeenAt: r.rulesSeenAt,
            leftAt: r.leftAt, leftKeep: r.leftKeep)
    ];
    rows.sort((a, b) {
      if (a.shared != b.shared) return a.shared ? 1 : -1;
      return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
    });
    return rows;
  }

  /// The cached members of [workspaceId] (shared spaces only).
  Future<List<SpaceMemberRow>> members(String workspaceId) =>
      (db.select(db.spaceMembers)..where((m) => m.workspaceId.equals(workspaceId))).get();

  Future<void> _setActive(String profileId) async {
    await db.transaction(() async {
      await db.update(db.profiles).write(const ProfilesCompanion(
            isActive: Value(false),
          ));
      await (db.update(db.profiles)..where((p) => p.id.equals(profileId)))
          .write(const ProfilesCompanion(isActive: Value(true)));
    });
  }

  /// P04b T8: what the server says about a shared space this account belongs
  /// to, written to the store's cache (LF-INV-SHARE-003: the server decides;
  /// devices only keep a copy). The space's records arrive by its sync.
  /// Called by the space sync (T11/T12) and by tests; never by the UI.
  Future<void> cacheSpace(SpaceSnapshot s) async {
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await db.into(db.workspaces).insertOnConflictUpdate(WorkspacesCompanion.insert(
            id: s.workspaceId,
            kind: const Value('shared'),
            ownerId: s.ownerAccountId,
            createdAt: now,
            name: Value(s.name),
            leaveRule: Value(s.leaveRule),
            exportRule: Value(s.exportRule),
            inviteDefault: Value(s.inviteDefault),
            rulesChangedAt: Value(s.rulesChangedAt),
            // P04b T12: a member again (joined again after leaving).
            leftAt: const Value(null),
            leftKeep: const Value(null),
          ));
      await (db.delete(db.spaceMembers)..where((m) => m.workspaceId.equals(s.workspaceId))).go();
      for (final m in s.members) {
        await db.into(db.spaceMembers).insert(SpaceMembersCompanion.insert(
              workspaceId: s.workspaceId,
              accountId: m.accountId,
              role: m.role,
              status: m.status,
              displayName: Value(m.displayName),
              updatedAt: now,
            ));
      }
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
        signedOut: row.signedOut,
      );
}

/// The workspace and actor of a user command (P04b T8, ADR-0060).
class CommandContext {
  const CommandContext(this.workspaceId, this.actor, {this.shared = false});
  final String workspaceId;
  final ActorRef actor;
  final bool shared;
}

/// A workspace of the store, as the store sees it.
class WorkspaceInfo {
  const WorkspaceInfo({
    required this.id,
    required this.shared,
    required this.ownerId,
    this.name,
    this.leaveRule,
    this.exportRule,
    this.rulesChangedAt,
    this.rulesSeenAt,
    this.leftAt,
    this.leftKeep,
  });
  final String id;
  final bool shared;
  final String ownerId;
  final String? name;
  final String? leaveRule;
  final String? exportRule;
  final DateTime? rulesChangedAt;
  final DateTime? rulesSeenAt;

  /// P04b T12: when the account left it, and what was kept (B8).
  final DateTime? leftAt;
  final String? leftKeep;
}

/// A shared space as the server describes it (cached, LF-INV-SHARE-003).
class SpaceSnapshot {
  const SpaceSnapshot({
    required this.workspaceId,
    required this.ownerAccountId,
    required this.name,
    required this.members,
    this.leaveRule = 'disappear',
    this.exportRule = 'ownerOnly',
    this.inviteDefault = 'approve',
    this.rulesChangedAt,
  });
  final String workspaceId;
  final String ownerAccountId;
  final String name;
  final List<SpaceMemberSnapshot> members;
  final String leaveRule;
  final String exportRule;
  final String inviteDefault;
  final DateTime? rulesChangedAt;
}

class SpaceMemberSnapshot {
  const SpaceMemberSnapshot({required this.accountId, required this.role, this.status = 'active', this.displayName = ''});
  final String accountId;
  final String role; // owner | editor | viewer
  final String status; // pending | active
  final String displayName;
}