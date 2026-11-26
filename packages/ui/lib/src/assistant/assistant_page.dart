// P06 T7 (ADR-0087; the owner's D1, D6, D8): the assistant on screen.
//   plan / fix   a day chosen; the proposal with each change on its own,
//                "Approve all", dismiss; a stale change shown, "Regenerate"
//   consent      before private items go to a cloud model: what would be
//                sent, what waits, what is never sent; "Send", "Send
//                without these" (D6)
//   history      the conversations, each with its messages and proposals
//   ask          a question about a document or a PDF, answered as it comes
// Nothing changes until the person approves (LF-INV-AI-001).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../l10n.dart';
import '../providers.dart';
import 'chat_view.dart' show AiChatPage;

/// Opens the assistant on [date] (today by default); with [run], that turn
/// starts at once (P06b W4: the chat's shortcuts).
Future<void> openAssistantPage(BuildContext context, {LocalDate? date, AiPurpose? run}) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute<void>(builder: (_) => AssistantPage(date: date, run: run)));

/// What the person chose on the consent sheet.
enum AiConsentChoice { send, without }

String aiClassLabel(BuildContext context, DataClassification c) => switch (c) {
      DataClassification.public => context.l10n.aiClassPublic,
      DataClassification.personal => context.l10n.aiClassPersonal,
      DataClassification.confidential => context.l10n.aiClassConfidential,
      DataClassification.restricted => context.l10n.aiClassRestricted,
    };

/// D6: what a request to the cloud would carry, before it goes.
Future<AiConsentChoice?> showAiConsentSheet(BuildContext context, AiTurnResult result) {
  final l = context.l10n;
  final waiting = result.waitingForConsent;
  final denied = [for (final x in result.lines) if (x.egress == AiEgress.deny) x];
  Widget line(AiEgressLine x) => ListTile(
        dense: true,
        leading: Icon(x.egress == AiEgress.deny ? Icons.block : Icons.lock_outline),
        title: Text(x.item.title.isEmpty ? '${x.item.ref}' : x.item.title),
        subtitle: Text(aiClassLabel(context, x.item.classification)),
      );
  return showModalBottomSheet<AiConsentChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(key: const Key('ai-consent-sheet'), shrinkWrap: true, children: [
          ListTile(title: Text(l.aiConsentTitle, style: Theme.of(context).textTheme.titleMedium), subtitle: Text(l.aiConsentBody)),
          if (waiting.isNotEmpty) ListTile(dense: true, title: Text(l.aiConsentWaiting, style: Theme.of(context).textTheme.labelLarge)),
          for (final x in waiting) line(x),
          if (denied.isNotEmpty) ListTile(dense: true, title: Text(l.aiConsentLeftOut, style: Theme.of(context).textTheme.labelLarge)),
          for (final x in denied) line(x),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
              OutlinedButton(
                  key: const Key('ai-consent-without'),
                  onPressed: () => Navigator.pop(context, AiConsentChoice.without),
                  child: Text(l.aiConsentWithout)),
              FilledButton(
                  key: const Key('ai-consent-send'),
                  onPressed: () => Navigator.pop(context, AiConsentChoice.send),
                  child: Text(l.aiConsentSend)),
            ]),
          ),
        ]),
      ),
    ),
  );
}

/// The person's words for a turn that did not give a proposal or an answer.
String? aiOutcomeText(BuildContext context, AiTurnResult r, AiPurpose purpose) {
  final l = context.l10n;
  switch (r.outcome) {
    case AiTurnOutcome.proposed:
    case AiTurnOutcome.needsConsent:
      return null;
    case AiTurnOutcome.answered:
      return r.proposalId == null && (purpose == AiPurpose.planDay || purpose == AiPurpose.fixConflict) ? l.aiNothingPlaced : null;
    case AiTurnOutcome.nothingToDo:
      if (purpose == AiPurpose.chat) return null;
      return purpose == AiPurpose.fixConflict ? l.aiNoConflicts : l.aiNothingToPlan;
    case AiTurnOutcome.declined:
      final why = r.reason ?? '';
      if (why.contains('personal space')) return l.aiDeclinedSpace;
      if (why.contains('not set up')) return l.aiDeclinedNoEngine;
      return l.aiDeclinedPrivacy;
    case AiTurnOutcome.failed:
      return switch (r.failure) {
        AiEngineFailureKind.notReady || AiEngineFailureKind.wrongSite => l.aiFailNotReady,
        AiEngineFailureKind.unauthorized => l.aiFailUnauthorized,
        AiEngineFailureKind.rateLimited => l.aiFailRateLimited,
        AiEngineFailureKind.network => l.aiFailNetwork,
        AiEngineFailureKind.capReached => l.aiFailCap,
        AiEngineFailureKind.refused => l.aiFailRefused,
        AiEngineFailureKind.malformedOutput => l.aiFailMalformed,
        AiEngineFailureKind.stopped => l.aiFailStopped,
        _ => l.aiFailOther(r.reason ?? ''),
      };
  }
}

String aiEngineLine(BuildContext context, AiEngineSite? site, String? model) => site == AiEngineSite.cloud
    ? context.l10n.aiViaCloud(model ?? '')
    : context.l10n.aiViaDevice(model ?? '');

/// Runs a turn, asking for consent when it needs it (D6), then once more.
Future<AiTurnResult?> runAiTurn(
  BuildContext context,
  Future<AiTurnResult> Function({Set<RecordRef> consented, bool withoutUnconsented}) turn,
) async {
  var r = await turn(consented: const {}, withoutUnconsented: false);
  if (r.outcome != AiTurnOutcome.needsConsent) return r;
  if (!context.mounted) return null;
  final choice = await showAiConsentSheet(context, r);
  if (choice == null) return null;
  // "Send without these" consents to nothing: the waiting items stay out.
  r = await turn(
    consented: choice == AiConsentChoice.send ? {for (final x in r.waitingForConsent) x.item.ref} : const {},
    withoutUnconsented: choice == AiConsentChoice.without,
  );
  return r;
}

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key, this.date, this.run});
  final LocalDate? date;

  /// A turn to start when the page opens (plan the day, fix conflicts).
  final AiPurpose? run;

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  late LocalDate _date = widget.date ?? ref.read(todayProvider)();
  final _note = TextEditingController();
  bool _busy = false;
  AiTurnResult? _result;
  AiPurpose _purpose = AiPurpose.planDay;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    if (widget.run case final run?) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _run(run) : null);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(AiPurpose purpose) async {
    final ai = ref.read(aiAssistantProvider);
    if (ai == null || _busy) return;
    setState(() {
      _busy = true;
      _purpose = purpose;
    });
    try {
      final r = await runAiTurn(
          context,
          ({Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) => purpose == AiPurpose.fixConflict
              ? ai.fixConflicts(_date, sessionId: _sessionId, consented: consented, withoutUnconsented: withoutUnconsented)
              : ai.planDay(_date,
                  sessionId: _sessionId, request: _note.text, consented: consented, withoutUnconsented: withoutUnconsented));
      if (!mounted || r == null) return;
      setState(() {
        _result = r;
        _sessionId = r.sessionId ?? _sessionId;
      });
      ref.invalidate(aiSessionsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime(_date.year, _date.month, _date.day);
    final picked = await showDatePicker(
        context: context, initialDate: now, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 365)));
    if (picked != null && mounted) setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = _result;
    final message = r == null ? null : aiOutcomeText(context, r, _purpose);
    return Scaffold(
      appBar: AppBar(title: Text(l.aiAssistant)),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        ListTile(
          key: const Key('ai-day'),
          leading: const Icon(Icons.event),
          title: Text(l.aiDayLabel('$_date')),
          trailing: IconButton(tooltip: l.aiChangeDay, icon: const Icon(Icons.edit_calendar), onPressed: _busy ? null : _pickDate),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const Key('ai-note'),
            controller: _note,
            enabled: !_busy,
            maxLength: 500,
            decoration: InputDecoration(labelText: l.aiYourNote, counterText: ''),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
                key: const Key('ai-plan-day'),
                onPressed: _busy ? null : () => _run(AiPurpose.planDay),
                icon: const Icon(Icons.auto_awesome),
                label: Text(l.aiPlanMyDay)),
            OutlinedButton.icon(
                key: const Key('ai-fix-conflicts'),
                onPressed: _busy ? null : () => _run(AiPurpose.fixConflict),
                icon: const Icon(Icons.call_split),
                label: Text(l.aiFixConflicts)),
            if (_busy)
              TextButton.icon(
                  key: const Key('ai-stop'),
                  onPressed: () => ref.read(aiAssistantProvider)?.stop(),
                  icon: const Icon(Icons.stop),
                  label: Text(l.aiStop)),
          ]),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [const LinearProgressIndicator(), const SizedBox(height: 8), Text(l.aiWorking)]),
          ),
        if (message != null) ListTile(key: const Key('ai-message'), leading: const Icon(Icons.info_outline), title: Text(message)),
        if (r != null && r.outcome == AiTurnOutcome.answered && r.proposalId == null && r.text.isNotEmpty)
          ListTile(title: Text(r.text)),
        if (r != null && r.proposalId != null && r.sessionId != null)
          ProposalCard(
            key: ValueKey('ai-proposal-${r.proposalId}'),
            sessionId: r.sessionId!,
            proposalId: r.proposalId!,
            onRegenerate: _busy ? null : () => _run(_purpose),
          ),
        const Divider(height: 32),
        const AiHistoryList(),
      ]),
    );
  }
}

String aiStatusLabel(BuildContext context, AiChangeStatus s) => switch (s) {
      AiChangeStatus.proposed => context.l10n.aiStatusProposed,
      AiChangeStatus.applied => context.l10n.aiStatusApplied,
      AiChangeStatus.stale => context.l10n.aiStatusStale,
      AiChangeStatus.failed => context.l10n.aiStatusFailed,
      AiChangeStatus.dismissed => context.l10n.aiStatusDismissed,
    };

/// One proposal: its note, each change with its status, approve each or
/// all (D8), dismiss; a stale change offers "Regenerate".
class ProposalCard extends ConsumerStatefulWidget {
  const ProposalCard({super.key, required this.sessionId, required this.proposalId, this.onRegenerate});
  final String sessionId;
  final String proposalId;
  final VoidCallback? onRegenerate;

  @override
  ConsumerState<ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends ConsumerState<ProposalCard> {
  AiProposalView? _p;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = ref.read(aiHistoryProvider);
    if (h == null) return;
    final all = await h.proposals(widget.sessionId);
    if (mounted) setState(() => _p = all.where((p) => p.id == widget.proposalId).firstOrNull);
  }

  Future<void> _act(Future<Object?> Function(AiHistoryService h) f) async {
    final h = ref.read(aiHistoryProvider);
    if (h == null || _busy) return;
    setState(() => _busy = true);
    try {
      await f(h);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _p;
    if (p == null) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
    final open = p.changes.where((c) => c.status == AiChangeStatus.proposed).length;
    final stale = p.changes.any((c) => c.status == AiChangeStatus.stale);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          title: Text(aiEngineLine(context, p.site, p.model)),
          subtitle: Text(p.note.isEmpty ? l.aiNothingChangesUntil : '${p.note}\n${l.aiNothingChangesUntil}'),
        ),
        for (final c in p.changes)
          ListTile(
            key: ValueKey('ai-change-${c.change.id}'),
            leading: Icon(switch (c.status) {
              AiChangeStatus.applied => Icons.check_circle,
              AiChangeStatus.stale => Icons.update,
              AiChangeStatus.failed => Icons.error_outline,
              AiChangeStatus.dismissed => Icons.remove_circle_outline,
              AiChangeStatus.proposed => Icons.schedule,
            }),
            title: Text(c.change.summary),
            subtitle: Text(aiStatusLabel(context, c.status)),
            trailing: c.status != AiChangeStatus.proposed
                ? null
                : Wrap(spacing: 4, children: [
                    IconButton(
                        key: ValueKey('ai-dismiss-${c.change.id}'),
                        tooltip: l.aiDismiss,
                        icon: const Icon(Icons.close),
                        onPressed: _busy ? null : () => _act((h) => h.dismiss(p.id, c.change.id))),
                    IconButton(
                        key: ValueKey('ai-approve-${c.change.id}'),
                        tooltip: l.aiApprove,
                        icon: const Icon(Icons.check),
                        onPressed: _busy ? null : () => _act((h) => h.approve(p.id, c.change.id))),
                  ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(spacing: 8, alignment: WrapAlignment.end, children: [
            if (stale && widget.onRegenerate != null)
              OutlinedButton.icon(
                  key: const Key('ai-regenerate'),
                  onPressed: _busy ? null : widget.onRegenerate,
                  icon: const Icon(Icons.refresh),
                  label: Text(l.aiRegenerate)),
            if (open > 1)
              FilledButton(
                  key: const Key('ai-approve-all'),
                  onPressed: _busy ? null : () => _act((h) => h.approveAll(p.id)),
                  child: Text(l.aiApproveAll)),
          ]),
        ),
      ]),
    );
  }
}

/// The conversations; a tap opens one, a delete goes to the trash with Undo.
class AiHistoryList extends ConsumerWidget {
  const AiHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sessions = ref.watch(aiSessionsProvider).valueOrNull ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(l.aiHistory, style: Theme.of(context).textTheme.titleSmall),
      ),
      if (sessions.isEmpty) ListTile(key: const Key('ai-no-history'), title: Text(l.aiNoHistory)),
      for (final s in sessions)
        ListTile(
          key: ValueKey('ai-session-${s.id}'),
          leading: Icon(switch (s.purpose) {
            AiPurpose.planDay => Icons.auto_awesome,
            AiPurpose.fixConflict => Icons.call_split,
            AiPurpose.askDocument => Icons.question_answer_outlined,
            AiPurpose.chat => Icons.chat_bubble_outline,
          }),
          title: Text(s.title),
          subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(s.updatedAt.toLocal())),
          trailing: IconButton(
            key: ValueKey('ai-delete-${s.id}'),
            tooltip: l.aiDeleteSession,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final h = ref.read(aiHistoryProvider);
              if (h == null) return;
              await h.trashSession(s.id);
              ref.invalidate(aiSessionsProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l.aiSessionDeleted),
                action: SnackBarAction(
                    label: l.undo,
                    onPressed: () async {
                      await h.restoreSession(s.id);
                      ref.invalidate(aiSessionsProvider);
                    }),
              ));
            },
          ),
          // P06b W4: a chat opens to go on with it; the other turns as they were.
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => s.purpose == AiPurpose.chat ? AiChatPage(session: s) : AiSessionPage(session: s))),
        ),
    ]);
  }
}

/// One conversation: its messages and proposals, in order.
class AiSessionPage extends ConsumerWidget {
  const AiSessionPage({super.key, required this.session});
  final AiSessionView session;

  Future<(List<AiMessageView>, List<AiProposalView>)> _load(AiHistoryService h) async =>
      (await h.messages(session.id), await h.proposals(session.id));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(aiHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(session.title)),
      body: h == null
          ? const SizedBox.shrink()
          : FutureBuilder<(List<AiMessageView>, List<AiProposalView>)>(
              future: _load(h),
              builder: (context, snap) {
                final data = snap.data;
                if (data == null) return const Center(child: CircularProgressIndicator());
                final (messages, proposals) = data;
                return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  for (final m in messages) ...[
                    ListTile(
                      key: ValueKey('ai-msg-${m.id}'),
                      leading: Icon(m.role == AiMessageRole.person ? Icons.person_outline : Icons.auto_awesome),
                      title: SelectableText(m.text),
                      subtitle: m.role == AiMessageRole.assistant ? Text(aiEngineLine(context, m.site, m.model)) : null,
                    ),
                    for (final p in proposals.where((p) => p.messageId == m.id))
                      ProposalCard(key: ValueKey('ai-proposal-${p.id}'), sessionId: session.id, proposalId: p.id),
                  ],
                ]);
              },
            ),
    );
  }
}

/// Asks the assistant about [item] (a document, a PDF or one page of it).
Future<void> showAskAssistant(BuildContext context, RecordRef item) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AskAssistantSheet(item: item),
      ),
    );

class AskAssistantSheet extends ConsumerStatefulWidget {
  const AskAssistantSheet({super.key, required this.item});
  final RecordRef item;

  @override
  ConsumerState<AskAssistantSheet> createState() => _AskAssistantSheetState();
}

class _AskAssistantSheetState extends ConsumerState<AskAssistantSheet> {
  final _q = TextEditingController();
  String _answer = '';
  String? _message;
  String? _sessionId;
  AiEngineSite? _site;
  String? _model;
  bool _busy = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final ai = ref.read(aiAssistantProvider);
    final question = _q.text.trim();
    if (ai == null || question.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _answer = '';
      _message = null;
    });
    try {
      final r = await runAiTurn(
          context,
          ({Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) => ai.askDocument(widget.item, question,
              sessionId: _sessionId,
              consented: consented,
              withoutUnconsented: withoutUnconsented,
              onText: (t) {
                if (mounted) setState(() => _answer = t);
              }));
      if (!mounted || r == null) return;
      setState(() {
        _sessionId = r.sessionId ?? _sessionId;
        _site = r.site;
        _model = r.model;
        if (r.text.isNotEmpty) _answer = r.text;
        _message = aiOutcomeText(context, r, AiPurpose.askDocument);
      });
      ref.invalidate(aiSessionsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: ListView(key: const Key('ai-ask-sheet'), shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        Text(l.aiAskTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('ai-ask-question'),
          controller: _q,
          autofocus: true,
          enabled: !_busy,
          maxLength: 2000,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(labelText: l.aiAskHint, counterText: ''),
          onSubmitted: (_) => _ask(),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, alignment: WrapAlignment.end, children: [
          if (_busy)
            TextButton.icon(
                key: const Key('ai-ask-stop'),
                onPressed: () => ref.read(aiAssistantProvider)?.stop(),
                icon: const Icon(Icons.stop),
                label: Text(l.aiStop)),
          FilledButton(key: const Key('ai-ask-send'), onPressed: _busy ? null : _ask, child: Text(l.aiAsk)),
        ]),
        if (_busy && _answer.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        if (_answer.isNotEmpty) ...[
          const SizedBox(height: 12),
          SelectableText(_answer, key: const Key('ai-ask-answer')),
          if (_site != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(aiEngineLine(context, _site, _model), style: Theme.of(context).textTheme.bodySmall)),
        ],
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, key: const Key('ai-ask-message'))),
      ]),
    );
  }
}
