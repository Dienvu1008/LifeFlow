// P06 T3 (ADR-0082; ADR-0080, ADR-0012; LF-INV-AI-001/002/003, GS-15): the
// assistant's history and the approval of its proposals.
//
// Approving a change:
//   1. the approval is made for this person, these exact arguments and the
//      versions the change was computed against (domain `approveChange`);
//   2. the tool catalog says which command and handler it is; a command the
//      assistant may not use, or arguments it does not take, fail;
//   3. the versions are read now: one that moved (or a thing gone) makes the
//      change stale, and nothing is written;
//   4. the command runs through the gateway as the person, with the
//      target's version expected, the versions read again in the
//      transaction, and the proposal marked applied in the same commit; the
//      audit row carries the provenance (LF-INV-AI-003);
//   5. a refusal is recorded on the proposal: stale or failed.
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:uuid/uuid.dart';

import 'ai_history_handlers.dart';
import 'app_database.dart';
import 'event_command_handlers.dart' show EventCommandHandler;
import 'profile_store.dart';
import 'schedule_mapping.dart' show scheduleFieldsJson;
import 'task_command_handler.dart';

/// A command the assistant may propose (P06 T6 brings the whole list).
class AiTool {
  const AiTool({
    required this.commandType,
    required this.kind,
    required this.handler,
    required this.op,
    required this.arguments,
    this.creates = false,
    this.check,
  });
  final String commandType;

  /// The kind of the thing it changes (its `id` argument).
  final String kind;
  final CommandHandler handler;

  /// The handler's op, put in the payload by the app (never by the model).
  final String op;

  /// The arguments it takes; `id` names its target.
  final Set<String> arguments;

  /// It makes a new thing (no version to expect).
  final bool creates;

  /// Why the arguments' values are not ones its command takes, or null: the
  /// checks the app's own screens make before a command (a handler may
  /// trust them). What runs is exactly what was approved, so nothing is
  /// tidied here: a value that is not right is refused.
  final String? Function(Map<String, Object?> arguments)? check;

  /// Why [change] is not a call of this tool, or null.
  String? problemOf(ProposedChange change) {
    final unknown = change.arguments.keys.where((k) => !arguments.contains(k)).toList();
    if (unknown.isNotEmpty) return 'arguments it does not take: ${unknown.join(', ')}';
    if (change.arguments['id'] is! String) return 'the thing to change is not named';
    if (!creates && change.versions[RecordRef(kind, change.arguments['id'] as String)] == null) {
      return 'the version of the thing to change is not given';
    }
    return check?.call(change.arguments);
  }

  Map<String, Object?> payloadOf(ProposedChange change) => {...change.arguments, 'op': op};
}

/// Why [schedule] is not a one-off timed slot of task [taskId] as the app
/// writes one, or null. The assistant may only give a task a start and an
/// end on one day: no repeat, no deadline, and exactly the payload the app
/// would make for that slot (what is approved is what runs).
String? aiScheduleArgumentError(String taskId, Object? schedule) {
  if (schedule is! Map) return 'a schedule is needed';
  final s = schedule.cast<String, Object?>();
  try {
    tk.TimedPoint point(String p) => tk.TimedPoint(ZonedWallClock(
        LocalDate.parse(s['${p}Date'] as String), TimeOfDayValue.parse(s['${p}Time'] as String), s['${p}Zone'] as String));
    final spec = tk.ScheduleSpec(start: point('start'), end: point('end'));
    if (tk.validateSchedule(spec) is! Ok) return 'not a valid time';
    if (spec.start!.date != spec.end!.date) return 'a slot is within one day';
    final expected = scheduleFieldsJson('task', taskId, spec, null);
    return canonicalArguments(expected) == canonicalArguments(s) ? null : 'only a one-off slot on one day';
  } on Object {
    return 'not a valid time';
  }
}

class AiToolCatalog {
  AiToolCatalog(Iterable<AiTool> tools) : _tools = {for (final t in tools) t.commandType: t};
  final Map<String, AiTool> _tools;
  AiTool? operator [](String commandType) => _tools[commandType];

  /// P06 T6 (ADR-0086): the tools of the assistant's turns. A plan or a
  /// conflict fix sets a task's time; the two text tools stay from T3.
  static final AiToolCatalog standard = AiToolCatalog([
    ...minimal._tools.values,
    AiTool(
        commandType: 'SetTaskSchedule',
        kind: 'task',
        handler: TaskCommandHandler(),
        op: 'setSchedule',
        arguments: {'id', 'schedule'},
        check: (a) => aiScheduleArgumentError(a['id'] as String, a['schedule'])),
    // P06b W4 (ADR-0088): the chat may propose a new task (in the personal
    // space, at the end of the tasks without a list); its id is the app's.
    AiTool(
        commandType: 'CreateTask',
        kind: 'task',
        handler: TaskCommandHandler(),
        op: 'create',
        arguments: {'id', 'title'},
        creates: true,
        check: (a) => _titleError(a['title'])),
    // P06b W4b (ADR-0093): the chat may propose a new event, an event of
    // the personal space at another time, or one occurrence of a repeating
    // event on another day: what the Calendar's own screens send.
    AiTool(
        commandType: 'CreateEvent',
        kind: 'event',
        handler: const EventCommandHandler(),
        op: 'create',
        arguments: {'id', 'title', 'schedule'},
        creates: true,
        check: (a) => _titleError(a['title']) ?? aiScheduleArgumentError(a['id'] as String, a['schedule'])),
    // A one-off event gets a new slot; its title, place and calendar are
    // what they were (an update replaces them all), so they are named.
    AiTool(
        commandType: 'MoveEvent',
        kind: 'event',
        handler: const EventCommandHandler(),
        op: 'update',
        arguments: {'id', 'title', 'location', 'calendarId', 'schedule'},
        check: (a) =>
            _titleError(a['title']) ??
            (a['location'] is String? && a['calendarId'] is String? ? null : 'a place and a calendar are text or none') ??
            aiScheduleArgumentError(a['id'] as String, a['schedule'])),
    AiTool(
        commandType: 'MoveEventOccurrence',
        kind: 'event',
        handler: const EventCommandHandler(),
        op: 'setException',
        arguments: {'id', 'kind', 'originalDate', 'moveDate', 'moveTime'},
        check: _occurrenceMoveError),
  ]);

  /// Why [a] is not one occurrence of a repeating event moved to a day and a
  /// time, or null.
  static String? _occurrenceMoveError(Map<String, Object?> a) {
    if (a['kind'] != 'move') return 'only moving an occurrence';
    try {
      LocalDate.parse(a['originalDate'] as String);
      LocalDate.parse(a['moveDate'] as String);
      TimeOfDayValue.parse(a['moveTime'] as String);
      return null;
    } on Object {
      return 'a day and a time (HH:MM) to move it to';
    }
  }

  /// T3's tools, enough to prove the path: renaming a task, its notes.
  static final AiToolCatalog minimal = AiToolCatalog([
    AiTool(
        commandType: 'RenameTask',
        kind: 'task',
        handler: TaskCommandHandler(),
        op: 'rename',
        arguments: {'id', 'title'},
        check: (a) => _titleError(a['title'])),
    AiTool(
        commandType: 'SetTaskNotes',
        kind: 'task',
        handler: TaskCommandHandler(),
        op: 'setNotes',
        arguments: {'id', 'notes'},
        check: (a) => switch (a['notes']) {
              null => null,
              final String n when n.length <= maxAiMessageLength => null,
              _ => 'notes are a text',
            }),
  ]);

  static String? _titleError(Object? title) => switch (title) {
        final String t when t.trim().isNotEmpty && t == t.trim() && t.length <= maxAiTitleLength => null,
        _ => 'a title is a non-empty text without spaces around it',
      };
}

class DriftAiHistoryService implements AiHistoryService {
  DriftAiHistoryService(this.db, this.gateway, {AiToolCatalog? catalog, this.clock = const SystemClock()})
      : catalog = catalog ?? AiToolCatalog.standard,
        _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final AiToolCatalog catalog;
  final Clock clock;
  final ProfileStore _store;
  final _uuid = const Uuid();

  AiSessionHandler get _sessions => AiSessionHandler(clock: clock);
  AiProposalHandler get _proposals => AiProposalHandler(clock: clock);

  static const _noProfile = CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');

  Future<CommandResult> _run(CommandContext ctx, String type, CommandHandler handler, Map<String, Object?> payload,
          {Version? expected, Map<String, Object?>? provenance}) =>
      gateway.execute(
          Command(
            operationId: _uuid.v7(),
            actor: ctx.actor,
            workspaceId: ctx.workspaceId,
            type: type,
            payload: payload,
            expectedVersion: expected,
            issuedAt: clock.now(),
            aiProvenance: provenance,
          ),
          handler);

  Future<CommandResult> _onSession(String type, String id, Map<String, Object?> payload) async {
    final ctx = await _store.personalContext();
    if (ctx == null) return _noProfile;
    final s = await (db.select(db.aiSessions)..where((s) => s.id.equals(id))).getSingleOrNull();
    if (s == null || s.workspaceId != ctx.workspaceId) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'session not found');
    }
    return _run(ctx, type, _sessions, {'id': id, ...payload}, expected: Version(s.version));
  }

  @override
  Future<CommandResult> startSession({required String title, required AiPurpose purpose}) async {
    final ctx = await _store.personalContext();
    if (ctx == null) return _noProfile;
    return _run(ctx, 'StartAiSession', _sessions,
        {'op': 'create', 'id': EntityId.generate().value, 'title': title.trim(), 'purpose': purpose.name});
  }

  @override
  Future<CommandResult> renameSession(String sessionId, String title) =>
      _onSession('RenameAiSession', sessionId, {'op': 'rename', 'title': title.trim()});

  @override
  Future<CommandResult> trashSession(String sessionId) => _onSession('TrashAiSession', sessionId, {'op': 'trash'});

  @override
  Future<CommandResult> restoreSession(String sessionId) =>
      _onSession('RestoreAiSession', sessionId, {'op': 'restore'});

  @override
  Future<CommandResult> addMessage(String sessionId, AiMessageRole role, String text,
      {String? model, AiEngineSite? site, List<(RecordRef, int?)> sentRefs = const []}) async {
    final mid = EntityId.generate().value;
    final r = await _onSession('AddAiMessage', sessionId, {
      'op': 'addMessage',
      'messageId': mid,
      'role': role.name,
      'text': text,
      'model': model,
      'site': site?.name,
      'sentRefs': [
        for (final (ref, v) in sentRefs) {'kind': ref.kind, 'id': ref.id, 'version': v}
      ],
    });
    return r is CommandOk ? CommandOk(mid, r.newVersion, r.events) : r;
  }

  @override
  Future<CommandResult> addProposal(String sessionId,
      {required String model,
      required AiEngineSite site,
      required List<ProposedChange> changes,
      String? messageId,
      String note = ''}) async {
    final pid = EntityId.generate().value;
    final r = await _onSession('AddAiProposal', sessionId, {
      'op': 'addProposal',
      'proposalId': pid,
      'messageId': messageId,
      'model': model,
      'site': site.name,
      'changes': encodeAiChanges([for (final c in changes) AiChangeRecord(c)]),
      'note': note,
    });
    return r is CommandOk ? CommandOk(pid, r.newVersion, r.events) : r;
  }

  /// The live proposal [id] of a live session of the personal space.
  Future<AiProposalRow?> _proposal(CommandContext ctx, String id) async {
    final p = await (db.select(db.aiProposals)..where((p) => p.id.equals(id))).getSingleOrNull();
    if (p == null || p.workspaceId != ctx.workspaceId || p.deletedAt != null) return null;
    return p;
  }

  Future<AiChangeOutcome> _now(String proposalId, String changeId, {String? fallback}) async {
    final p = await (db.select(db.aiProposals)..where((p) => p.id.equals(proposalId))).getSingleOrNull();
    final c = p == null ? null : decodeAiChanges(p.changes).where((c) => c.change.id == changeId).firstOrNull;
    if (c == null) return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: fallback ?? 'change not found');
    return AiChangeOutcome(changeId, c.status, reason: c.reason ?? fallback);
  }

  /// Records what became of a change that did not run.
  Future<AiChangeOutcome> _record(CommandContext ctx, AiProposalRow p, String changeId, AiChangeStatus status,
      {String? reason, AiApproval? approval}) async {
    await _run(
        ctx,
        'RecordAiChange',
        _proposals,
        {
          'op': 'record',
          'id': p.id,
          'changeId': changeId,
          'status': status.name,
          'reason': reason,
          'approvedBy': approval?.actorId,
          'approvedAt': approval?.approvedAt.millis,
        },
        expected: Version(p.version));
    return _now(p.id, changeId, fallback: reason);
  }

  @override
  Future<AiChangeOutcome> approve(String proposalId, String changeId, {Set<RecordRef> consented = const {}}) async {
    final ctx = await _store.personalContext();
    if (ctx == null) return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: _noProfile.reason);
    final p = await _proposal(ctx, proposalId);
    if (p == null) return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: 'proposal not found');
    final s = await (db.select(db.aiSessions)..where((s) => s.id.equals(p.sessionId))).getSingleOrNull();
    if (s == null || s.deletedAt != null)
      return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: 'session not found');
    final records = decodeAiChanges(p.changes);
    final rec = records.where((c) => c.change.id == changeId).firstOrNull;
    if (rec == null) return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: 'change not found');
    if (rec.status != AiChangeStatus.proposed) return AiChangeOutcome(changeId, rec.status, reason: rec.reason);

    // 1. The approval: this person, these arguments, these versions.
    final site = AiEngineSite.values.byName(p.site);
    final proposal = AiProposal(
        id: p.id,
        sessionId: p.sessionId,
        model: p.model,
        createdAt: Instant(p.createdAt),
        changes: [for (final r in records) r.change]);
    final change = proposal.change(changeId)!;
    final approval = approveChange(proposal, change,
        actorId: ctx.actor.id,
        at: clock.now(),
        policy: AiPolicyContext(site: site, model: p.model, consented: consented));

    // 2. A tool the assistant may use, called as it takes.
    final tool = catalog[change.commandType];
    if (tool == null)
      return _record(ctx, p, changeId, AiChangeStatus.failed, reason: 'not a command the assistant may use');
    final why = tool.problemOf(change);
    if (why != null) return _record(ctx, p, changeId, AiChangeStatus.failed, reason: why);

    // 3. Still what it was computed against (LF-INV-AI-002).
    final current = <RecordRef, int?>{
      for (final ref in change.versions.keys) ref: await liveVersionOf(db, ctx.workspaceId, ref),
    };
    final problem =
        approvalProblem(approval, proposalId: p.id, change: change, actorId: ctx.actor.id, current: (r) => current[r]);
    if (problem == ApprovalProblem.stale) {
      return _record(ctx, p, changeId, AiChangeStatus.stale, reason: aiStaleReason, approval: approval);
    }
    if (problem != null)
      return _record(ctx, p, changeId, AiChangeStatus.failed, reason: problem.name, approval: approval);

    // 4. As the person, through the gateway, with its provenance.
    final target = RecordRef(tool.kind, change.arguments['id'] as String);
    final expected = tool.creates ? null : change.versions[target];
    final CommandResult result;
    try {
      result = await _run(
          ctx,
          change.commandType,
          AiApprovedChangeHandler(tool.handler,
              proposalId: p.id, changeId: changeId, versions: approval.versions, clock: clock),
          tool.payloadOf(change),
          expected: expected == null ? null : Version(expected),
          provenance: {
            'proposalId': p.id,
            'changeId': changeId,
            'sessionId': p.sessionId,
            'model': p.model,
            'site': site.name,
            'approvedBy': approval.actorId,
            'approvedAt': approval.approvedAt.millis,
            'arguments': approval.arguments,
            'versions': [for (final r in (approval.versions.keys.toList()..sort())) '$r@${approval.versions[r]}'],
            'consented': [for (final r in (consented.toList()..sort())) '$r'],
          });
    } on Object catch (e) {
      // A handler that broke on what it was given: rolled back, nothing
      // written; the change is failed, not the app.
      final fresh = await _proposal(ctx, p.id);
      if (fresh == null) return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: '$e');
      return _record(ctx, fresh, changeId, AiChangeStatus.failed,
          reason: 'the command could not run', approval: approval);
    }

    // 5. What became of it.
    switch (result) {
      case CommandOk():
        return AiChangeOutcome(changeId, AiChangeStatus.applied);
      case CommandFailure(kind: CommandFailureKind.versionConflict):
      case CommandFailure(reason: aiStaleReason):
        final fresh = await _proposal(ctx, p.id);
        if (fresh == null) return AiChangeOutcome(changeId, AiChangeStatus.stale, reason: aiStaleReason);
        return _record(ctx, fresh, changeId, AiChangeStatus.stale, reason: aiStaleReason, approval: approval);
      case CommandFailure(:final kind, :final reason):
        final fresh = await _proposal(ctx, p.id);
        final again =
            fresh == null ? null : decodeAiChanges(fresh.changes).where((c) => c.change.id == changeId).firstOrNull;
        // Decided meanwhile (another tap, another device): as it is now.
        if (fresh == null || again == null || again.status != AiChangeStatus.proposed)
          return _now(p.id, changeId, fallback: reason);
        return _record(ctx, fresh, changeId, AiChangeStatus.failed, reason: reason ?? kind.name, approval: approval);
    }
  }

  @override
  Future<List<AiChangeOutcome>> approveAll(String proposalId, {Set<RecordRef> consented = const {}}) async {
    final ctx = await _store.personalContext();
    if (ctx == null) return const [];
    final p = await _proposal(ctx, proposalId);
    if (p == null) return const [];
    return [
      for (final c in decodeAiChanges(p.changes))
        if (c.status == AiChangeStatus.proposed) await approve(proposalId, c.change.id, consented: consented),
    ];
  }

  @override
  Future<AiChangeOutcome> dismiss(String proposalId, String changeId) async {
    final ctx = await _store.personalContext();
    if (ctx == null) return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: _noProfile.reason);
    final p = await _proposal(ctx, proposalId);
    if (p == null) return AiChangeOutcome(changeId, AiChangeStatus.failed, reason: 'proposal not found');
    return _record(ctx, p, changeId, AiChangeStatus.dismissed);
  }

  @override
  Future<List<AiSessionView>> sessions() async {
    final ws = await _store.personalWorkspaceId();
    if (ws == null) return const [];
    final rows = await (db.select(db.aiSessions)
          ..where((s) => s.workspaceId.equals(ws) & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.updatedAt), (s) => OrderingTerm.desc(s.id)]))
        .get();
    return [
      for (final s in rows)
        if (AiPurpose.values.where((p) => p.name == s.purpose).firstOrNull case final purpose?)
          AiSessionView(id: s.id, title: s.title, purpose: purpose, updatedAt: s.updatedAt),
    ];
  }

  @override
  Future<List<AiMessageView>> messages(String sessionId) async {
    final ws = await _store.personalWorkspaceId();
    final rows = await (db.select(db.aiMessages)
          ..where((m) => m.sessionId.equals(sessionId) & m.deletedAt.isNull())
          // P06b W4: times are kept to the second, and a UUID v7 is random
          // within a millisecond, so a question and its answer written
          // together are put in the order they were written (rowid) first.
          ..orderBy([
            (m) => OrderingTerm.asc(m.createdAt),
            (m) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
            (m) => OrderingTerm.asc(m.id),
          ]))
        .get();
    return [
      for (final m in rows)
        if (m.workspaceId == ws)
          AiMessageView(
            id: m.id,
            role: AiMessageRole.values.where((r) => r.name == m.role).firstOrNull ?? AiMessageRole.assistant,
            text: m.body,
            createdAt: m.createdAt,
            model: m.model,
            site: AiEngineSite.values.where((s) => s.name == m.site).firstOrNull,
            sentRefs: [
              for (final r in (jsonDecode(m.sentRefs) as List).cast<Map>())
                (RecordRef(r['kind'] as String, r['id'] as String), r['version'] as int?),
            ],
          ),
    ];
  }

  @override
  Future<List<AiProposalView>> proposals(String sessionId) async {
    final ws = await _store.personalWorkspaceId();
    final rows = await (db.select(db.aiProposals)
          ..where((p) => p.sessionId.equals(sessionId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt), (p) => OrderingTerm.asc(p.id)]))
        .get();
    return [
      for (final p in rows)
        if (p.workspaceId == ws)
          AiProposalView(
            id: p.id,
            sessionId: p.sessionId,
            messageId: p.messageId,
            model: p.model,
            site: AiEngineSite.values.where((s) => s.name == p.site).firstOrNull ?? AiEngineSite.cloud,
            changes: decodeAiChanges(p.changes),
            note: p.note,
          ),
    ];
  }
}
