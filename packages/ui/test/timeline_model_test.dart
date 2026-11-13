// P03 UX U4 (ADR-0048): the Timeline's days as pure data: bounded windows,
// no doubled items across windows, all-day first then by time, overdue at
// today, conflicts by title, the days to show.
import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/src/timeline_model.dart';

final today = LocalDate(2026, 11, 13);

AgendaItem task(String id, LocalDate d, {int? hour, bool overdue = false}) => AgendaItem(
      taskId: id,
      title: id,
      originalDate: d,
      start: hour == null ? SchedulePointInput.date(d) : SchedulePointInput.at(d, TimeOfDayValue(hour, 0), 'UTC'),
      isRepeating: false,
      isDone: false,
      isOverdue: overdue,
    );

EventItem event(String id, LocalDate d, {int? hour}) => EventItem(
      eventId: id,
      title: id,
      originalDate: d,
      start: hour == null ? SchedulePointInput.date(d) : SchedulePointInput.at(d, TimeOfDayValue(hour, 0), 'UTC'),
      isRepeating: false,
    );

CalendarRange range(List<EventItem> e, List<AgendaItem> t, {List<ConflictView> c = const [], bool truncated = false}) =>
    CalendarRange(events: e, tasks: t, conflicts: c, truncated: truncated);

void main() {
  test('windows of 21 days around the anchor, contiguous both ways', () {
    final w0 = timelineWindow(today, 0), w1 = timelineWindow(today, 1), wm1 = timelineWindow(today, -1);
    expect((w0.from, w0.to), (today, today.addDays(20)));
    expect(w1.from, w0.to.addDays(1));
    expect(wm1.to, w0.from.addDays(-1));
    expect(wm1.from.daysUntil(wm1.to) + 1, timelineWindowDays);
  });

  test('each window keeps only what starts inside it: no doubles', () {
    final w0 = timelineWindow(today, 0), w1 = timelineWindow(today, 1);
    // Both windows answer with everything (as a range touching both can).
    final all = range([event('Trip', today.addDays(20))], [task('Pay', today.addDays(21))]);
    final d = buildTimeline(windows: [(w0, all), (w1, all)], todayAgenda: null, today: today);
    expect(d.days[today.addDays(20)]!.map((e) => e.title), ['Trip']);
    expect(d.days[today.addDays(21)]!.map((e) => e.title), ['Pay']);
    expect(d.days.values.expand((v) => v), hasLength(2));
    expect((d.from, d.to), (w0.from, w1.to));
    // An answer outside every loaded window is left for the window that loads it.
    final odd = buildTimeline(windows: [(w0, range(const [], [task('Far', today.addDays(-50))]))], todayAgenda: null, today: today);
    expect(odd.days, isEmpty);
  });

  test('a day: all-day first, then by time, then by title', () {
    final w = timelineWindow(today, 0);
    final d = buildTimeline(windows: [
      (w, range([event('Lunch', today, hour: 12), event('Holiday', today)], [task('Call', today, hour: 9), task('Buy', today)]))
    ], todayAgenda: null, today: today);
    expect(d.days[today]!.map((e) => e.title), ['Buy', 'Holiday', 'Call', 'Lunch']);
  });

  test('today\'s agenda adds overdue tasks apart and fills what the windows miss, once', () {
    final w = timelineWindow(today, 0);
    final d = buildTimeline(
      windows: [(w, range(const [], [task('Gym', today, hour: 18)]))],
      todayAgenda: Agenda([task('Late', today.addDays(-3), overdue: true), task('Gym', today, hour: 18), task('Read', today)]),
      today: today,
    );
    expect(d.overdue.map((i) => i.title), ['Late']);
    expect(d.days[today]!.map((e) => e.title), ['Read', 'Gym']);
    expect(d.days.containsKey(today.addDays(-3)), isFalse);
  });

  test('a cut-off window or agenda is reported', () {
    final w = timelineWindow(today, 0);
    expect(buildTimeline(windows: [(w, range(const [], const [], truncated: true))], todayAgenda: null, today: today).truncated, isTrue);
    expect(buildTimeline(windows: [(w, null)], todayAgenda: const Agenda([], truncated: true), today: today).truncated, isTrue);
    expect(buildTimeline(windows: [(w, null)], todayAgenda: const Agenda([]), today: today).truncated, isFalse);
  });

  test('conflicts are listed by the other item\'s title, both ways', () {
    final w = timelineWindow(today, 0);
    final a = event('Meet', today, hour: 9), b = task('Call', today, hour: 9);
    final d = buildTimeline(windows: [
      (w, range([a], [b], c: [ConflictView(eventOccurrenceKey('Meet', today), taskOccurrenceKey('Call', today))]))
    ], todayAgenda: null, today: today);
    expect(d.conflicts[eventOccurrenceKey('Meet', today)], ['Call']);
    expect(d.conflicts[taskOccurrenceKey('Call', today)], ['Meet']);
  });

  test('the days to show: those with items, the anchor, and today when loaded', () {
    final anchor = today.addDays(5);
    final w = timelineWindow(anchor, -1), w0 = timelineWindow(anchor, 0);
    final d = buildTimeline(windows: [(w, null), (w0, range(const [], [task('X', anchor.addDays(3))]))], todayAgenda: null, today: today);
    expect(d.visibleDays(anchor, today), [today, anchor, anchor.addDays(3)]);
    // Today outside the loaded range is not added.
    final far = today.addDays(100);
    final d2 = buildTimeline(windows: [(timelineWindow(far, 0), null)], todayAgenda: null, today: today);
    expect(d2.visibleDays(far, today), [far]);
  });
}
