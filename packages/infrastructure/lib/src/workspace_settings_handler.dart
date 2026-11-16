// P04 T1 (schema v10, ADR-0053): the settings of a workspace that sync with
// it (p04-plan.md D4). One row per workspace, its id the workspace id; the
// first change creates it. Through the gateway like every change, so the
// row gets its audit, outbox and event-log rows (FF-ARCH-06).
//
// Supported ops (payload['op']):
//   setManualResults : id (workspace id), value ('target' | 'tick')
//                      P03 UX U6 (U-D13, ADR-0050)
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';

class WorkspaceSettingsCommandHandler implements CommandHandler {
  const WorkspaceSettingsCommandHandler();

  @override
  String get entityType => 'workspaceSettings';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await _row(db, cmd.payload['id'] as String);
    return row == null ? null : Version(row.version);
  }

  Future<WorkspaceSetting?> _row(AppDatabase db, String id) =>
      (db.select(db.workspaceSettings)..where((s) => s.id.equals(id))).getSingleOrNull();

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    if (id != cmd.workspaceId) throw DomainRejection('settings belong to their own workspace');
    switch (op) {
      case 'setManualResults':
        final v = cmd.payload['value'];
        if (v != 'target' && v != 'tick') throw DomainRejection('unknown result policy');
        final row = await _row(db, id);
        if ((row?.manualResults ?? 'target') == v) throw DomainRejection('the result policy is already $v');
        final now = DateTime.now().toUtc();
        final ws = await (db.select(db.workspaces)..where((w) => w.id.equals(id))).getSingleOrNull();
        if (ws == null) throw DomainRejection('workspace not found');
        await db.into(db.workspaceSettings).insertOnConflictUpdate(WorkspaceSettingsCompanion.insert(
              id: id,
              workspaceId: id,
              ownerId: ws.ownerId,
              version: Value(newVersion.value),
              createdAt: row?.createdAt ?? now,
              updatedAt: now,
              manualResults: Value(v as String),
            ));
        return HandlerOutcome(
          entityId: id,
          operationType: row == null ? 'create' : 'update',
          changeSet: {'id': id, 'manualResults': v},
          events: [DomainEvent('ManualResultsChanged', {'workspaceId': id, 'value': v})],
        );
      default:
        throw DomainRejection('unknown op: $op');
    }
  }
}

/// The result policy of [workspaceId] ('target' without a settings row).
Future<bool> ticksAreResults(AppDatabase db, String workspaceId) async =>
    (await (db.select(db.workspaceSettings)..where((s) => s.id.equals(workspaceId) & s.deletedAt.isNull()))
            .getSingleOrNull())
        ?.manualResults ==
    'tick';
