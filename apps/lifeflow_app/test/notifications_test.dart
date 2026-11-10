// P02 T7: the adapter keeps unchanged pending reminders and replaces the rest.
import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:lifeflow_app/notifications.dart';

PlannedReminder r(int id, String key, int hour, {String title = 'T', String body = 'B'}) => PlannedReminder(
    id: id, key: key, at: Instant(DateTime.utc(2026, 11, 10, hour)), title: title, body: body);

({int id, String? payload, String? title, String? body}) pendingOf(PlannedReminder p) =>
    (id: p.id, payload: payloadOf(p), title: p.title, body: p.body);

void main() {
  test('unchanged stay, changed and stale are cancelled, new are scheduled', () {
    final keep = r(1, 'task:a#0@2026-11-10', 1);
    final moved = r(2, 'task:b#0@2026-11-10', 2);
    final renamed = r(3, 'task:c#0@2026-11-10', 3);
    final stale = r(4, 'task:d#0@2026-11-10', 4);
    final pending = [pendingOf(keep), pendingOf(moved), pendingOf(renamed), pendingOf(stale),
      // Not LifeFlow's format (for example left by an old build): replaced.
      (id: 9, payload: 'other', title: 'x', body: 'y')];
    final fresh = r(5, 'event:e#0@2026-11-11', 5);
    final planned = [keep, r(2, moved.key, 7), r(3, renamed.key, 3, title: 'New title'), fresh];

    final d = diffPending(pending, planned);
    expect(d.cancel, unorderedEquals([2, 3, 4, 9]));
    expect(d.schedule.map((p) => p.id), [2, 3, 5]);
  });

  test('an empty plan cancels everything; nothing pending schedules everything', () {
    final a = r(1, 'k1', 1), b = r(2, 'k2', 2);
    expect(diffPending([pendingOf(a), pendingOf(b)], const []).cancel, [1, 2]);
    final d = diffPending(const [], [a, b]);
    expect(d.cancel, isEmpty);
    expect(d.schedule, [a, b]);
  });

  test('Windows: no entry = never shown (scheduled ones would be dropped); Enabled 0 = turned off', () {
    expect(windowsNotificationStateOf(1, ''), WindowsNotificationState.unregistered);
    const shown = r'''
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\LifeFlow.App
    LastNotificationAddedTime    REG_QWORD    0x1dd70ecfb29ce70
    PeriodicNotificationCount    REG_DWORD    0x2
''';
    expect(windowsNotificationStateOf(0, shown), WindowsNotificationState.enabled);
    const off = '$shown    Enabled    REG_DWORD    0x0\n';
    expect(windowsNotificationStateOf(0, off), WindowsNotificationState.disabled);
    const on = '$shown    Enabled    REG_DWORD    0x1\n';
    expect(windowsNotificationStateOf(0, on), WindowsNotificationState.enabled);
  });

  test('the payload carries the key and the instant', () {
    expect(payloadOf(r(1, 'task:a#0@2026-11-10', 1)), 'lf1|task:a#0@2026-11-10|${DateTime.utc(2026, 11, 10, 1).millisecondsSinceEpoch}');
  });
}
