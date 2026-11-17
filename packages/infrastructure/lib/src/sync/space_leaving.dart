// P04b T12 (ADR-0064; p04b-plan.md B8): what stays on this device when its
// account is no longer in a shared space (it left, was removed, or the space
// was deleted). The server decided (SHARE-003); this only follows its
// leaving rule, set by the owner and known to every member:
//   disappear            the space's data goes from this device
//   disappearWithExport  it is hidden and kept until the person exported it
//                        (once) or let it go
//   keepReadOnly         a read-only copy of what there was stays; nothing
//                        changes it any more
// Nothing of this is sent anywhere: the records are not deleted, they are
// let go from this device (no outbox rows, the waiting changes set aside).
// If the space is shown, the personal workspace is shown first (a command).
import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart' hide Workspace;
import '../profile_command_handler.dart';
import '../profile_store.dart';
import '../record_kinds.dart';
import 'workspace_keyring.dart';

/// Applies [workspaceId]'s leaving rule here; [forget] lets it go whatever
/// the rule (rule (b) after the export, or "remove this copy").
Future<void> leaveSpaceHere(AppDatabase db, CommandGateway gateway, WorkspaceKeyring keyring, String workspaceId,
    {bool forget = false}) async {
  final ws = await (db.select(db.workspaces)..where((w) => w.id.equals(workspaceId))).getSingleOrNull();
  if (ws == null || ws.kind != 'shared') return;
  if (ws.leftAt != null && !forget) return; // already applied
  final store = ProfileStore(db);
  final profile = await store.getActiveProfile();
  final rule = forget ? 'disappear' : (ws.leaveRule ?? 'disappear');
  final keepCopy = rule == 'keepReadOnly';
  if (profile != null && profile.activeWorkspaceId.value == workspaceId && !keepCopy) {
    final personal = await store.personalContext();
    final row = await (db.select(db.profiles)..where((p) => p.id.equals(profile.profileId.value))).getSingle();
    if (personal != null) {
      await gateway.execute(
        Command(
          operationId: const Uuid().v7(),
          actor: personal.actor,
          workspaceId: personal.workspaceId,
          type: 'ShowSpace',
          payload: {'op': 'switchSpace', 'id': profile.profileId.value, 'workspaceId': personal.workspaceId},
          expectedVersion: Version(row.version),
          issuedAt: Instant.now(),
        ),
        const ProfileCommandHandler(),
      );
    }
  }
  await db.transaction(() async {
    await (db.delete(db.syncState)..where((s) => s.workspaceId.equals(workspaceId))).go();
    await (db.delete(db.spaceMembers)..where((m) => m.workspaceId.equals(workspaceId))).go();
    await (db.delete(db.syncBase)..where((b) => b.workspaceId.equals(workspaceId))).go();
    await (db.delete(db.syncParked)..where((b) => b.workspaceId.equals(workspaceId))).go();
    await (db.delete(db.syncReviews)..where((r) => r.workspaceId.equals(workspaceId))).go();
    if (rule == 'disappear') {
      for (final k in recordKinds) {
        await db.customStatement('DELETE FROM ${k.tableName} WHERE workspace_id = ?', [workspaceId]);
      }
      await (db.delete(db.outbox)..where((o) => o.workspaceId.equals(workspaceId))).go();
      await (db.delete(db.workspaces)..where((w) => w.id.equals(workspaceId))).go();
    } else {
      await db.customStatement("UPDATE outbox SET status = 'local' WHERE status = 'pending' AND workspace_id = ?", [workspaceId]);
      await (db.update(db.workspaces)..where((w) => w.id.equals(workspaceId))).write(WorkspacesCompanion(
          leftAt: Value(DateTime.now().toUtc()), leftKeep: Value(keepCopy ? 'readOnly' : 'exportFirst')));
    }
  });
  await keyring.forget(workspaceId);
}
