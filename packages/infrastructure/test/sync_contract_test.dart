// P04 T1 (schema v10, ADR-0053): what sync needs from the store.
//   outbox      every record an operation writes has an outbox row of its
//               own, named by its record kind (all operations: the check in
//               atomic_set_test.dart); here the ended focus session's record
//   settings    the result policy (U-D13) is a setting of the workspace, a
//               record that syncs: made by the first change, then updated
//   export      settings travel in the file; a v9 file's profile policy
//               becomes the workspace's; bad settings are refused; the sync
//               bookkeeping (sync_base, sync_state) is not exported
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'profile_harness.dart';

class _Time implements DeviceTime {
  @override
  Instant now() => Instant.now();
  @override
  String zone() => 'UTC';
}

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late DriftCommandGateway gw;
  late DriftHabitService habits;
  late DriftHabitQueries queries;
  late DriftDataTransferService transfer;
  late String ws;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_sync_contract_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    habits = DriftHabitService(host.db, gw, _Time());
    queries = DriftHabitQueries(host.db, _Time());
    transfer = DriftDataTransferService(host.db, dir);
    ws = (await ProfileStore(host.db).getActiveProfile())!.activeWorkspaceId.value;
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: '$r');
    return (r as CommandOk).entityId;
  }

  Future<List<OutboxData>> outboxOf(String type, String id) =>
      (host.db.select(host.db.outbox)..where((o) => o.entityType.equals(type) & o.entityId.equals(id))).get();

  Map<String, Object?> payloadOf(String text) =>
      ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();

  test('an ended focus session\'s record has an outbox row of its own', () async {
    final focus = DriftFocusService(host.db, gw);
    final s = ok(await focus.start(mode: FocusSessionMode.stopwatch));
    ok(await focus.end(s, count: true));
    final rec = (await host.db.select(host.db.executionRecords).get()).single;
    final rows = await outboxOf('executionRecord', rec.id);
    expect(rows, hasLength(1));
    expect(rows.single.operationType, 'create');
    expect(ExecutionRecordRow.fromJson(jsonDecode(rows.single.payload) as Map<String, dynamic>).id, rec.id,
        reason: 'the payload is the record');
    // The same operation also wrote the session's own row.
    expect((await outboxOf('focusSession', s)).map((o) => o.operationId), contains(rows.single.operationId));
  });

  test('the result policy is a workspace setting: the first change makes it, the next updates it', () async {
    expect(await queries.manualResults(), ManualResults.target);
    expect(await host.db.select(host.db.workspaceSettings).get(), isEmpty, reason: 'no row is the default');
    ok(await habits.setManualResults(ManualResults.tick));
    var row = (await host.db.select(host.db.workspaceSettings).get()).single;
    expect((row.id, row.workspaceId, row.manualResults, row.version), (ws, ws, 'tick', 1));
    expect(await queries.manualResults(), ManualResults.tick);
    expect((await outboxOf('workspaceSettings', ws)).single.operationType, 'create');

    final again = await habits.setManualResults(ManualResults.tick);
    expect(again, isA<CommandFailure>(), reason: 'no change');
    ok(await habits.setManualResults(ManualResults.target));
    row = (await host.db.select(host.db.workspaceSettings).get()).single;
    expect((row.manualResults, row.version), ('target', 2));
    expect([for (final o in await outboxOf('workspaceSettings', ws)) o.operationType], ['create', 'update']);
    // The legacy profile column is not written any more.
    expect((await host.db.select(host.db.profiles).get()).single.manualResults, 'target');
  });

  test('settings are only written for the command\'s own workspace', () async {
    final p = (await ProfileStore(host.db).getActiveProfile())!;
    // Another workspace in the store (as shared workspaces will be, P04b).
    await host.db.into(host.db.workspaces).insert(WorkspacesCompanion.insert(
        id: 'another-workspace', ownerId: p.profileId.value, createdAt: DateTime.now()));
    final r = await gw.execute(
        Command(
          operationId: 'other-ws',
          actor: ActorRef(ActorKind.owner, p.profileId.value),
          workspaceId: ws,
          type: 'SetManualResults',
          payload: {'op': 'setManualResults', 'id': 'another-workspace', 'value': 'tick'},
          issuedAt: Instant.now(),
        ),
        const WorkspaceSettingsCommandHandler());
    expect(r, isA<CommandFailure>());
    expect(await host.db.select(host.db.workspaceSettings).get(), isEmpty);
  });

  test('export: settings travel; sync bookkeeping does not; a clean install keeps the policy', () async {
    ok(await habits.setManualResults(ManualResults.tick));
    await host.db.into(host.db.syncState).insert(SyncStateCompanion.insert(workspaceId: ws, deviceId: 'pc'));
    final file = await transfer.exportActiveProfile();
    final payload = payloadOf(file.contents);
    expect((payload['workspaceSettings'] as List).single, containsPair('manualResults', 'tick'));
    expect(payload.containsKey('syncState') || payload.containsKey('syncBase'), isFalse);

    final b = Directory.systemTemp.createTempSync('lifeflow_sync_contract_clean_');
    final clean = await openDirectory(b, MemoryKeys());
    addTearDown(() async {
      await clean.close();
      b.deleteSync(recursive: true);
    });
    final h = TestHost(clean);
    await h.openActive();
    addTearDown(h.close);
    expect(await DriftDataTransferService(h.db, clean).restore(file.contents), isA<Restored>());
    final store = await clean.openProfile(host.currentId!);
    addTearDown(store.db.close);
    expect(await DriftHabitQueries(store.db, _Time()).manualResults(), ManualResults.tick);
    expect(await store.db.select(store.db.syncState).get(), isEmpty);
  });

  test('a v9 file: the profile\'s policy becomes the workspace\'s setting', () async {
    final payload = payloadOf((await transfer.exportActiveProfile()).contents);
    payload.remove('workspaceSettings');
    final profile = (payload['profiles'] as List).cast<Map>().single;
    profile['manualResults'] = 'tick';
    // As a v9 build wrote it: no settings table, so no count for it either.
    String v9() {
      final env = jsonDecode(ProfileExport.seal(payload, schemaVersion: 9)) as Map<String, dynamic>;
      (env['counts'] as Map).remove('workspaceSettings');
      return jsonEncode(env);
    }

    final parsed = ProfileExport.parse(v9(), currentSchemaVersion: AppDatabase.currentSchemaVersion);
    final s = parsed.records['workspaceSettings']!.single;
    expect((s['id'], s['workspaceId'], s['ownerId'], s['manualResults']), (ws, ws, profile['id'], 'tick'));

    profile['manualResults'] = 'target';
    final plain = ProfileExport.parse(v9(), currentSchemaVersion: AppDatabase.currentSchemaVersion);
    expect(plain.records['workspaceSettings'], isEmpty, reason: 'the default needs no row');
  });

  test('untrusted settings in a file are refused (SR-14)', () async {
    ok(await habits.setManualResults(ManualResults.tick));
    final payload = payloadOf((await transfer.exportActiveProfile()).contents);
    final row = (payload['workspaceSettings'] as List).cast<Map>().single;
    void refused(String mentions) => expect(
        () => ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: AppDatabase.currentSchemaVersion),
            currentSchemaVersion: AppDatabase.currentSchemaVersion),
        throwsA(isA<ExportRejected>().having((e) => e.message, 'message', contains(mentions))));
    row['manualResults'] = 'maybe';
    refused('result policy');
    row
      ..['manualResults'] = 'tick'
      ..['id'] = 'another';
    refused('another workspace');
    row
      ..['id'] = 'elsewhere'
      ..['workspaceId'] = 'elsewhere';
    refused('unknown workspace');
  });
}
