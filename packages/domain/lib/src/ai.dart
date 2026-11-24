// P06 T1 (ADR-0080; ADR-0012, ADR-0016, data-classification.md §2,
// ai-architecture.md §3–§5): what an AI request may carry, and how an AI
// proposal is approved. Pure: no model, no store.
//   egress     each item of a context gets allow, needs consent, or deny,
//              from its class and the engine (on this device or in the
//              cloud). Default deny: a case not listed is denied
//   proposal   the changes a model suggests: a command type, its exact
//              arguments, and the version of each existing thing it was
//              computed against. It is only a suggestion (LF-INV-AI-001)
//   approval   bound to the person, the exact arguments and those versions
//              (ADR-0012); it no longer holds when any of them changed
//              (LF-INV-AI-002). Each change is approved on its own (D8)
import 'dart:convert';

import 'package:foundation/foundation.dart';

import 'data_classification.dart';

/// Where a model runs.
enum AiEngineSite {
  /// On this device (P06 D2: the default).
  device,

  /// A cloud model, with the person's own key (D2, D5).
  cloud,
}

enum AiEgress {
  /// May be put in the request as it is.
  allow,

  /// Only with the person's consent for this one request (data-
  /// classification.md §2: "explicit per-request consent").
  needsConsent,

  /// Never: dropped from the request, and the person is told.
  deny,
}

/// What the person allowed for the request being built.
class AiEgressPolicy {
  const AiEgressPolicy({this.cloudEnabled = false, this.scopeIncludesConfidential = false});

  /// The cloud option is on in Settings (D2; off by default).
  final bool cloudEnabled;

  /// The request is about Confidential items by its nature: "ask about this
  /// document", "plan my day" over the tasks (the matrix's "if the session
  /// scope permits", for the device engine).
  final bool scopeIncludesConfidential;
}

/// What an item of [classification] may do in a request to an engine at
/// [site] (data-classification.md §2, ai-architecture.md §3):
///
/// | class        | device                         | cloud                        |
/// |--------------|--------------------------------|------------------------------|
/// | Public       | allow                          | allow, if cloud is on        |
/// | Personal     | allow                          | allow, if cloud is on        |
/// | Confidential | allow, if in the request's scope; else consent | consent, if cloud is on |
/// | Restricted   | consent                        | **deny, always** (PRIV-002)  |
AiEgress aiEgressOf(DataClassification classification, AiEngineSite site, AiEgressPolicy policy) {
  switch (site) {
    case AiEngineSite.device:
      return switch (classification) {
        DataClassification.public || DataClassification.personal => AiEgress.allow,
        DataClassification.confidential => policy.scopeIncludesConfidential ? AiEgress.allow : AiEgress.needsConsent,
        DataClassification.restricted => AiEgress.needsConsent,
      };
    case AiEngineSite.cloud:
      return switch (classification) {
        // Always, even with the cloud on and the person's consent (PRIV-002).
        DataClassification.restricted => AiEgress.deny,
        _ when !policy.cloudEnabled => AiEgress.deny,
        DataClassification.public || DataClassification.personal => AiEgress.allow,
        DataClassification.confidential => AiEgress.needsConsent,
      };
  }
}

/// Whether an item may go into the request: allowed, or needing consent and
/// consented for this request. Restricted toward the cloud never is.
bool aiMaySend(DataClassification classification, AiEngineSite site, AiEgressPolicy policy, {required bool consented}) =>
    switch (aiEgressOf(classification, site, policy)) {
      AiEgress.allow => true,
      AiEgress.needsConsent => consented,
      AiEgress.deny => false,
    };

/// A thing a proposal reads or changes: a record kind and id.
class RecordRef implements Comparable<RecordRef> {
  const RecordRef(this.kind, this.id);
  final String kind;
  final String id;

  @override
  bool operator ==(Object o) => o is RecordRef && o.kind == kind && o.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
  @override
  int compareTo(RecordRef o) => kind == o.kind ? id.compareTo(o.id) : kind.compareTo(o.kind);
  @override
  String toString() => '$kind:$id';
}

/// One change a model suggests: a command and its exact arguments, and the
/// version of each existing thing it was computed against (a new thing has
/// none).
class ProposedChange {
  ProposedChange({
    required this.id,
    required this.commandType,
    required Map<String, Object?> arguments,
    required Map<RecordRef, int> versions,
    required this.summary,
  })  : arguments = Map.unmodifiable(arguments),
        versions = Map.unmodifiable(versions);

  /// Unique within its proposal.
  final String id;
  final String commandType;
  final Map<String, Object?> arguments;
  final Map<RecordRef, int> versions;

  /// What the person reads ("Move "Gọi điện cho mẹ" to 14:30").
  final String summary;
}

/// What a model suggested in one turn (LF-INV-AI-001: nothing happens until
/// the person approves a change).
class AiProposal {
  AiProposal({
    required this.id,
    required this.sessionId,
    required this.model,
    required this.createdAt,
    required List<ProposedChange> changes,
    this.note = '',
  }) : changes = List.unmodifiable(changes) {
    final ids = <String>{};
    for (final c in changes) {
      if (!ids.add(c.id)) throw ArgumentError('a proposal names change ${c.id} twice');
    }
  }
  final String id;
  final String sessionId;

  /// Which model made it (provenance).
  final String model;
  final Instant createdAt;
  final List<ProposedChange> changes;
  final String note;

  ProposedChange? change(String id) => changes.where((c) => c.id == id).firstOrNull;
}

/// What the approval was given under (ADR-0012's policy context).
class AiPolicyContext {
  const AiPolicyContext({required this.site, required this.model, this.consented = const {}});
  final AiEngineSite site;
  final String model;

  /// The items the person consented to send for this request.
  final Set<RecordRef> consented;
}

/// The person's approval of one change (ADR-0012).
class AiApproval {
  AiApproval._({
    required this.proposalId,
    required this.changeId,
    required this.actorId,
    required this.approvedAt,
    required this.arguments,
    required Map<RecordRef, int> versions,
    required this.policy,
  }) : versions = Map.unmodifiable(versions);

  final String proposalId;
  final String changeId;

  /// The person who approved: the change runs as them.
  final String actorId;
  final Instant approvedAt;

  /// The change's arguments, in canonical JSON (keys sorted): what was
  /// approved is exactly what runs.
  final String arguments;
  final Map<RecordRef, int> versions;
  final AiPolicyContext policy;
}

/// [arguments] as canonical JSON: map keys sorted at every level.
String canonicalArguments(Map<String, Object?> arguments) {
  Object? sorted(Object? v) => switch (v) {
        Map m => {for (final k in (m.keys.map((k) => '$k').toList()..sort())) k: sorted(m[k])},
        List l => [for (final x in l) sorted(x)],
        _ => v,
      };
  return jsonEncode(sorted(arguments));
}

/// The person [actorId] approves [change] of [proposal] at [at].
AiApproval approveChange(AiProposal proposal, ProposedChange change,
    {required String actorId, required Instant at, required AiPolicyContext policy}) {
  if (!identical(proposal.change(change.id), change)) {
    throw ArgumentError('change ${change.id} is not part of proposal ${proposal.id}');
  }
  return AiApproval._(
    proposalId: proposal.id,
    changeId: change.id,
    actorId: actorId,
    approvedAt: at,
    arguments: canonicalArguments(change.arguments),
    versions: change.versions,
    policy: policy,
  );
}

enum ApprovalProblem {
  /// Another person, or another proposal or change.
  notThisApproval,

  /// The arguments to run are not the ones approved.
  argumentsChanged,

  /// A thing it was computed against changed or is gone since (LF-INV-AI-002):
  /// the person must regenerate.
  stale,
}

/// Why [approval] does not let [change] of proposal [proposalId] run now for
/// [actorId], or null when it does. [current] gives each thing's version now
/// (null: gone).
ApprovalProblem? approvalProblem(
  AiApproval approval, {
  required String proposalId,
  required ProposedChange change,
  required String actorId,
  required int? Function(RecordRef ref) current,
}) {
  if (approval.proposalId != proposalId || approval.changeId != change.id || approval.actorId != actorId) {
    return ApprovalProblem.notThisApproval;
  }
  if (approval.arguments != canonicalArguments(change.arguments) ||
      !_sameVersions(approval.versions, change.versions)) {
    return ApprovalProblem.argumentsChanged;
  }
  for (final MapEntry(key: ref, value: v) in approval.versions.entries) {
    if (current(ref) != v) return ApprovalProblem.stale;
  }
  return null;
}

bool _sameVersions(Map<RecordRef, int> a, Map<RecordRef, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
