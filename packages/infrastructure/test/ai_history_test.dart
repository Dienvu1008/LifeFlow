// P06 T3 (ADR-0082; ADR-0080; the owner's D7, D8): the assistant's history
// and the approval of its proposals, on the real store.
//   history     sessions, messages, proposals: written through the gateway,
//               in the personal space only (also while a shared space is
//               shown); a session goes to the trash with its history
//   GS-15       a change approved after its target changed is stale and
//               nothing is written; regenerated, it applies
//   AI-001      nothing runs without the person's approval; the assistant
//               itself may not run a command
//   AI-002      the versions are read again inside the transaction
//   AI-003      the audit row of an applied change carries its provenance;
//               the actor is the person
//   D8          each change on its own; approve all; dismiss
//   tools       a command the assistant may not use, or arguments it does
//               not take, fail and write nothing
//   sync (D7)   the history syncs sealed to another device; applied wins a
//               merge; a trashed session is trashed there too
//   export      in the file, checked when read; a v17 file reads
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const me = 'acc-me';
const space = '30000000-0000-4000-8000-0000000000aa';

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
  return (r as CommandOk).entityId;
}

ProposedChange rename(String id, String taskId, int version, String title, {Map<RecordRef, int>? versions}) =>
    ProposedChange(
        id: id,
        commandType: 'RenameTask',
        arguments: {'id': taskId, 'title': title},
        versions: versions ?? {RecordRef('task', taskId): version},
        summary: 'Đổi tên thành "$title"');

/// Runs the real handler, then refuses or breaks (a rollback).
class _Breaks implements CommandHandler {
  _Breaks(this.inner, this.error);
  final CommandHandler inner;
  final Object error;
  @override
  String get entityType => inner.entityType;
  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) => inner.currentVersion(tx, cmd);
  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version v) async {
    await inner.apply(tx, cmd, v);
    throw error;
  }
}

/// A gateway where someone else changes things just before an approved
/// change runs (once).
class _Racing implements CommandGateway {
  _Racing(this.inner, this.before);
  final CommandGateway inner;
  Future<CommandResult> Function()? before;
  @override
  Future<CommandResult> execute(Command cmd, CommandHandler handler) async {
    if (cmd.aiProvenance != null && before != null) {
      final b = before!;
      before = null;
      ok(await b());
    }
    return inner.execute(cmd, handler);
  }

  @override
  Future<void> dispatchPendingEvents() => inner.dispatchPendingEvents();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late DriftTaskService tasks;
  late DriftAiHistoryService ai;
  late String personal;
  late String profileId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    final p = await ProfileStore(db).ensureFirstProfile();
    personal = p.activeWorkspaceId.value;
    profileId = p.profileId.value;
    tasks = DriftTaskService(db, gw);
    ai = DriftAiHistoryService(db, gw);
  });
  tearDown(() => db.close());

  Future<int> versionOf(String id) async => (await recordKindByName['task']!.readOne(db, id))!['version'] as int;
  Future<String> titleOf(String id) async => (await recordKindByName['task']!.readOne(db, id))!['title'] as String;
  Future<String> session() async => ok(await ai.startSession(title: 'Kế hoạch hôm nay', purpose: AiPurpose.planDay));
  Future<String> propose(String s, List<ProposedChange> changes) async =>
      ok(await ai.addProposal(s, model: 'qwen3.5-2b', site: AiEngineSite.device, changes: changes));
  Future<List<AiChangeRecord>> changesOf(String s) async => (await ai.proposals(s)).single.changes;
  Future<List<AuditLogData>> aiAudit() async =>
      (db.select(db.auditLog)..where((a) => a.aiProvenance.isNotNull())).get();

  group('history', () {
    test('a session, its messages and a proposal, read back', () async {
      final t = ok(await tasks.create('Gọi điện cho mẹ'));
      final s = await session();
      final q = ok(await ai.addMessage(s, AiMessageRole.person, 'Sắp xếp ngày mai giúp tôi'));
      final a = ok(await ai.addMessage(s, AiMessageRole.assistant, 'Đây là đề xuất',
          model: 'qwen3.5-2b', site: AiEngineSite.device, sentRefs: [(RecordRef('task', t), 1)]));
      final p = ok(await ai.addProposal(s,
          model: 'qwen3.5-2b',
          site: AiEngineSite.device,
          changes: [rename('c1', t, 1, 'Gọi mẹ lúc 18:00')],
          messageId: a));

      expect((await ai.sessions()).single.title, 'Kế hoạch hôm nay');
      final msgs = await ai.messages(s);
      expect([for (final m in msgs) m.id], [q, a]);
      expect(msgs.last.model, 'qwen3.5-2b');
      expect(msgs.last.site, AiEngineSite.device);
      expect(msgs.last.sentRefs, [(RecordRef('task', t), 1)]);
      final prop = (await ai.proposals(s)).single;
      expect(prop.id, p);
      expect(prop.messageId, a);
      expect(prop.changes.single.status, AiChangeStatus.proposed);
      expect(prop.changes.single.change.arguments, {'id': t, 'title': 'Gọi mẹ lúc 18:00'});
      expect(await titleOf(t), 'Gọi điện cho mẹ', reason: 'a proposal changes nothing (LF-INV-AI-001)');

      // Each written record syncs: an outbox row of its kind.
      final kinds = {for (final o in await db.select(db.outbox).get()) o.entityType};
      expect(kinds, containsAll(['aiSession', 'aiMessage', 'aiProposal']));
    });

    test("a person's message has no model; a proposal is only proposed; bad input is refused", () async {
      final s = await session();
      final r = await ai.addMessage(s, AiMessageRole.person, 'Xin chào', model: 'x');
      expect((r as CommandFailure).reason, contains('no model'));
      expect(await ai.addMessage(s, AiMessageRole.person, '   '), isA<CommandFailure>());
      expect(await ai.addProposal(s, model: 'm', site: AiEngineSite.device, changes: const []), isA<CommandFailure>());
      final bad = await gw.execute(
          Command(
            operationId: 'op-bad',
            actor: ActorRef(ActorKind.owner, profileId),
            workspaceId: personal,
            type: 'AddAiProposal',
            payload: {
              'op': 'addProposal',
              'id': s,
              'proposalId': 'px',
              'model': 'm',
              'site': 'device',
              'changes': encodeAiChanges([AiChangeRecord(rename('c1', 't', 1, 'x'), status: AiChangeStatus.applied)]),
            },
            expectedVersion: Version((await db.select(db.aiSessions).getSingle()).version),
            issuedAt: Instant.now(),
          ),
          const AiSessionHandler());
      expect((bad as CommandFailure).reason, contains('only proposed'));

      // "Applied" is written only with the change itself.
      final t = ok(await tasks.create('Việc'));
      final p = await propose(s, [rename('c1', t, await versionOf(t), 'Khác')]);
      final forged = await gw.execute(
          Command(
            operationId: 'op-forged',
            actor: ActorRef(ActorKind.owner, profileId),
            workspaceId: personal,
            type: 'RecordAiChange',
            payload: {'op': 'record', 'id': p, 'changeId': 'c1', 'status': 'applied'},
            expectedVersion: Version((await db.select(db.aiProposals).getSingle()).version),
            issuedAt: Instant.now(),
          ),
          const AiProposalHandler());
      expect(forged, isA<CommandFailure>());
      expect((await changesOf(s)).single.status, AiChangeStatus.proposed);
    });

    test('in the personal space only, also while a shared space is shown', () async {
      await (db.update(db.profiles)..where((x) => x.id.equals(profileId)))
          .write(const ProfilesCompanion(accountId: Value(me), accountProvider: Value('github')));
      await ProfileStore(db).cacheSpace(const SpaceSnapshot(
          workspaceId: space,
          ownerAccountId: me,
          name: 'Gia đình',
          members: [SpaceMemberSnapshot(accountId: me, role: 'owner')]));
      ok(await DriftSpaceService(db, gw).show(space));
      final s = await session();
      expect((await db.select(db.aiSessions).getSingle()).workspaceId, personal);
      expect((await ai.sessions()).single.id, s);

      // As a member of the space, straight to the gateway: refused.
      final r = await gw.execute(
          Command(
            operationId: 'op-space',
            actor: const ActorRef(ActorKind.member, me),
            workspaceId: space,
            type: 'StartAiSession',
            payload: {'op': 'create', 'id': 'sx', 'title': 'x', 'purpose': 'planDay'},
            issuedAt: Instant.now(),
          ),
          const AiSessionHandler());
      expect(r, isA<CommandFailure>());
      // As the owner of the space (authorization lets the owner act there):
      // the handler refuses it.
      final r2 = await gw.execute(
          Command(
            operationId: 'op-space-owner',
            actor: const ActorRef(ActorKind.owner, me),
            workspaceId: space,
            type: 'StartAiSession',
            payload: {'op': 'create', 'id': 'sy', 'title': 'x', 'purpose': 'planDay'},
            issuedAt: Instant.now(),
          ),
          const AiSessionHandler());
      expect((r2 as CommandFailure).reason, contains('personal space only'));
      expect(await db.select(db.aiSessions).get(), hasLength(1));
    });

    test('Confidential, like notes (data-classification)', () {
      for (final k in ['aiSession', 'aiMessage', 'aiProposal']) {
        expect(dataClassOf(k, const {}), DataClassification.confidential, reason: k);
      }
    });

    test('a session goes to the trash with its history and comes back with it', () async {
      final t = ok(await tasks.create('Việc'));
      final s = await session();
      ok(await ai.addMessage(s, AiMessageRole.person, 'Một'));
      await propose(s, [rename('c1', t, 1, 'Hai')]);
      ok(await ai.trashSession(s));
      expect(await ai.sessions(), isEmpty);
      expect(await ai.messages(s), isEmpty);
      expect(await ai.proposals(s), isEmpty);
      expect((await ai.approve((await db.select(db.aiProposals).getSingle()).id, 'c1')).status, AiChangeStatus.failed,
          reason: 'a trashed proposal cannot be approved');
      expect(await titleOf(t), 'Việc');
      ok(await ai.restoreSession(s));
      expect(await ai.messages(s), hasLength(1));
      expect(await ai.proposals(s), hasLength(1));
    });
  });

  group('approval', () {
    test('an approved change runs as the person; the audit row says where it came from (LF-INV-AI-003)', () async {
      final t = ok(await tasks.create('Gọi điện cho mẹ'));
      final s = await session();
      final p = await propose(s, [rename('c1', t, await versionOf(t), 'Gọi mẹ lúc 18:00')]);
      final out = await ai.approve(p, 'c1', consented: {RecordRef('task', t)});
      expect(out.status, AiChangeStatus.applied, reason: out.reason);
      expect(await titleOf(t), 'Gọi mẹ lúc 18:00');

      final audit = (await aiAudit()).single;
      expect(audit.actor, ActorRef(ActorKind.owner, profileId).toString(), reason: 'the person approved it');
      expect(audit.action, 'RenameTask');
      final prov = jsonDecode(audit.aiProvenance!) as Map;
      expect(prov['proposalId'], p);
      expect(prov['changeId'], 'c1');
      expect(prov['sessionId'], s);
      expect(prov['model'], 'qwen3.5-2b');
      expect(prov['site'], 'device');
      expect(prov['approvedBy'], profileId);
      expect(prov['arguments'], canonicalArguments({'id': t, 'title': 'Gọi mẹ lúc 18:00'}));
      expect(prov['consented'], ['task:$t']);

      final rec = (await changesOf(s)).single;
      expect(rec.status, AiChangeStatus.applied);
      expect(rec.operationId, audit.operationId, reason: 'marked in the same operation');
      expect(rec.approvedBy, profileId);

      // Approving again does nothing more.
      expect((await ai.approve(p, 'c1')).status, AiChangeStatus.applied);
      expect((await ai.dismiss(p, 'c1')).status, AiChangeStatus.applied, reason: 'an applied change stays applied');
      expect((await changesOf(s)).single.status, AiChangeStatus.applied);
      expect(await aiAudit(), hasLength(1));
      // Ordinary changes have no provenance.
      ok(await tasks.rename(t, 'Gọi mẹ'));
      expect(await aiAudit(), hasLength(1));
    });

    test('GS-15: approved after its target changed, it is stale and nothing is written; regenerated, it applies',
        () async {
      final t = ok(await tasks.create('Họp nhóm'));
      final s = await session();
      final v = await versionOf(t);
      final p = await propose(s, [rename('c1', t, v, 'Họp nhóm 9:00')]);
      ok(await tasks.rename(t, 'Họp nhóm (đã dời)')); // the person changes it meanwhile
      final auditBefore = (await db.select(db.auditLog).get()).length;

      final out = await ai.approve(p, 'c1');
      expect(out.status, AiChangeStatus.stale);
      expect(await titleOf(t), 'Họp nhóm (đã dời)', reason: "the person's change stays");
      expect(await aiAudit(), isEmpty, reason: 'nothing ran');
      final audit = await db.select(db.auditLog).get();
      expect(audit.length, auditBefore + 1, reason: 'only the proposal was marked');
      expect(audit.last.action, 'RecordAiChange');
      final rec = (await changesOf(s)).single;
      expect(rec.status, AiChangeStatus.stale);
      expect(rec.approvedBy, profileId);
      expect((await ai.approve(p, 'c1')).status, AiChangeStatus.stale, reason: 'stale stays stale');

      // Regenerated against the current version: it applies.
      final p2 = await propose(s, [rename('c1', t, await versionOf(t), 'Họp nhóm 9:00')]);
      expect((await ai.approve(p2, 'c1')).status, AiChangeStatus.applied);
      expect(await titleOf(t), 'Họp nhóm 9:00');
    });

    test('a target gone to the trash makes it stale', () async {
      final t = ok(await tasks.create('Đi chợ'));
      final s = await session();
      final p = await propose(s, [rename('c1', t, await versionOf(t), 'Đi siêu thị')]);
      ok(await tasks.trash(t));
      expect((await ai.approve(p, 'c1')).status, AiChangeStatus.stale);
      expect(await aiAudit(), isEmpty);
    });

    test('the versions are read again inside the transaction (LF-INV-AI-002)', () async {
      final t1 = ok(await tasks.create('Một'));
      final t2 = ok(await tasks.create('Hai'));
      final s = await session();
      final versions = {RecordRef('task', t1): await versionOf(t1), RecordRef('task', t2): await versionOf(t2)};
      final p = await propose(s, [rename('c1', t1, 0, 'Một (mới)', versions: versions)]);
      ok(await tasks.rename(t2, 'Hai (đổi)')); // after the service's own check would have run
      final r = await gw.execute(
          Command(
            operationId: 'op-race',
            actor: ActorRef(ActorKind.owner, profileId),
            workspaceId: personal,
            type: 'RenameTask',
            payload: {'op': 'rename', 'id': t1, 'title': 'Một (mới)'},
            expectedVersion: Version(versions[RecordRef('task', t1)]!),
            issuedAt: Instant.now(),
          ),
          AiApprovedChangeHandler(TaskCommandHandler(), proposalId: p, changeId: 'c1', versions: versions));
      expect((r as CommandFailure).reason, aiStaleReason);
      expect(await titleOf(t1), 'Một');
      expect((await changesOf(s)).single.status, AiChangeStatus.proposed);
      // And through the service.
      expect((await ai.approve(p, 'c1')).status, AiChangeStatus.stale);
    });

    test('the target changed between the check and the run: stale, nothing written', () async {
      final t = ok(await tasks.create('Một'));
      final s = await session();
      final p = await propose(s, [rename('c1', t, await versionOf(t), 'Một (AI)')]);
      final racing = _Racing(gw, () => tasks.rename(t, 'Một (người)'));
      final out = await DriftAiHistoryService(db, racing).approve(p, 'c1');
      expect(out.status, AiChangeStatus.stale);
      expect(await titleOf(t), 'Một (người)');
      expect(await aiAudit(), isEmpty);
      expect((await changesOf(s)).single.status, AiChangeStatus.stale);
    });

    test('another thing it was computed against changed between the check and the run: stale', () async {
      final t1 = ok(await tasks.create('Một'));
      final t2 = ok(await tasks.create('Hai'));
      final s = await session();
      final versions = {RecordRef('task', t1): await versionOf(t1), RecordRef('task', t2): await versionOf(t2)};
      final p = await propose(s, [rename('c1', t1, 0, 'Một (AI)', versions: versions)]);
      final racing = _Racing(gw, () => tasks.rename(t2, 'Hai (người)'));
      final out = await DriftAiHistoryService(db, racing).approve(p, 'c1');
      expect((out.status, out.reason), (AiChangeStatus.stale, aiStaleReason));
      expect(await titleOf(t1), 'Một');
      expect((await changesOf(s)).single.status, AiChangeStatus.stale);
    });

    test('D8: each on its own, approve all, dismiss', () async {
      final a = ok(await tasks.create('A'));
      final b = ok(await tasks.create('B'));
      final s = await session();
      final va = await versionOf(a), vb = await versionOf(b);
      final p = await propose(s, [
        rename('c1', a, va, 'A1'),
        rename('c2', b, vb, 'B1'),
        rename('c3', a, va, 'A2'), // computed against the same version as c1
        rename('c4', b, vb, 'B2'),
      ]);
      expect((await ai.dismiss(p, 'c4')).status, AiChangeStatus.dismissed);
      expect((await ai.approve(p, 'c4')).status, AiChangeStatus.dismissed, reason: 'dismissed stays dismissed');
      final all = await ai.approveAll(p);
      expect({
        for (final o in all) o.changeId: o.status
      }, {
        'c1': AiChangeStatus.applied,
        'c2': AiChangeStatus.applied,
        'c3': AiChangeStatus.stale, // a moved since c1 ran
      });
      expect((await titleOf(a), await titleOf(b)), ('A1', 'B1'));
      expect([for (final c in await changesOf(s)) c.status],
          [AiChangeStatus.applied, AiChangeStatus.applied, AiChangeStatus.stale, AiChangeStatus.dismissed]);
      expect(await aiAudit(), hasLength(2));
    });

    test('a command the assistant may not use, arguments it does not take, or no version: failed, nothing written',
        () async {
      final t = ok(await tasks.create('Việc'));
      final s = await session();
      final v = await versionOf(t);
      final p = await propose(s, [
        ProposedChange(
            id: 'c1', commandType: 'TrashTask', arguments: {'id': t}, versions: {RecordRef('task', t): v}, summary: ''),
        ProposedChange(
            id: 'c2',
            commandType: 'RenameTask',
            arguments: {'id': t, 'title': 'X', 'op': 'trash'},
            versions: {RecordRef('task', t): v},
            summary: ''),
        ProposedChange(
            id: 'c3', commandType: 'RenameTask', arguments: {'id': t, 'title': 'X'}, versions: const {}, summary: ''),
        ProposedChange(
            id: 'c4',
            commandType: 'SetTaskNotes',
            arguments: {'id': t, 'notes': 'Mang theo giấy tờ'},
            versions: {RecordRef('task', t): v},
            summary: ''),
      ]);
      final out = {for (final o in await ai.approveAll(p)) o.changeId: o};
      expect(out['c1']!.status, AiChangeStatus.failed);
      expect(out['c1']!.reason, contains('may use'));
      expect(out['c2']!.status, AiChangeStatus.failed);
      expect(out['c2']!.reason, contains('op'));
      expect(out['c3']!.status, AiChangeStatus.failed);
      expect(out['c3']!.reason, contains('version'));
      expect(out['c4']!.status, AiChangeStatus.applied);
      final row = (await recordKindByName['task']!.readOne(db, t))!;
      expect((row['title'], row['notes'], row['deletedAt']), ('Việc', 'Mang theo giấy tờ', null));
    });

    test('values the screens would refuse are failed, nothing tidied or written', () async {
      final t = ok(await tasks.create('Việc'));
      final s = await session();
      final v = await versionOf(t);
      final p = await propose(s, [
        rename('c1', t, v, ''),
        rename('c2', t, v, ' Việc mới '),
        ProposedChange(
            id: 'c3', commandType: 'SetTaskNotes', arguments: {'id': t, 'notes': 42}, versions: {RecordRef('task', t): v}, summary: ''),
      ]);
      final out = await ai.approveAll(p);
      expect([for (final o in out) o.status], everyElement(AiChangeStatus.failed));
      expect(await titleOf(t), 'Việc');
      expect(await versionOf(t), v);
    });

    test('a change its handler refuses, or breaks on, is failed with nothing written', () async {
      final t = ok(await tasks.create('Việc'));
      final s = await session();
      final v = await versionOf(t);
      final svc = DriftAiHistoryService(db, gw,
          catalog: AiToolCatalog([
            AiTool(
                commandType: 'RenameTask',
                kind: 'task',
                handler: _Breaks(TaskCommandHandler(), DomainRejection('không được')),
                op: 'rename',
                arguments: {'id', 'title'}),
            AiTool(
                commandType: 'SetTaskNotes',
                kind: 'task',
                handler: _Breaks(TaskCommandHandler(), StateError('broken')),
                op: 'setNotes',
                arguments: {'id', 'notes'}),
          ]));
      final p = await propose(s, [
        rename('c1', t, v, 'Khác'),
        ProposedChange(
            id: 'c2', commandType: 'SetTaskNotes', arguments: {'id': t, 'notes': 'x'}, versions: {RecordRef('task', t): v}, summary: ''),
      ]);
      final out = {for (final o in await svc.approveAll(p)) o.changeId: o};
      expect((out['c1']!.status, out['c1']!.reason), (AiChangeStatus.failed, 'không được'));
      expect(out['c2']!.status, AiChangeStatus.failed);
      final row = (await recordKindByName['task']!.readOne(db, t))!;
      expect((row['title'], row['notes'], row['version']), ('Việc', null, v));
      expect(await aiAudit(), isEmpty);
      expect([for (final c in await changesOf(s)) c.status], [AiChangeStatus.failed, AiChangeStatus.failed]);
    });

    test('LF-INV-AI-001: the assistant itself may not run a command', () async {
      final t = ok(await tasks.create('Việc'));
      final s = await session();
      final p = await propose(s, [rename('c1', t, await versionOf(t), 'Khác')]);
      const bot = ActorRef(ActorKind.aiAssistant, 'qwen3.5-2b');
      Command as(String type, Map<String, Object?> payload, {Version? v}) => Command(
          operationId: 'op-$type',
          actor: bot,
          workspaceId: personal,
          type: type,
          payload: payload,
          expectedVersion: v,
          issuedAt: Instant.now());
      final v = Version(await versionOf(t));
      for (final (cmd, handler) in <(Command, CommandHandler)>[
        (as('RenameTask', {'op': 'rename', 'id': t, 'title': 'Khác'}, v: v), TaskCommandHandler()),
        (
          as('RenameTask', {'op': 'rename', 'id': t, 'title': 'Khác'}, v: v),
          AiApprovedChangeHandler(TaskCommandHandler(),
              proposalId: p, changeId: 'c1', versions: {RecordRef('task', t): v.value})
        ),
        (
          as('StartAiSession', {'op': 'create', 'id': 'sx', 'title': 'x', 'purpose': 'planDay'}),
          const AiSessionHandler()
        ),
        (
          as('RecordAiChange', {'op': 'record', 'id': p, 'changeId': 'c1', 'status': 'dismissed'}),
          const AiProposalHandler()
        ),
      ]) {
        final r = await gw.execute(cmd, handler);
        expect((r as CommandFailure).kind, CommandFailureKind.unauthorized, reason: cmd.type);
      }
      expect(await titleOf(t), 'Việc');
      expect((await changesOf(s)).single.status, AiChangeStatus.proposed);
    });
  });

  group('export', () {
    test('the history is in the file and read back; a bad proposal is refused; a v17 file reads', () async {
      final t = ok(await tasks.create('Việc'));
      final s = await session();
      ok(await ai.addMessage(s, AiMessageRole.person, 'Một'));
      await propose(s, [rename('c1', t, await versionOf(t), 'Hai')]);
      final text = await ProfileExport.build(db);
      final parsed = ProfileExport.parse(text, currentSchemaVersion: AppDatabase.currentSchemaVersion);
      expect(parsed.records['aiSession'], hasLength(1));
      expect(parsed.records['aiMessage'], hasLength(1));
      expect(parsed.records['aiProposal'], hasLength(1));

      Map<String, Object?> payload() => ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();
      for (final (why, tamper) in <(String, void Function(Map<String, Object?>))>[
        ('unreadable changes', (p) => (p['aiProposals'] as List).first['changes'] = '{nope'),
        ('an unknown role', (p) => (p['aiMessages'] as List).first['role'] = 'system'),
        ('an unknown purpose', (p) => (p['aiSessions'] as List).first['purpose'] = 'chat'),
        ('a message of an unknown session', (p) => (p['aiMessages'] as List).first['sessionId'] = 'nope'),
      ]) {
        final p = payload();
        tamper(p);
        expect(
            () => ProfileExport.parse(ProfileExport.seal(p, schemaVersion: AppDatabase.currentSchemaVersion),
                currentSchemaVersion: AppDatabase.currentSchemaVersion),
            throwsA(isA<ExportRejected>()),
            reason: why);
      }

      // A file of v17 has no assistant history.
      final old = payload()..removeWhere((k, _) => k.startsWith('ai'));
      final env = (jsonDecode(ProfileExport.seal(old, schemaVersion: 17)) as Map).cast<String, Object?>();
      env['counts'] = (env['counts'] as Map)..removeWhere((k, _) => !old.containsKey(k));
      final back = ProfileExport.parse(jsonEncode(env), currentSchemaVersion: AppDatabase.currentSchemaVersion);
      expect(back.records['aiSession'], isEmpty);
      expect(back.records['task'], hasLength(1));
    });
  });

  group('sync (the owner\'s D7)', () {
    late Directory dir;
    final open = <AppDatabase>[];
    setUp(() => dir = Directory.systemTemp.createTempSync('lifeflow_ai_sync_'));
    tearDown(() async {
      for (final d in open) {
        await d.close();
      }
      open.clear();
      dir.deleteSync(recursive: true);
    });

    test('sealed to another device; applied wins over dismissed; a trashed session goes there too', () async {
      final server = MemoryRemoteServer();
      final f0 = File('${dir.path}/d0.db');
      final db0 = AppDatabase(NativeDatabase(f0));
      final ws = (await ProfileStore(db0).ensureFirstProfile()).activeWorkspaceId.value;
      final sealer = await RecordSealer.of(await newWorkspaceKey());
      await MemoryRemoteGateway(server, accountId: 'acc')
          .createWorkspace(RemoteWorkspace(workspaceId: ws, wrappedKey: Uint8List(1), unlockKind: 'recoveryKey'));
      await db0.into(db0.syncState).insert(SyncStateCompanion.insert(workspaceId: ws, deviceId: 'd0'));
      await db0.close();
      final f1 = f0.copySync('${dir.path}/d1.db');

      Future<(AppDatabase, DriftCommandGateway, SyncEngine)> device(File f, String name) async {
        final d = AppDatabase(NativeDatabase(f));
        open.add(d);
        await (d.update(d.syncState)..where((s) => s.workspaceId.equals(ws)))
            .write(SyncStateCompanion(deviceId: Value(name)));
        final g = DriftCommandGateway(d, WorkspaceOwnerAuthorization(d));
        return (
          d,
          g,
          SyncEngine(
              db: d,
              gateway: g,
              remote: MemoryRemoteGateway(server, accountId: 'acc'),
              sealer: sealer,
              workspaceId: ws,
              deviceId: name)
        );
      }

      final (a, ga, ea) = await device(f0, 'd0');
      final (b, gb, eb) = await device(f1, 'd1');
      Future<void> syncBoth() async {
        for (var i = 0; i < 2; i++) {
          for (final e in [ea, eb]) {
            final r = await e.sync();
            expect(r.outcome, SyncOutcome.upToDate, reason: '$r');
          }
        }
      }

      final aiA = DriftAiHistoryService(a, ga), aiB = DriftAiHistoryService(b, gb);
      final t = ok(await DriftTaskService(a, ga).create('Gọi điện cho mẹ'));
      final s = ok(await aiA.startSession(title: 'Ngày mai', purpose: AiPurpose.planDay));
      ok(await aiA.addMessage(s, AiMessageRole.person, 'Sắp xếp giúp tôi'));
      final v = (await recordKindByName['task']!.readOne(a, t))!['version'] as int;
      final p = ok(await aiA.addProposal(s,
          model: 'qwen3.5-2b', site: AiEngineSite.device, changes: [rename('c1', t, v, 'Gọi mẹ 18:00')]));
      await syncBoth();

      // Sealed on the server: no plain text of the history there.
      final pulled = await MemoryRemoteGateway(server, accountId: 'acc').pull(ws, 0);
      expect(pulled, hasLength(greaterThanOrEqualTo(4)));
      for (final r in pulled) {
        expect(utf8.decode(r.sealed ?? Uint8List(0), allowMalformed: true), isNot(contains('Sắp xếp')));
      }
      expect((await aiB.sessions()).single.title, 'Ngày mai');
      expect((await aiB.messages(s)).single.text, 'Sắp xếp giúp tôi');

      // Concurrently: dismissed on one device, applied on the other.
      expect((await aiA.dismiss(p, 'c1')).status, AiChangeStatus.dismissed);
      expect((await aiB.approve(p, 'c1')).status, AiChangeStatus.applied);
      await syncBoth();
      for (final (d, svc) in [(a, aiA), (b, aiB)]) {
        expect((await svc.proposals(s)).single.changes.single.status, AiChangeStatus.applied, reason: 'applied wins');
        expect((await recordKindByName['task']!.readOne(d, t))!['title'], 'Gọi mẹ 18:00');
      }

      ok(await aiA.trashSession(s));
      await syncBoth();
      expect(await aiB.sessions(), isEmpty);
      expect(await aiB.messages(s), isEmpty);
    });
  });
}
