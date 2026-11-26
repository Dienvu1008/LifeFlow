// P06 T7: the assistant's ports, faked. Calls are recorded in [calls].
import 'dart:async';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

class FakeAssistant implements AiAssistant {
  FakeAssistant(this.calls, this.history);
  final List<String> calls;
  final FakeHistory history;

  /// What the next turns give, in order (the last one repeats).
  final results = <AiTurnResult Function()>[];

  /// The words of the next answer.
  List<String> words = const ['Ngày ', '30 tháng 11.'];
  Completer<void>? hold;

  AiTurnResult _next() => (results.length > 1 ? results.removeAt(0) : results.single)();

  @override
  Future<AiTurnResult> planDay(LocalDate date,
      {String? sessionId, String? request, Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) async {
    calls.add('ai.plan:$date:${sessionId ?? '-'}:${request ?? ''}:${(consented.map((r) => '$r').toList()..sort()).join(',')}:$withoutUnconsented');
    return _next();
  }

  @override
  Future<AiTurnResult> fixConflicts(LocalDate date,
      {String? sessionId, Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) async {
    calls.add('ai.fix:$date:${sessionId ?? '-'}');
    return _next();
  }

  @override
  Future<AiTurnResult> askDocument(RecordRef item, String question,
      {String? sessionId,
      Set<RecordRef> consented = const {},
      bool withoutUnconsented = false,
      void Function(String text)? onText}) async {
    calls.add('ai.ask:$item:$question:${(consented.map((r) => '$r').toList()..sort()).join(',')}');
    final r = _next();
    if (r.outcome != AiTurnOutcome.answered) return r;
    final b = StringBuffer();
    for (final w in words) {
      if (hold != null) await hold!.future;
      b.write(w);
      onText?.call(b.toString());
    }
    return AiTurnResult(AiTurnOutcome.answered, sessionId: r.sessionId, site: r.site, model: r.model, text: b.toString());
  }

  /// P06b W4: a chat turn. A turn that answers is kept in [history] as the
  /// real one is: the person's message, the answer, its proposal.
  @override
  Future<AiTurnResult> chat(String message,
      {String? sessionId, Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) async {
    calls.add('ai.chat:$message:${sessionId ?? '-'}:${(consented.map((r) => '$r').toList()..sort()).join(',')}:$withoutUnconsented');
    if (hold != null) await hold!.future;
    final r = _next();
    if (r.outcome != AiTurnOutcome.answered && r.outcome != AiTurnOutcome.proposed) return r;
    final s = sessionId ?? r.sessionId ?? 'chat${history.sessionsList.length + 1}';
    if (!history.sessionsList.any((x) => x.id == s)) {
      history.sessionsList.insert(0, AiSessionView(id: s, title: message, purpose: AiPurpose.chat, updatedAt: DateTime(2026, 11, 4, 9)));
    }
    final list = history.messagesOf.putIfAbsent(s, () => []);
    final n = list.length;
    list.add(AiMessageView(id: '$s-$n', role: AiMessageRole.person, text: message, createdAt: DateTime(2026, 11, 4, 9)));
    final answer = '$s-${n + 1}';
    list.add(AiMessageView(
        id: answer, role: AiMessageRole.assistant, text: r.text, createdAt: DateTime(2026, 11, 4, 9), model: r.model, site: r.site));
    if (r.proposalId != null) {
      history.proposalsOf.putIfAbsent(s, () => []).add(AiProposalView(
          id: r.proposalId!,
          sessionId: s,
          messageId: answer,
          model: r.model ?? 'qwen',
          site: r.site ?? AiEngineSite.device,
          note: r.text,
          changes: [for (final c in chatChanges) AiChangeRecord(c)]));
    }
    return AiTurnResult(r.outcome,
        sessionId: s, messageId: answer, proposalId: r.proposalId, site: r.site, model: r.model, text: r.text, lines: r.lines);
  }

  /// The changes of the next chat proposal.
  List<ProposedChange> chatChanges = const [];

  @override
  Future<void> stop() async => calls.add('ai.stop');
}

ProposedChange change(String id, String summary) =>
    ProposedChange(id: id, commandType: 'SetTaskSchedule', arguments: {'id': id}, versions: {RecordRef('task', id): 1}, summary: summary);

class FakeHistory implements AiHistoryService {
  FakeHistory(this.calls);
  final List<String> calls;
  final sessionsList = <AiSessionView>[];
  final trashed = <String>{};
  final messagesOf = <String, List<AiMessageView>>{};
  final proposalsOf = <String, List<AiProposalView>>{};

  /// Changes that are stale when approved.
  final staleOnApprove = <String>{};

  /// A session with one proposal of [changes]; its ids.
  (String, String) seed(String title, List<ProposedChange> changes, {String note = 'Việc quan trọng trước.'}) {
    final s = 's${sessionsList.length + 1}', p = 'p${sessionsList.length + 1}', m = 'm${sessionsList.length + 1}';
    sessionsList.insert(0, AiSessionView(id: s, title: title, purpose: AiPurpose.planDay, updatedAt: DateTime(2026, 11, 4, 9)));
    messagesOf[s] = [
      AiMessageView(id: '$m-q', role: AiMessageRole.person, text: 'Plan my day', createdAt: DateTime(2026, 11, 4, 9)),
      AiMessageView(
          id: m, role: AiMessageRole.assistant, text: note, createdAt: DateTime(2026, 11, 4, 9), model: 'qwen', site: AiEngineSite.device),
    ];
    proposalsOf[s] = [
      AiProposalView(
          id: p, sessionId: s, messageId: m, model: 'qwen', site: AiEngineSite.device, note: note, changes: [for (final c in changes) AiChangeRecord(c)]),
    ];
    return (s, p);
  }

  AiChangeOutcome _set(String proposalId, String changeId, AiChangeStatus status) {
    for (final e in proposalsOf.entries) {
      final list = e.value;
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        if (p.id != proposalId) continue;
        final changes = [
          for (final c in p.changes)
            c.change.id == changeId && c.status == AiChangeStatus.proposed ? c.withOutcome(status) : c,
        ];
        list[i] = AiProposalView(
            id: p.id, sessionId: p.sessionId, messageId: p.messageId, model: p.model, site: p.site, note: p.note, changes: changes);
        return AiChangeOutcome(changeId, changes.firstWhere((c) => c.change.id == changeId).status);
      }
    }
    return AiChangeOutcome(changeId, AiChangeStatus.failed);
  }

  @override
  Future<AiChangeOutcome> approve(String proposalId, String changeId, {Set<RecordRef> consented = const {}}) async {
    calls.add('h.approve:$proposalId:$changeId');
    return _set(proposalId, changeId, staleOnApprove.contains(changeId) ? AiChangeStatus.stale : AiChangeStatus.applied);
  }

  @override
  Future<List<AiChangeOutcome>> approveAll(String proposalId, {Set<RecordRef> consented = const {}}) async {
    calls.add('h.approveAll:$proposalId');
    final p = proposalsOf.values.expand((l) => l).firstWhere((p) => p.id == proposalId);
    return [
      for (final c in p.changes)
        if (c.status == AiChangeStatus.proposed)
          _set(proposalId, c.change.id, staleOnApprove.contains(c.change.id) ? AiChangeStatus.stale : AiChangeStatus.applied),
    ];
  }

  @override
  Future<AiChangeOutcome> dismiss(String proposalId, String changeId) async {
    calls.add('h.dismiss:$proposalId:$changeId');
    return _set(proposalId, changeId, AiChangeStatus.dismissed);
  }

  @override
  Future<List<AiSessionView>> sessions() async => [for (final s in sessionsList) if (!trashed.contains(s.id)) s];
  @override
  Future<List<AiMessageView>> messages(String sessionId) async => messagesOf[sessionId] ?? const [];
  @override
  Future<List<AiProposalView>> proposals(String sessionId) async => [...?proposalsOf[sessionId]];

  @override
  Future<CommandResult> trashSession(String sessionId) async {
    calls.add('h.trash:$sessionId');
    trashed.add(sessionId);
    return CommandOk(sessionId, const Version(2), const []);
  }

  @override
  Future<CommandResult> restoreSession(String sessionId) async {
    calls.add('h.restore:$sessionId');
    trashed.remove(sessionId);
    return CommandOk(sessionId, const Version(3), const []);
  }

  @override
  Future<CommandResult> startSession({required String title, required AiPurpose purpose}) => throw UnimplementedError();
  @override
  Future<CommandResult> renameSession(String sessionId, String title) => throw UnimplementedError();
  @override
  Future<CommandResult> addMessage(String sessionId, AiMessageRole role, String text,
          {String? model, AiEngineSite? site, List<(RecordRef, int?)> sentRefs = const []}) =>
      throw UnimplementedError();
  @override
  Future<CommandResult> addProposal(String sessionId,
          {required String model, required AiEngineSite site, required List<ProposedChange> changes, String? messageId, String note = ''}) =>
      throw UnimplementedError();
}

const tinyModel = LocalModelInfo(
  id: 'qwen-08',
  name: 'Qwen 3.5 0.8B',
  fileName: 'q08.gguf',
  url: 'https://example.org/q08.gguf',
  sizeBytes: 532517120,
  sha256: 'aa',
  license: 'Apache-2.0',
  licenseUrl: 'https://example.org/LICENSE',
  platforms: {LocalPlatform.windows, LocalPlatform.android},
  slowOn: {LocalPlatform.android},
  memoryGb: 0.8,
);
const bigModel = LocalModelInfo(
  id: 'qwen-2',
  name: 'Qwen 3.5 2B',
  fileName: 'q2.gguf',
  url: 'https://example.org/q2.gguf',
  sizeBytes: 1280835840,
  sha256: 'bb',
  license: 'Apache-2.0',
  licenseUrl: 'https://example.org/LICENSE',
  platforms: {LocalPlatform.windows},
  recommendedOn: {LocalPlatform.windows},
  memoryGb: 1.4,
);

class FakeModels implements LocalModelService {
  FakeModels(this.calls, this.platform);
  final List<String> calls;
  final LocalPlatform platform;
  final installedList = <InstalledModel>[];
  String? selectedId;

  /// Completed by the test to finish a download.
  Completer<void>? gate;

  InstalledModel _of(LocalModelInfo m) =>
      InstalledModel(id: m.id, name: m.name, path: '/m/${m.fileName}', sizeBytes: m.sizeBytes, sha256: m.sha256, license: m.license);

  @override
  List<LocalModelInfo> catalog() => [for (final m in [bigModel, tinyModel]) if (m.platforms.contains(platform)) m];
  @override
  Future<List<InstalledModel>> installed() async => [...installedList];

  @override
  Future<InstalledModel> download(String id, {void Function(int received, int total)? onProgress, AiCancel? cancel}) async {
    calls.add('m.download:$id');
    final m = catalog().firstWhere((m) => m.id == id);
    onProgress?.call(m.sizeBytes ~/ 4, m.sizeBytes);
    if (gate != null) await gate!.future;
    if (cancel?.isCancelled ?? false) throw const LocalModelFailure(LocalModelFailureKind.cancelled);
    onProgress?.call(m.sizeBytes, m.sizeBytes);
    final got = _of(m);
    installedList.add(got);
    return got;
  }

  @override
  Future<InstalledModel> importFile(String path, {AiCancel? cancel}) async {
    calls.add('m.import:$path');
    if (!path.endsWith('.gguf')) throw const LocalModelFailure(LocalModelFailureKind.notGguf);
    final m = InstalledModel(id: 'file-1', name: 'Mine.gguf', path: path, sizeBytes: 4000000000, sha256: 'cc', fromFile: true);
    installedList.add(m);
    return m;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('m.delete:$id');
    installedList.removeWhere((m) => m.id == id);
    if (selectedId == id) selectedId = null;
  }

  @override
  Future<InstalledModel?> selected() async => installedList.where((m) => m.id == selectedId).firstOrNull;
  @override
  Future<void> select(String? id) async {
    calls.add('m.select:$id');
    selectedId = id;
  }
}

class FakeSetup implements AiSetupService {
  FakeSetup(this.calls, {this.platform = LocalPlatform.windows}) : models = FakeModels(calls, platform);
  final List<String> calls;
  @override
  final LocalPlatform platform;
  @override
  final FakeModels models;
  AiAssistantSettings current = const AiAssistantSettings();
  CloudAiConfig? cloudConfig;
  final keys = <CloudProvider, String>{};
  List<String> modelList = const ['model-a', 'model-b'];
  int used = 1234;

  @override
  Future<AiAssistantSettings> settings() async => current;
  @override
  Future<void> setSettings(AiAssistantSettings s) async {
    calls.add('s.settings:${s.preferred.name}:${s.cloudEnabled}:${s.dayStart}-${s.dayEnd}:${s.language}');
    current = s;
  }

  @override
  Future<CloudAiConfig?> cloud() async => cloudConfig;
  @override
  Future<void> setCloud(CloudAiConfig? c) async {
    calls.add('s.cloud:${c?.provider.name}:${c?.model}:${c?.baseUrl}:${c?.monthlyTokenCap}');
    cloudConfig = c;
  }

  @override
  Future<bool> hasKey(CloudProvider p) async => keys.containsKey(p);
  @override
  Future<void> setKey(CloudProvider p, String? key) async {
    calls.add('s.key:${p.name}:${key == null || key.trim().isEmpty ? 'forget' : 'set'}');
    if (key == null || key.trim().isEmpty) {
      keys.remove(p);
    } else {
      keys[p] = key;
    }
  }

  @override
  Future<List<String>> cloudModels(CloudProvider p, {String? baseUrl}) async {
    calls.add('s.models:${p.name}');
    return modelList;
  }

  @override
  Future<int> tokensThisMonth() async => used;
}
