/// Optimistic-concurrency version per aggregate root (ADR-0009).
/// Monotonic integer, incremented once per successful command (LF-INV-VER-001).
extension type const Version(int value) {
  static const initial = Version(1);
  Version get next => Version(value + 1);
}

/// Actor performing a command (ADR-0009 / authorization-model).
enum ActorKind { owner, aiAssistant, provider, sync }

class ActorRef {
  const ActorRef(this.kind, this.id);
  final ActorKind kind;
  final String id; // profile/account id for owner; a label otherwise
  @override
  String toString() => '${kind.name}:$id';
}
