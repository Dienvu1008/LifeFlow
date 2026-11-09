/// Time primitives per ADR-0010 and ADR-0028. Plain data only: nothing here
/// knows the time-zone database. Resolving a wall clock in a zone to an
/// instant (and the DST rule) lives in `time_kernel`.
///
/// Three distinct kinds of time, never converted implicitly:
///  - [LocalDate]      a calendar date, no time, no zone (date-only items)
///  - [ZonedWallClock] a local date and time in a named IANA zone (timed items)
///  - [Instant]        a UTC point in time (metadata, cached query values)
library;

/// ISO 8601 day of the week (Monday = 1 ... Sunday = 7).
enum Weekday {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  /// 1 (Monday) to 7 (Sunday).
  int get isoNumber => index + 1;

  static Weekday fromIso(int n) {
    if (n < 1 || n > 7) throw RangeError.range(n, 1, 7, 'isoWeekday');
    return Weekday.values[n - 1];
  }
}

/// A floating calendar date (no time, no zone). Never implicitly an instant
/// (LF-INV-PLAN-004). Always a real date: the constructor rejects 2026-02-30.
class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be 1..12');
    }
    if (day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError.value(day, 'day', 'not a day of $year-$month');
    }
  }

  /// From the number of days since 1970-01-01 (may be negative).
  factory LocalDate.fromEpochDay(int epochDay) {
    // Civil-from-days (H. Hinnant), proleptic Gregorian, exact for all ints.
    final z = epochDay + 719468;
    final era = (z >= 0 ? z : z - 146096) ~/ 146097;
    final doe = z - era * 146097;
    final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
    final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100);
    final mp = (5 * doy + 2) ~/ 153;
    final d = doy - (153 * mp + 2) ~/ 5 + 1;
    final m = mp < 10 ? mp + 3 : mp - 9;
    final y = yoe + era * 400 + (m <= 2 ? 1 : 0);
    return LocalDate(y, m, d);
  }

  /// Parses `YYYY-MM-DD`.
  factory LocalDate.parse(String s) {
    final m = RegExp(r'^(-?\d{4,})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) throw FormatException('not a date (YYYY-MM-DD)', s);
    return LocalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  final int year;
  final int month;
  final int day;

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int daysInMonth(int year, int month) => switch (month) {
        2 => isLeapYear(year) ? 29 : 28,
        4 || 6 || 9 || 11 => 30,
        _ => 31,
      };

  /// Days since 1970-01-01.
  int get epochDay {
    final y = month <= 2 ? year - 1 : year;
    final era = (y >= 0 ? y : y - 399) ~/ 400;
    final yoe = y - era * 400;
    final mp = month > 2 ? month - 3 : month + 9;
    final doy = (153 * mp + 2) ~/ 5 + day - 1;
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
    return era * 146097 + doe - 719468;
  }

  Weekday get weekday => Weekday.fromIso(((epochDay % 7) + 7 + 3) % 7 + 1);

  LocalDate addDays(int days) => LocalDate.fromEpochDay(epochDay + days);

  /// Days from this date to [other] (positive when [other] is later).
  int daysUntil(LocalDate other) => other.epochDay - epochDay;

  /// The same day [months] later, or null when that month has no such day
  /// (for example Jan 31 + 1 month). Callers decide what that means (the
  /// recurrence month-end rule, ADR-0028).
  LocalDate? addMonthsExact(int months) {
    final total = year * 12 + (month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    return day <= daysInMonth(y, m) ? LocalDate(y, m, day) : null;
  }

  /// The same day [months] later, clamped to the last day of the month.
  LocalDate addMonthsClamped(int months) {
    final total = year * 12 + (month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = daysInMonth(y, m);
    return LocalDate(y, m, day <= last ? day : last);
  }

  bool isBefore(LocalDate o) => epochDay < o.epochDay;
  bool isAfter(LocalDate o) => epochDay > o.epochDay;

  @override
  int compareTo(LocalDate o) => epochDay.compareTo(o.epochDay);

  @override
  bool operator ==(Object o) =>
      o is LocalDate && o.year == year && o.month == month && o.day == day;
  @override
  int get hashCode => Object.hash(year, month, day);

  /// ISO `YYYY-MM-DD`.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// A time of day without date or zone, minute precision (00:00–23:59).
class TimeOfDayValue implements Comparable<TimeOfDayValue> {
  TimeOfDayValue(this.hour, this.minute) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be 0..23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'must be 0..59');
    }
  }

  /// Parses `HH:MM`.
  factory TimeOfDayValue.parse(String s) {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(s);
    if (m == null) throw FormatException('not a time (HH:MM)', s);
    return TimeOfDayValue(int.parse(m[1]!), int.parse(m[2]!));
  }

  final int hour;
  final int minute;

  int get minuteOfDay => hour * 60 + minute;

  @override
  int compareTo(TimeOfDayValue o) => minuteOfDay.compareTo(o.minuteOfDay);

  @override
  bool operator ==(Object o) =>
      o is TimeOfDayValue && o.hour == hour && o.minute == minute;
  @override
  int get hashCode => Object.hash(hour, minute);
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// A local date and time in a named IANA zone (for example
/// `Europe/Berlin`). It is the stored truth of a timed item: the instant is
/// derived on demand by `time_kernel` with the DST rule of ADR-0010, so the
/// wall clock is kept across DST and across device zone changes
/// (LF-INV-PLAN-013). This class does not validate the zone name; the kernel
/// does (it owns the zone database).
class ZonedWallClock {
  ZonedWallClock(this.date, this.time, this.zone) {
    if (zone.trim().isEmpty) {
      throw ArgumentError.value(zone, 'zone', 'must be an IANA zone name');
    }
  }

  final LocalDate date;
  final TimeOfDayValue time;
  final String zone;

  /// The same wall clock on another date (used by recurrence).
  ZonedWallClock onDate(LocalDate d) => ZonedWallClock(d, time, zone);

  @override
  bool operator ==(Object o) =>
      o is ZonedWallClock && o.date == date && o.time == time && o.zone == zone;
  @override
  int get hashCode => Object.hash(date, time, zone);
  @override
  String toString() => '${date}T$time[$zone]';
}

/// A UTC point in time (metadata, precise past events, cached query values).
extension type const Instant(DateTime utc) {
  static Instant now() => Instant(DateTime.now().toUtc());

  static Instant fromMillis(int ms) =>
      Instant(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));

  int get millis => utc.millisecondsSinceEpoch;
}

/// The source of "now". Injected so time-dependent code is testable.
abstract interface class Clock {
  Instant now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  Instant now() => Instant.now();
}

/// A clock that returns what the test sets.
class FixedClock implements Clock {
  FixedClock(this.value);
  Instant value;
  @override
  Instant now() => value;
}
