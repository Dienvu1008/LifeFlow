// P06 T6 (ADR-0086; ai-architecture.md §2, §4; the owner's D1, D6, D8, D9):
// the assistant's turns, and how a request finds its engine.
//   turns     "plan my day" and "fix a conflict" give a proposal (nothing
//             changes until the person approves each change); "ask about
//             this document or PDF" gives an answer and changes nothing
//   routing   the person's preferred engine first. An engine that would have
//             to leave out an item the request needs (Restricted toward the
//             cloud) is passed over for the next; one that only needs the
//             person's consent stops there and asks. With no engine left the
//             request is declined: privacy is never lowered to get an answer
//             (OQ-AI-2)
import 'package:foundation/foundation.dart';

import 'ai.dart';
import 'ai_engine.dart';

enum AiTurnOutcome {
  /// A proposal was made (plan, conflict).
  proposed,

  /// An answer was given (document), or a plan with nothing to place.
  answered,

  /// Items the request needs wait for the person's consent (D6): ask, then
  /// call again with them consented, or "send without these".
  needsConsent,

  /// No engine may take the request, or the shown space is not personal.
  declined,

  /// Nothing to do (no task to plan, no conflict that day).
  nothingToDo,

  /// The engine failed ([AiTurnResult.failure]).
  failed,
}

class AiTurnResult {
  const AiTurnResult(
    this.outcome, {
    this.sessionId,
    this.proposalId,
    this.messageId,
    this.site,
    this.model,
    this.lines = const [],
    this.reason,
    this.failure,
    this.text = '',
    this.unplaced = const [],
    this.moved = const [],
  });
  final AiTurnOutcome outcome;
  final String? sessionId;
  final String? proposalId;

  /// The assistant's message of the turn.
  final String? messageId;
  final AiEngineSite? site;
  final String? model;

  /// Every item the request was built from and what happened to it (for
  /// the consent sheet: what would be sent, what waits, what is left out).
  final List<AiEgressLine> lines;
  final String? reason;
  final AiEngineFailureKind? failure;

  /// The answer, or the plan's note.
  final String text;

  /// Tasks of the plan with no room that day, and tasks placed elsewhere
  /// than the model said (by the code's checks), by id.
  final List<String> unplaced;
  final List<String> moved;

  List<AiEgressLine> get waitingForConsent => [for (final l in lines) if (!l.sent && l.egress == AiEgress.needsConsent) l];
}

/// The person's assistant settings (T7 shows them).
class AiAssistantSettings {
  const AiAssistantSettings({
    this.preferred = AiEngineSite.device,
    this.cloudEnabled = false,
    this.dayStart = 8 * 60,
    this.dayEnd = 18 * 60,
    this.language = 'vi',
  });

  /// Which engine to try first.
  final AiEngineSite preferred;

  /// The cloud option (D2: off by default).
  final bool cloudEnabled;

  /// The hours a day plan may use, in minutes of the day.
  final int dayStart;
  final int dayEnd;

  /// The language of the app's own words in a plan ('vi' or 'en'); an
  /// answer follows the person's question (D9).
  final String language;
}

abstract interface class AiAssistant {
  /// A proposal placing the open tasks of [date] (unscheduled, or planned
  /// for that day without a time) around its fixed events and timed items.
  Future<AiTurnResult> planDay(LocalDate date,
      {String? sessionId, String? request, Set<RecordRef> consented, bool withoutUnconsented});

  /// A proposal moving the timed tasks of [date] that overlap something.
  Future<AiTurnResult> fixConflicts(LocalDate date,
      {String? sessionId, Set<RecordRef> consented, bool withoutUnconsented});

  /// An answer about a document or a PDF ([item]: `document:<id>`,
  /// `file:<hash>` or `file:<hash>#<page>`), written as it comes.
  Future<AiTurnResult> askDocument(RecordRef item, String question,
      {String? sessionId, Set<RecordRef> consented, bool withoutUnconsented, void Function(String text)? onText});

  /// P06b W4 (ADR-0088): one turn of a free chat. The earlier turns of
  /// [sessionId] go with it (as private data, through the checkpoint), and
  /// so do the shown space's next days and what the profile's spaces hold
  /// about [message]. The answer may come with a proposal (tasks of the
  /// personal space to create, rename or schedule), approved by the person.
  Future<AiTurnResult> chat(String message, {String? sessionId, Set<RecordRef> consented, bool withoutUnconsented});

  /// Stops the answer being written.
  Future<void> stop();
}

/// Where a request goes, or why it does not.
class AiRoute {
  const AiRoute._(this.outcome, {this.engine, this.request, this.lines = const [], this.reason});
  final AiTurnOutcome outcome;
  final AiEngine? engine;
  final CheckedAiRequest? request;
  final List<AiEgressLine> lines;
  final String? reason;
  bool get ready => engine != null && request != null;
}

/// The route of a request built from [context] (ai-architecture.md §4).
/// [engines] in the person's order of preference; one whose [AiEngine.model]
/// is null is not set up. [needed]: the items the request is about (the
/// tasks to plan, the document); the rest is helpful context. With
/// [withoutUnconsented], items waiting for consent are left out ("send
/// without these"), and a request left with none of what it needs is not
/// sent.
Future<AiRoute> chooseAiRoute({
  required List<AiEngine> engines,
  required AiEgressPolicy policy,
  required AiContext context,
  required String instructions,
  required String question,
  required Set<RecordRef> needed,
  Set<RecordRef> consented = const {},
  bool withoutUnconsented = false,
}) async {
  final reasons = <String>[];
  for (final e in engines) {
    if (await e.model() == null) {
      reasons.add('${e.site.name}: not set up');
      continue;
    }
    final req = checkAiEgress(
        site: e.site, policy: policy, context: context, instructions: instructions, question: question, consented: consented);
    final neededLines = [for (final l in req.lines) if (needed.contains(l.item.ref)) l];
    if (neededLines.any((l) => l.egress == AiEgress.deny)) {
      // Hard rule: what this engine may never get (Restricted toward the
      // cloud, anything with the cloud off) sends the request elsewhere.
      reasons.add('${e.site.name}: may not receive what the request is about');
      continue;
    }
    final waiting = [for (final l in neededLines) if (!l.sent) l];
    if (waiting.isNotEmpty && !withoutUnconsented) {
      return AiRoute._(AiTurnOutcome.needsConsent, engine: e, lines: req.lines, reason: 'consent needed');
    }
    if (needed.isNotEmpty && !neededLines.any((l) => l.sent)) {
      return AiRoute._(AiTurnOutcome.declined, lines: req.lines, reason: 'nothing the request is about may be sent');
    }
    return AiRoute._(AiTurnOutcome.proposed, engine: e, request: req, lines: req.lines);
  }
  return AiRoute._(AiTurnOutcome.declined,
      reason: reasons.isEmpty ? 'no assistant engine is set up' : reasons.join('; '));
}

/// P06 T7 (ADR-0087): what the assistant's settings screen reads and changes.
/// The settings and the cloud choice belong to the profile (another profile
/// on the device does not inherit the cloud option); the models are the
/// device's; the keys are the profile's, in secure storage.
abstract interface class AiSetupService {
  Future<AiAssistantSettings> settings();
  Future<void> setSettings(AiAssistantSettings settings);

  /// The cloud model set up, or null.
  Future<CloudAiConfig?> cloud();
  Future<void> setCloud(CloudAiConfig? config);

  /// Whether a key is kept for [provider] (the key itself is never shown).
  Future<bool> hasKey(CloudProvider provider);

  /// Keeps [key] for [provider]; null or blank forgets it.
  Future<void> setKey(CloudProvider provider, String? key);

  /// The models [provider] offers to the kept key.
  Future<List<String>> cloudModels(CloudProvider provider, {String? baseUrl});

  /// Tokens used this calendar month on this device.
  Future<int> tokensThisMonth();

  /// The models of this device.
  LocalModelService get models;

  /// The platform, for the model list and its warnings.
  LocalPlatform get platform;
}
