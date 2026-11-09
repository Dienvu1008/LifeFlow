// P02 T1 — GS-04 / LF-INV-PLAN-013 / AC-06.5: DST correctness, table-driven
// over three zones with DST (northern and southern hemisphere), plus a
// half-hour DST zone and a zone without DST. Rule (ADR-0010): gap -> the end
// of the gap; overlap -> the earlier instant.
//
// Expected values are written by hand from the published rules for 2026:
//   Europe/Berlin     +01 -> +02 on Sun 29 Mar at 02:00; back on Sun 25 Oct at 03:00
//   America/New_York  -05 -> -04 on Sun  8 Mar at 02:00; back on Sun  1 Nov at 02:00
//   Australia/Sydney  +11 -> +10 on Sun  5 Apr at 03:00; +10 -> +11 on Sun 4 Oct at 02:00
//   Australia/Lord_Howe +11 -> +10:30 on Sun 5 Apr at 02:00; back on Sun 4 Oct at 02:00
import 'dart:math';

import 'package:foundation/foundation.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart';

ZonedWallClock wc(String zone, int y, int m, int d, int h, int min) =>
    ZonedWallClock(LocalDate(y, m, d), TimeOfDayValue(h, min), zone);

DateTime utc(int y, int m, int d, int h, int min) => DateTime.utc(y, m, d, h, min);

void main() {
  group('GS-04 table: gap, overlap and normal times', () {
    final rows = <(String, ZonedWallClock, DateTime, WallClockKind)>[
      // Europe/Berlin
      ('Berlin normal winter', wc('Europe/Berlin', 2026, 1, 15, 9, 0), utc(2026, 1, 15, 8, 0), WallClockKind.normal),
      ('Berlin normal summer', wc('Europe/Berlin', 2026, 7, 15, 9, 0), utc(2026, 7, 15, 7, 0), WallClockKind.normal),
      ('Berlin gap 02:30', wc('Europe/Berlin', 2026, 3, 29, 2, 30), utc(2026, 3, 29, 1, 0), WallClockKind.gap),
      ('Berlin gap 02:00', wc('Europe/Berlin', 2026, 3, 29, 2, 0), utc(2026, 3, 29, 1, 0), WallClockKind.gap),
      ('Berlin just after gap 03:00', wc('Europe/Berlin', 2026, 3, 29, 3, 0), utc(2026, 3, 29, 1, 0), WallClockKind.normal),
      ('Berlin just before gap 01:59', wc('Europe/Berlin', 2026, 3, 29, 1, 59), utc(2026, 3, 29, 0, 59), WallClockKind.normal),
      ('Berlin overlap 02:30', wc('Europe/Berlin', 2026, 10, 25, 2, 30), utc(2026, 10, 25, 0, 30), WallClockKind.overlap),
      ('Berlin overlap 02:00', wc('Europe/Berlin', 2026, 10, 25, 2, 0), utc(2026, 10, 25, 0, 0), WallClockKind.overlap),
      ('Berlin after overlap 03:00', wc('Europe/Berlin', 2026, 10, 25, 3, 0), utc(2026, 10, 25, 2, 0), WallClockKind.normal),
      // America/New_York
      ('New York gap 02:30', wc('America/New_York', 2026, 3, 8, 2, 30), utc(2026, 3, 8, 7, 0), WallClockKind.gap),
      ('New York overlap 01:30', wc('America/New_York', 2026, 11, 1, 1, 30), utc(2026, 11, 1, 5, 30), WallClockKind.overlap),
      ('New York normal 09:00 winter', wc('America/New_York', 2026, 12, 1, 9, 0), utc(2026, 12, 1, 14, 0), WallClockKind.normal),
      ('New York normal 09:00 summer', wc('America/New_York', 2026, 6, 1, 9, 0), utc(2026, 6, 1, 13, 0), WallClockKind.normal),
      // Australia/Sydney (southern hemisphere: summer time in January)
      ('Sydney gap 02:30', wc('Australia/Sydney', 2026, 10, 4, 2, 30), utc(2026, 10, 3, 16, 0), WallClockKind.gap),
      ('Sydney overlap 02:30', wc('Australia/Sydney', 2026, 4, 5, 2, 30), utc(2026, 4, 4, 15, 30), WallClockKind.overlap),
      ('Sydney normal January (+11)', wc('Australia/Sydney', 2026, 1, 15, 9, 0), utc(2026, 1, 14, 22, 0), WallClockKind.normal),
      ('Sydney normal July (+10)', wc('Australia/Sydney', 2026, 7, 15, 9, 0), utc(2026, 7, 14, 23, 0), WallClockKind.normal),
      // Half-hour DST
      ('Lord Howe overlap 01:45', wc('Australia/Lord_Howe', 2026, 4, 5, 1, 45), utc(2026, 4, 4, 14, 45), WallClockKind.overlap),
      ('Lord Howe gap 02:15', wc('Australia/Lord_Howe', 2026, 10, 4, 2, 15), utc(2026, 10, 3, 15, 30), WallClockKind.gap),
      // No DST
      ('Ho Chi Minh 09:00', wc('Asia/Ho_Chi_Minh', 2026, 3, 29, 9, 0), utc(2026, 3, 29, 2, 0), WallClockKind.normal),
      ('UTC midnight', wc('UTC', 2026, 1, 1, 0, 0), utc(2026, 1, 1, 0, 0), WallClockKind.normal),
    ];

    for (final (name, wall, expected, kind) in rows) {
      test(name, () {
        final r = resolveWallClockDetailed(wall);
        expect(r.instant.utc, expected, reason: '$wall');
        expect(r.kind, kind, reason: '$wall');
        expect(resolveWallClock(wall).utc, expected);
      });
    }
  });

  group('LF-INV-PLAN-013: a daily 09:00 keeps its wall clock across DST', () {
    for (final (zone, from, utcBefore, utcAfter) in [
      ('Europe/Berlin', LocalDate(2026, 3, 26), 8, 7),
      ('America/New_York', LocalDate(2026, 3, 5), 14, 13),
      ('Australia/Sydney', LocalDate(2026, 4, 2), 22, 23),
    ]) {
      test(zone, () {
        final hours = <int>[];
        for (var i = 0; i < 7; i++) {
          final w = ZonedWallClock(from.addDays(i), TimeOfDayValue(9, 0), zone);
          final at = resolveWallClock(w);
          // Shown in its own zone it is always 09:00 on that date.
          final back = wallClockAt(at, zone);
          expect(back.time, TimeOfDayValue(9, 0));
          expect(back.date, w.date);
          hours.add(at.utc.hour);
        }
        expect(hours.first, utcBefore);
        expect(hours.last, utcAfter);
      });
    }
  });

  test('property: an instant shown as a wall clock resolves back to itself '
      '(or to the earlier twin inside an overlap)', () {
    final r = Random(4);
    for (final zone in ['Europe/Berlin', 'America/New_York', 'Australia/Sydney', 'Australia/Lord_Howe']) {
      for (var i = 0; i < 3000; i++) {
        // Random minute in 2025-2028.
        final ms = DateTime.utc(2025).millisecondsSinceEpoch +
            r.nextInt(4 * 365 * 24 * 60) * 60000;
        final at = Instant.fromMillis(ms);
        final w = wallClockAt(at, zone);
        final res = resolveWallClockDetailed(w);
        if (res.kind == WallClockKind.overlap) {
          expect(res.instant.millis, lessThanOrEqualTo(ms), reason: '$zone $w');
          expect(wallClockAt(res.instant, zone), w);
        } else {
          expect(res.kind, WallClockKind.normal, reason: '$zone $w');
          expect(res.instant.millis, ms, reason: '$zone $w');
        }
      }
    }
  });

  test('unknown zones are reported', () {
    expect(TimeZones.isKnown('Europe/Berlin'), isTrue);
    expect(TimeZones.isKnown('Mars/Olympus'), isFalse);
    expect(() => resolveWallClock(wc('Mars/Olympus', 2026, 1, 1, 9, 0)),
        throwsA(isA<UnknownZone>()));
    expect(TimeZones.names(), contains('Asia/Ho_Chi_Minh'));
  });

  test('dateAt gives "today" in a zone', () {
    final at = Instant(utc(2026, 11, 7, 23, 30));
    expect(dateAt(at, 'UTC'), LocalDate(2026, 11, 7));
    expect(dateAt(at, 'Asia/Ho_Chi_Minh'), LocalDate(2026, 11, 8));
    expect(dateAt(at, 'America/New_York'), LocalDate(2026, 11, 7));
  });
}
