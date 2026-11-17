// P04 T4 (ADR-0057, p04-plan.md D5, D11): turning sync on and off for a
// profile's store, as commands through the gateway (GOV-001).
//   turnOn    this device starts syncing its workspace: its sync state, and
//             an outbox row for every record so the first sync uploads all
//   join      this device joins the account's workspace (another id). A
//             snapshot of the store comes first, for undo. Its records move
//             into the account's workspace keeping their ids; then either
//             they are all uploaded (merge, the default) or they are removed
//             here (use the account's data only; saved to a file first by
//             the service) and the account's data comes down
//   undoJoin  the store as it was before the join; sync off
//   turnOff   sync state, last synced copies and review items go; the data
//             stays
// Payload: {op, id: the command's workspace, deviceId?, accountWorkspaceId?,
// mode?: 'merge' | 'replace'}
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../command_gateway.dart';
import '../profile_export.dart';
import '../record_kinds.dart';

/// The restore snapshot that undoes a join (kept apart from a restore's).
const syncJoinSnapshotId = 'sync-join';

const turnSyncOnAction = 'TurnSyncOn';
const joinSyncAction = 'JoinSyncedWorkspace';
const undoSyncJoinAction = 'UndoSyncJoin';
const turnSyncOffAction = 'TurnSyncOff';

class SyncSetupHandler implements CommandHandler {
  const SyncSetupHandler();

  @override
  String get entityType => 'syncSetup';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async => null;

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final p = cmd.payload;
    final ws = p['id'] as String;
    if (ws != cmd.workspaceId) throw DomainRejection('sync setup of another workspace');
    final now = DateTime.now().toUtc();
    // P04b T8 (ADR-0060): personal sync is of the personal workspace, even
    // while a shared space is shown.
    final wsRow = await (db.select(db.workspaces)..where((w) => w.id.equals(ws))).getSingleOrNull();
    if (wsRow == null || wsRow.kind != 'personal') throw DomainRejection('not this profile\'s workspace');
    final profile = await (db.select(db.profiles)..where((x) => x.id.equals(wsRow.ownerId))).getSingleOrNull();
    if (profile == null) throw DomainRejection('not this profile\'s workspace');
    final state = await (db.select(db.syncState)..where((s) => s.workspaceId.equals(ws))).getSingleOrNull();

    switch (p['op']) {
      case 'turnOn':
        if (state != null) throw DomainRejection('sync is already on');
        await db.into(db.syncState).insert(SyncStateCompanion.insert(workspaceId: ws, deviceId: _device(p)));
        final n = await _uploadAll(db, cmd, ws, now);
        return _outcome(ws, 'SyncTurnedOn', {'records': n});

      case 'join':
        if (state != null) throw DomainRejection('sync is already on');
        final target = p['accountWorkspaceId'] as String;
        final mode = p['mode'];
        if (mode != 'merge' && mode != 'replace') throw DomainRejection('unknown join mode');
        if (target == ws) throw DomainRejection('this is already the account\'s workspace');
        // Undo copy first, in the same transaction (as a restore keeps one).
        final before = ProfileExport.seal(await ProfileExport.payloadOf(db), schemaVersion: db.schemaVersion, now: now);
        await db.delete(db.restoreSnapshots).go();
        await db.into(db.restoreSnapshots).insert(RestoreSnapshotsCompanion.insert(
            id: syncJoinSnapshotId, operationId: cmd.operationId, createdAt: now, exportText: before));
        await _rehome(db, from: ws, to: target, owner: profile.id);
        await (db.delete(db.syncBase)..where((b) => b.workspaceId.isIn([ws, target]))).go();
        await (db.delete(db.syncReviews)..where((r) => r.workspaceId.isIn([ws, target]))).go();
        await db.into(db.syncState).insert(SyncStateCompanion.insert(workspaceId: target, deviceId: _device(p)));
        var n = 0;
        if (mode == 'replace') {
          for (final k in recordKinds) {
            await db.customStatement('DELETE FROM ${k.tableName} WHERE workspace_id = ?', [target]);
          }
          await db.customStatement(
              "UPDATE outbox SET status = 'local' WHERE status = 'pending' AND workspace_id = ?", [target]);
        } else {
          n = await _uploadAll(db, cmd, target, now, workspaceOfCommand: ws);
        }
        return _outcome(ws, 'SyncJoined', {'into': target, 'mode': mode, 'records': n});

      case 'undoJoin':
        final snap = await (db.select(db.restoreSnapshots)..where((s) => s.id.equals(syncJoinSnapshotId)))
            .getSingleOrNull();
        if (snap == null) throw DomainRejection('there is no join to undo');
        final ParsedExport file;
        try {
          file = ProfileExport.parse(snap.exportText, currentSchemaVersion: db.schemaVersion);
        } on ExportRejected catch (e) {
          throw DomainRejection(e.message);
        }
        final old = file.profile.activeWorkspaceId;
        for (final k in recordKinds) {
          await db.customStatement('DELETE FROM ${k.tableName} WHERE workspace_id = ?', [ws]);
        }
        await db.batch((b) {
          b.insertAll(db.workspaces, file.workspaces, mode: InsertMode.insertOrIgnore);
          for (final k in recordKinds) {
            k.upsert(b, db, file.records[k.name] ?? const []);
          }
        });
        // The profile shows its personal workspace again, unless a shared
        // space is shown.
        await db.customStatement(
            'UPDATE profiles SET active_workspace_id = ? WHERE id = ? AND active_workspace_id = ?', [old, profile.id, ws]);
        await db.customStatement('UPDATE outbox SET workspace_id = ? WHERE workspace_id = ?', [old, ws]);
        await db.customStatement('UPDATE op_dedupe SET workspace_id = ? WHERE workspace_id = ?', [old, ws]);
        await db.customStatement("UPDATE outbox SET status = 'local' WHERE status = 'pending' AND workspace_id = ?", [old]);
        // Every restored record has its outbox row (LF-INV-OUTBOX-001); sync
        // is off, so nothing is sent.
        await _uploadAll(db, cmd, old, now, status: 'local');
        await (db.delete(db.workspaces)..where((w) => w.id.equals(ws))).go();
        await (db.delete(db.syncState)..where((s) => s.workspaceId.equals(ws))).go();
        await (db.delete(db.syncBase)..where((b) => b.workspaceId.isIn([ws, old]))).go();
        await (db.delete(db.syncReviews)..where((r) => r.workspaceId.isIn([ws, old]))).go();
        await (db.delete(db.restoreSnapshots)..where((s) => s.id.equals(syncJoinSnapshotId))).go();
        return _outcome(ws, 'SyncJoinUndone', {'back': old});

      case 'turnOff':
        if (state == null) throw DomainRejection('sync is not on');
        await (db.delete(db.syncState)..where((s) => s.workspaceId.equals(ws))).go();
        await (db.delete(db.syncBase)..where((b) => b.workspaceId.equals(ws))).go();
        await (db.delete(db.syncReviews)..where((r) => r.workspaceId.equals(ws))).go();
        await db.customStatement(
            "UPDATE outbox SET status = 'local' WHERE status IN ('pending', 'failed') AND workspace_id = ?", [ws]);
        // A join can no longer be undone once sync is off.
        await (db.delete(db.restoreSnapshots)..where((s) => s.id.equals(syncJoinSnapshotId))).go();
        return _outcome(ws, 'SyncTurnedOff', const {});

      default:
        throw DomainRejection('unknown op');
    }
  }

  String _device(Map<String, Object?> p) {
    final d = p['deviceId'];
    if (d is! String || d.isEmpty || d.length > 64) throw DomainRejection('bad device id');
    return d;
  }

  /// Moves every row of [from] into [to], keeping record ids; the profile's
  /// workspace becomes [to] (records' owner ids stay as they were made).
  Future<void> _rehome(AppDatabase db, {required String from, required String to, required String owner}) async {
    await db.into(db.workspaces).insertOnConflictUpdate(WorkspacesCompanion.insert(
        id: to, kind: const Value('personal'), ownerId: owner, createdAt: DateTime.now().toUtc()));
    for (final k in recordKinds) {
      await db.customStatement('UPDATE ${k.tableName} SET workspace_id = ? WHERE workspace_id = ?', [to, from]);
    }
    // The settings record is keyed by its workspace (ADR-0053).
    await db.customStatement('UPDATE workspace_settings SET id = ? WHERE id = ?', [to, from]);
    await db.customStatement('UPDATE outbox SET workspace_id = ? WHERE workspace_id = ?', [to, from]);
    await db.customStatement('UPDATE op_dedupe SET workspace_id = ? WHERE workspace_id = ?', [to, from]);
    await db.customStatement('UPDATE profiles SET active_workspace_id = ? WHERE active_workspace_id = ?', [to, from]);
    await (db.delete(db.workspaces)..where((w) => w.id.equals(from))).go();
  }

  /// An outbox row (pending) for every record of [ws]: the first sync
  /// uploads them all.
  Future<int> _uploadAll(AppDatabase db, Command cmd, String ws, DateTime now,
      {String? workspaceOfCommand, String status = 'pending'}) async {
    var n = 0;
    for (final k in recordKinds) {
      for (final r in await k.readAll(db)) {
        if (r['workspaceId'] != ws) continue;
        await db.into(db.outbox).insert(
            OutboxCompanion.insert(
              operationId: cmd.operationId,
              entityId: r['id'] as String,
              entityType: k.name,
              workspaceId: ws,
              actorId: cmd.actor.toString(),
              operationType: 'create',
              payload: jsonEncode({'id': r['id'], 'upload': true}),
              createdAt: now,
              status: Value(status),
            ),
            mode: InsertMode.insertOrIgnore);
        n++;
      }
    }
    return n;
  }

  // Not the workspace id itself: the settings record has that id, and its
  // outbox row may be under the same operation.
  HandlerOutcome _outcome(String ws, String event, Map<String, Object?> data) => HandlerOutcome(
        entityId: 'sync:$ws',
        operationType: 'update',
        changeSet: {'id': ws, ...data},
        events: [DomainEvent(event, {'workspaceId': ws, ...data})],
      );
}

/// A new device id for sync (random; not tied to the hardware).
String newSyncDeviceId() => const Uuid().v4();
