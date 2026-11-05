import 'package:uuid/uuid.dart';

/// Client-generated, time-ordered identifier (UUID v7) per ADR-0009.
/// Skeleton: a thin typed wrapper; richer typing (EntityId<T>) comes in P01.
class EntityId {
  const EntityId(this.value);
  final String value;

  static final _uuid = Uuid();

  /// New UUID v7 (time-ordered). IDs never change once created (LF-INV-ID-001).
  factory EntityId.generate() => EntityId(_uuid.v7());

  @override
  bool operator ==(Object other) => other is EntityId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}
