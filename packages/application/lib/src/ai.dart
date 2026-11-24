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
import 'dart:convert';

import 'package:domain/domain.dart';

export 'package:domain/domain.dart'
    show
        AiApproval,
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
        canonicalArguments;

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
