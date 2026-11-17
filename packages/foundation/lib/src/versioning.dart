/// Optimistic-concurrency version per aggregate root (ADR-0009).
/// Monotonic integer, incremented once per successful command (LF-INV-VER-001).
extension type const Version(int value) {
  static const initial = Version(1);
  Version get next => Version(value + 1);
}

/// Actor performing a command (ADR-0009 / authorization-model).
///   owner   the local person in their personal workspace (id: profile id)
///   member  the local person in a shared space (id: their account id; the
///           role comes from the space's members, P04b ADR-0060)
enum ActorKind { owner, aiAssistant, provider, sync, member }

class ActorRef {
  const ActorRef(this.kind, this.id);
  final ActorKind kind;
  final String id; // profile/account id for owner; a label otherwise
  @override
  String toString() => '${kind.name}:$id';
}
