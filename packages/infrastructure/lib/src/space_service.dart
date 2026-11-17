// P04b T8 (ADR-0060; p04b-plan.md B1): the spaces of the active profile's
// store and the one shown. Showing another space is one command on the
// profile (ProfileCommandHandler 'switchSpace'), through the gateway.
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart' hide Workspace;
import 'profile_command_handler.dart';
import 'profile_store.dart';
import 'workspace_settings_handler.dart' show spaceNameOf;

class DriftSpaceService implements SpaceService {
  DriftSpaceService(this.db, this.gateway) : _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore _store;

  @override
  Future<List<SpaceView>> spaces() async {
    final p = await _store.getActiveProfile();
    if (p == null) return const [];
    final account = p.binding?.accountId;
    final out = <SpaceView>[];
    for (final w in await _store.workspaces()) {
      if (!w.shared) {
        if (w.ownerId != p.profileId.value) continue;
        out.add(SpaceView(id: w.id, shared: false, isShown: w.id == p.activeWorkspaceId.value));
        continue;
      }
      // P04b T12: the name the owner gave it (synced, sealed), else the cache.
      final name = await spaceNameOf(db, w.id) ?? w.name;
      final changed = w.rulesChangedAt != null && (w.rulesSeenAt == null || w.rulesSeenAt!.isBefore(w.rulesChangedAt!));
      if (w.leftAt != null) {
        // What its leaving rule left here (B8).
        out.add(SpaceView(
          id: w.id,
          shared: true,
          isShown: w.id == p.activeWorkspaceId.value,
          name: name,
          role: SpaceRole.viewer,
          left: w.leftKeep == 'readOnly' ? SpaceLeft.readOnly : SpaceLeft.exportFirst,
        ));
        continue;
      }
      final members = await _store.members(w.id);
      final me = members.where((m) => m.accountId == account && m.status == 'active').firstOrNull;
      if (me == null) continue; // waiting for approval, or no longer a member
      out.add(SpaceView(
        id: w.id,
        shared: true,
        isShown: w.id == p.activeWorkspaceId.value,
        name: name,
        role: SpaceRole.values.where((r) => r.name == me.role).firstOrNull,
        members: members.where((m) => m.status == 'active').length,
        rulesChanged: changed,
      ));
    }
    return out;
  }

  @override
  Future<CommandResult> show(String spaceId) async {
    final p = await _store.getActiveProfile();
    final ctx = await _store.personalContext();
    if (p == null || ctx == null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    }
    final row = await (db.select(db.profiles)..where((x) => x.id.equals(p.profileId.value))).getSingle();
    return gateway.execute(
      Command(
        operationId: const Uuid().v7(),
        actor: ctx.actor,
        workspaceId: ctx.workspaceId,
        type: 'ShowSpace',
        payload: {'op': 'switchSpace', 'id': p.profileId.value, 'workspaceId': spaceId},
        expectedVersion: Version(row.version),
        issuedAt: Instant.now(),
      ),
      const ProfileCommandHandler(),
    );
  }
}
