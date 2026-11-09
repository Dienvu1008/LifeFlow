// Zone database access and the DST rule (ADR-0010, ADR-0028).
//
// The only place in LifeFlow that turns a wall clock into an instant.
// Rule (ADR-0010):
//   gap     (the wall clock does not exist, clocks jump forward)
//           -> the first valid instant after the gap (the transition)
//   overlap (the wall clock happens twice, clocks fall back)
//           -> the earlier of the two instants
import 'package:foundation/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _hour = 3600 * 1000;

/// The IANA zone database shipped with this build.
class TimeZones {
  TimeZones._();

  static bool _ready = false;

  /// Loads the zone database. Cheap after the first call; called by every
  /// kernel function that needs it, so callers never forget.
  static void ensureInitialized() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  static bool isKnown(String zone) {
    ensureInitialized();
    return tz.timeZoneDatabase.locations.containsKey(zone);
  }

  /// All zone names, sorted (for a zone picker).
  static List<String> names() {
    ensureInitialized();
    return tz.timeZoneDatabase.locations.keys.toList()..sort();
  }

  static tz.Location _location(String zone) {
    ensureInitialized();
    final loc = tz.timeZoneDatabase.locations[zone];
    if (loc == null) throw UnknownZone(zone);
    return loc;
  }

  /// UTC offset (milliseconds) of [zone] at [instant].
  static int offsetAt(String zone, Instant instant) =>
      _location(zone).timeZone(instant.millis).offset;
}

/// The zone name is not in the database.
class UnknownZone implements Exception {
  const UnknownZone(this.zone);
  final String zone;
  @override
  String toString() => 'UnknownZone($zone)';
}

/// How a wall clock maps to the timeline.
enum WallClockKind {
  /// Exactly one instant.
  normal,

  /// Does not exist (DST gap); resolved to the end of the gap.
  gap,

  /// Exists twice (DST overlap); resolved to the earlier instant.
  overlap,
}

class ResolvedWallClock {
  const ResolvedWallClock(this.instant, this.kind);
  final Instant instant;
  final WallClockKind kind;
}

/// The wall clock as if it were UTC, in milliseconds.
int _localMillis(LocalDate d, TimeOfDayValue t) =>
    d.epochDay * 24 * _hour + t.minuteOfDay * 60 * 1000;

/// Resolves [w] to an instant with the ADR-0010 rule. Throws [UnknownZone].
ResolvedWallClock resolveWallClockDetailed(ZonedWallClock w) {
  final loc = TimeZones._location(w.zone);
  final local = _localMillis(w.date, w.time);
  int off(int utc) => loc.timeZone(utc).offset;

  // Real zones never have two transitions within 36 hours, so the offsets
  // just before and just after cover every case.
  final before = off(local - 36 * _hour);
  final after = off(local + 36 * _hour);
  final valid = <int>[
    for (final o in {before, after})
      if (off(local - o) == o) local - o,
  ]..sort();

  if (valid.length == 1) return ResolvedWallClock(Instant.fromMillis(valid.first), WallClockKind.normal);
  if (valid.length > 1) {
    return ResolvedWallClock(Instant.fromMillis(valid.first), WallClockKind.overlap);
  }

  // Gap: find the transition instant (first instant with the new offset).
  var lo = local - 36 * _hour; // offset == before
  var hi = local + 36 * _hour; // offset == after
  while (hi - lo > 1) {
    final mid = lo + (hi - lo) ~/ 2;
    if (off(mid) == before) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return ResolvedWallClock(Instant.fromMillis(hi), WallClockKind.gap);
}

/// Resolves [w] to an instant (gap -> end of gap, overlap -> earlier).
Instant resolveWallClock(ZonedWallClock w) => resolveWallClockDetailed(w).instant;

/// The wall clock shown in [zone] at [instant] (minute precision; seconds
/// are dropped). Used to display instants and to find "today" in a zone.
ZonedWallClock wallClockAt(Instant instant, String zone) {
  final local = instant.millis + TimeZones.offsetAt(zone, instant);
  final day = local >= 0 ? local ~/ (24 * _hour) : -((-local - 1) ~/ (24 * _hour)) - 1;
  final minute = (local - day * 24 * _hour) ~/ 60000;
  return ZonedWallClock(
      LocalDate.fromEpochDay(day), TimeOfDayValue(minute ~/ 60, minute % 60), zone);
}

/// The calendar date in [zone] at [instant] ("today" for that zone).
LocalDate dateAt(Instant instant, String zone) => wallClockAt(instant, zone).date;
