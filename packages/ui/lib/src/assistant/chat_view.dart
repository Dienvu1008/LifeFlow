// P06b W4 (ADR-0088; the owner's change of P06 D1): the Assistant
// destination and its free chat.
//   screen    the chat; before a first message, what it can do, the day's
//             tools (plan my day, fix conflicts) and the history
//   chat      the person's message, the answer, and a proposal under it when
//             the assistant suggests changes (approved each or all, D8);
//             consent before private items go to a cloud model (D6); the
//             earlier turns of the chat go with each new one
//   history   a chat opens again where it was left
// Nothing changes until the person approves (LF-INV-AI-001).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../providers.dart';
import '../shell.dart' show shellMenuButton;
import '../widgets/options_menu.dart';
import 'assistant_page.dart';

/// The Assistant destination: a chat, a new one on "New chat".
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  String? _session;
  int _chat = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ai = ref.watch(aiAssistantProvider);
    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: Text(l.navAssistant),
        actions: [
          if (_session != null)
            IconButton(
              key: const Key('ai-new-chat'),
              tooltip: l.aiNewChat,
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () => setState(() {
                _session = null;
                _chat++;
              }),
            ),
          OptionsMenu(options: [
            MenuOption(
                key: const Key('ai-open-settings'),
                label: l.aiSettingsMenu,
                icon: Icons.tune,
                onSelected: () => context.go('/settings/assistant')),
          ]),
        ],
      ),
      body: ai == null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.aiNotAvailable, key: const Key('ai-not-available'), textAlign: TextAlign.center)))
          : AiChatView(key: ValueKey('ai-chat-$_chat'), onSession: (s) => setState(() => _session = s)),
    );
  }
}

/// A chat opened from the history, to go on with it.
class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key, required this.session});
  final AiSessionView session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(session.title, overflow: TextOverflow.ellipsis)),
        body: AiChatView(sessionId: session.id),
      );
}

/// The messages of one chat and the field to write the next one.
class AiChatView extends ConsumerStatefulWidget {
  const AiChatView({super.key, this.sessionId, this.onSession});

  /// The chat to go on with; a new one when null.
  final String? sessionId;

  /// Told the chat's id once its first turn made it.
  final ValueChanged<String?>? onSession;

  @override
  ConsumerState<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends ConsumerState<AiChatView> {
  late String? _session = widget.sessionId;
  final _field = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  String? _pending;
  String? _message;
  List<AiMessageView> _messages = const [];
  List<AiProposalView> _proposals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final h = ref.read(aiHistoryProvider);
    final s = _session;
    if (h == null || s == null) return;
    final messages = await h.messages(s);
    final proposals = await h.proposals(s);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _proposals = proposals;
    });
    _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  Future<void> _send() async {
    final ai = ref.read(aiAssistantProvider);
    final text = _field.text.trim();
    if (ai == null || text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _pending = text;
      _message = null;
    });
    _field.clear();
    _toEnd();
    try {
      final r = await runAiTurn(
          context,
          ({Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) =>
              ai.chat(text, sessionId: _session, consented: consented, withoutUnconsented: withoutUnconsented));
      if (!mounted) return;
      // Not sent (consent cancelled) or not kept: the words come back to
      // the field, so nothing typed is lost.
      if (r == null || r.messageId == null) _field.text = text;
      if (r != null) {
        _message = aiOutcomeText(context, r, AiPurpose.chat);
        if (r.sessionId != null && r.sessionId != _session) {
          _session = r.sessionId;
          widget.onSession?.call(_session);
        }
      }
      ref.invalidate(aiSessionsProvider);
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pending = null;
        });
      }
    }
  }

  Widget _bubble(BuildContext context, {required Key key, required bool mine, required String text, String? by}) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      key: key,
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Semantics(label: mine ? context.l10n.aiYou : context.l10n.aiAssistant, child: SelectableText(text)),
            if (by != null) ...[
              const SizedBox(height: 4),
              Text(by, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(l.aiChatIntro, key: const Key('ai-chat-intro')),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(
            key: const Key('ai-chip-plan'),
            avatar: const Icon(Icons.auto_awesome, size: 18),
            label: Text(l.aiPlanMyDay),
            onPressed: () => openAssistantPage(context, run: AiPurpose.planDay),
          ),
          ActionChip(
            key: const Key('ai-chip-fix'),
            avatar: const Icon(Icons.call_split, size: 18),
            label: Text(l.aiFixConflicts),
            onPressed: () => openAssistantPage(context, run: AiPurpose.fixConflict),
          ),
        ]),
      ),
      const Divider(height: 32),
      const AiHistoryList(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fresh = _session == null && _messages.isEmpty && _pending == null;
    return Column(children: [
      Expanded(
        child: ListView(key: const Key('ai-chat'), controller: _scroll, padding: const EdgeInsets.only(bottom: 12), children: [
          if (fresh) _intro(context),
          for (final m in _messages) ...[
            _bubble(context,
                key: ValueKey('ai-msg-${m.id}'),
                mine: m.role == AiMessageRole.person,
                text: m.text,
                by: m.role == AiMessageRole.assistant ? aiEngineLine(context, m.site, m.model) : null),
            for (final p in _proposals.where((p) => p.messageId == m.id))
              ProposalCard(key: ValueKey('ai-proposal-${p.id}'), sessionId: p.sessionId, proposalId: p.id),
          ],
          if (_pending case final t?) _bubble(context, key: const Key('ai-pending'), mine: true, text: t),
          if (_busy)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Expanded(child: LinearProgressIndicator()),
                const SizedBox(width: 12),
                TextButton.icon(
                    key: const Key('ai-stop'),
                    onPressed: () => ref.read(aiAssistantProvider)?.stop(),
                    icon: const Icon(Icons.stop),
                    label: Text(l.aiStop)),
              ]),
            ),
          if (_message case final m?)
            ListTile(key: const Key('ai-message'), leading: const Icon(Icons.info_outline), title: Text(m)),
        ]),
      ),
      const Divider(height: 1),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                key: const Key('ai-chat-field'),
                controller: _field,
                enabled: !_busy,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(hintText: l.aiChatHint, counterText: '', border: const OutlineInputBorder(), isDense: true),
              ),
            ),
            IconButton(
              key: const Key('ai-chat-send'),
              tooltip: l.aiChatSend,
              icon: const Icon(Icons.send),
              onPressed: _busy ? null : _send,
            ),
          ]),
        ),
      ),
    ]);
  }
}
