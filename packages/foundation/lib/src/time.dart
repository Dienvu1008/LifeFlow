/// Time primitives per ADR-0010: date-only vs instant are distinct types.
/// Skeleton placeholders; ZonedWallClock + DST resolver live in time_kernel.

/// A floating calendar date (no time, no zone). Never implicitly an instant.
class LocalDate {
  const LocalDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object o) =>
      o is LocalDate && o.year == year && o.month == month && o.day == day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// A UTC point in time (metadata, precise past events).
extension type const Instant(DateTime utc) {
  static Instant now() => Instant(DateTime.now().toUtc());
}
