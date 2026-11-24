// P06 T2 (ADR-0081; ai-architecture.md §3, ADR-0016): the context a model
// gets, and the one gate it passes before it leaves for a model.
//   context     the Context Builder gathers only what the request is about
//               (named items, a document and its PDF text, search hits),
//               in the shown space, live, classified; bounded in size
//   checkpoint  [checkAiEgress] decides each item with the domain's rule
//               (allow, consent, deny); only what may go is put in the
//               request, as tagged untrusted data. A [CheckedAiRequest] can
//               only be made here, so an engine cannot be given an unchecked
//               one (FF-ARCH-08, LF-INV-PRIV-003)
//   history     (P06 T3, ADR-0082; the owner's D7) sessions, messages and
//               proposals are records: synced, exported, deletable, in the
//               personal space only. A change runs only when the person
//               approves it, as them, bound to its arguments and versions;
//               one computed against something that changed since is stale
//               and nothing is written (LF-INV-AI-001/002, GS-15)
import 'dart:convert';

import 'package:domain/domain.dart';

import 'command.dart';

export 'package:domain/domain.dart'
    show
        AiApproval,
        AiChangeRecord,
        AiChangeStatus,
        AiEgress,
        AiEgressPolicy,
        AiEngineSite,
        AiPolicyContext,
        AiProposal,
        ApprovalProblem,
        DataClassification,
        ProposedChange,
        RecordRef,
        aiEgressOf,
        aiMaySend,
        approvalProblem,
        approveChange,
        canonicalArguments,
        decodeAiChanges,
        encodeAiChanges;

/// What a request is about (P06 D1).
enum AiPurpose { planDay, fixConflict, askDocument }

/// What to put in a request's context: the named things (the screen, a
/// selection, the items of the day) and, optionally, search hits for words.
class AiContextRequest {
  const AiContextRequest({required this.purpose, this.named = const [], this.query});
  final AiPurpose purpose;
  final List<RecordRef> named;
  final String? query;
}

/// One thing in a context. [text] is the person's content: data for the
/// model, never instructions.
class AiContextItem {
  const AiContextItem({
    required this.ref,
    required this.classification,
    required this.title,
    this.text = '',
    this.version,
  });

  /// A record (`task:<id>`), or a PDF's text (`file:<hash>` or
  /// `file:<hash>#<page>`).
  final RecordRef ref;
  final DataClassification classification;
  final String title;
  final String text;

  /// The record's version when the context was made (proposals bind it).
  final int? version;
}

class AiContext {
  const AiContext(this.items, {this.truncated = false});
  final List<AiContextItem> items;

  /// Some of what was asked for was left out to stay within the limits.
  final bool truncated;
}

abstract interface class AiContextBuilder {
  /// The context for [request], in the shown space only.
  Future<AiContext> build(AiContextRequest request);
}

/// An item and what the checkpoint did with it.
class AiEgressLine {
  const AiEgressLine(this.item, this.egress, {required this.sent});
  final AiContextItem item;
  final AiEgress egress;
  final bool sent;
}

/// A request that passed the checkpoint: the only kind an engine takes.
final class CheckedAiRequest {
  CheckedAiRequest._(this.site, this.instructions, this.question, this.data, this.lines);

  final AiEngineSite site;

  /// The app's own instructions (trusted).
  final String instructions;

  /// What the person asked (trusted: they typed it).
  final String question;

  /// The items sent, as JSON objects tagged untrusted.
  final List<Map<String, Object?>> data;

  /// Every item asked for and what happened to it (for the person: what was
  /// sent, what waits for consent, what was left out).
  final List<AiEgressLine> lines;

  Set<RecordRef> get sentRefs => {for (final l in lines) if (l.sent) l.item.ref};
  List<AiEgressLine> get waitingForConsent => [for (final l in lines) if (!l.sent && l.egress == AiEgress.needsConsent) l];
  List<AiEgressLine> get denied => [for (final l in lines) if (l.egress == AiEgress.deny) l];

  /// The data as the model reads it.
  String get dataJson => jsonEncode(data);
}

/// The egress checkpoint (ai-architecture.md §3): the last gate before a
/// request leaves for a model at [site]. Each item is decided by the
/// domain's rule; what may not go is not in the request.
CheckedAiRequest checkAiEgress({
  required AiEngineSite site,
  required AiEgressPolicy policy,
  required AiContext context,
  required String instructions,
  required String question,
  Set<RecordRef> consented = const {},
}) {
  final lines = <AiEgressLine>[];
  final data = <Map<String, Object?>>[];
  for (final item in context.items) {
    final egress = aiEgressOf(item.classification, site, policy);
    final sent = aiMaySend(item.classification, site, policy, consented: consented.contains(item.ref));
    lines.add(AiEgressLine(item, egress, sent: sent));
    if (!sent) continue;
    data.add({
      'untrusted': true,
      'ref': '${item.ref}',
      'title': item.title,
      'text': item.text,
    });
  }
  return CheckedAiRequest._(site, instructions, question, List.unmodifiable(data), List.unmodifiable(lines));
}

/// Who wrote a message of a session.
enum AiMessageRole { person, assistant }

/// A session with the assistant, as listed.
class AiSessionView {
  const AiSessionView({required this.id, required this.title, required this.purpose, required this.updatedAt});
  final String id;
  final String title;
  final AiPurpose purpose;
  final DateTime updatedAt;
}

class AiMessageView {
  const AiMessageView({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.model,
    this.site,
    this.sentRefs = const [],
  });
  final String id;
  final AiMessageRole role;
  final String text;
  final DateTime createdAt;
  final String? model;
  final AiEngineSite? site;

  /// What was sent with the question, and the version of each.
  final List<(RecordRef, int?)> sentRefs;
}

class AiProposalView {
  const AiProposalView({
    required this.id,
    required this.sessionId,
    required this.model,
    required this.site,
    required this.changes,
    this.messageId,
    this.note = '',
  });
  final String id;
  final String sessionId;
  final String? messageId;
  final String model;
  final AiEngineSite site;
  final List<AiChangeRecord> changes;
  final String note;
}

/// What became of one change the person approved or dismissed.
class AiChangeOutcome {
  const AiChangeOutcome(this.changeId, this.status, {this.reason});
  final String changeId;
  final AiChangeStatus status;
  final String? reason;
}

/// The assistant's history and its proposals (P06 T3). Every write goes
/// through the command gateway, in the personal space, as its owner.
abstract interface class AiHistoryService {
  /// A new session; its id on success.
  Future<CommandResult> startSession({required String title, required AiPurpose purpose});
  Future<CommandResult> renameSession(String sessionId, String title);

  /// To the trash with its messages and proposals; [restoreSession] brings
  /// back the ones that went with it.
  Future<CommandResult> trashSession(String sessionId);
  Future<CommandResult> restoreSession(String sessionId);

  /// A message of the session; the message's id on success.
  Future<CommandResult> addMessage(String sessionId, AiMessageRole role, String text,
      {String? model, AiEngineSite? site, List<(RecordRef, int?)> sentRefs = const []});

  /// A proposal of the assistant, every change proposed; its id on success.
  Future<CommandResult> addProposal(String sessionId,
      {required String model, required AiEngineSite site, required List<ProposedChange> changes, String? messageId, String note = ''});

  /// The person approves one change: it runs as them, if nothing it was
  /// computed against changed since (else it is stale and nothing is written).
  Future<AiChangeOutcome> approve(String proposalId, String changeId, {Set<RecordRef> consented = const {}});

  /// Each change still proposed, in order, as [approve] (D8).
  Future<List<AiChangeOutcome>> approveAll(String proposalId, {Set<RecordRef> consented = const {}});
  Future<AiChangeOutcome> dismiss(String proposalId, String changeId);

  /// Live sessions, the newest first.
  Future<List<AiSessionView>> sessions();
  Future<List<AiMessageView>> messages(String sessionId);
  Future<List<AiProposalView>> proposals(String sessionId);
}
