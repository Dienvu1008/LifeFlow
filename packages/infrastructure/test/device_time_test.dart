// P03 UX U5 (ADR-0049): timed items as the device's wall clock, for the
// time grid. The Time Kernel resolves zones and DST; the UI never does.
//   zones      an item in another zone lands at the device's local time
//   midnight   it can move to another device date
//   DST        on 23 h and 25 h days the wall clock is the resolved one
//   queries    the calendar range and the agenda carry the device times
import 'dart:io';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'fake_auth.dart';
import 'profile_harness.dart';

class _Time implements DeviceTime {
  _Time(this.tz);
  final String tz;
  @override
  Instant now() => Instant(DateTime.utc(2026, 11, 9, 1));
  @override
  String zone() => tz;
}

tk.TimedPoint wall(LocalDate d, int h, int m, String zone) => tk.TimedPoint(ZonedWallClock(d, TimeOfDayValue(h, m), zone));

void main() {
  final nov12 = LocalDate(2026, 11, 12);

  test('another zone lands at the device\'s local time; a date-only point stays off the grid', () {
    final p = devicePointOf(wall(nov12, 10, 0, 'Europe/Berlin'), 'Asia/Ho_Chi_Minh')!;
    expect((p.date, '${p.time}', p.zone), (nov12, '16:00', 'Asia/Ho_Chi_Minh'));
    expect(devicePointOf(tk.DatePoint(nov12), 'Asia/Ho_Chi_Minh'), isNull);
    expect(devicePointOf(null, 'UTC'), isNull);
  });

  test('late in Berlin is the next morning in Ho Chi Minh City', () {
    final p = devicePointOf(wall(nov12, 23, 30, 'Europe/Berlin'), 'Asia/Ho_Chi_Minh')!;
    expect((p.date, '${p.time}'), (nov12.addDays(1), '05:30'));
  });

  test('DST: a wall clock in the spring gap resolves to the end of the gap; the autumn hour twice stays', () {
    // 2026-03-29: Berlin skips 02:00-03:00 (a 23 h day).
    final gap = devicePointOf(wall(LocalDate(2026, 3, 29), 2, 30, 'Europe/Berlin'), 'Europe/Berlin')!;
    // The kernel's gap rule: the first valid instant after it (03:00 CEST).
    expect('${gap.time}', '03:00');
    expect('${devicePointOf(wall(LocalDate(2026, 3, 29), 2, 30, 'Europe/Berlin'), 'UTC')!.time}', '01:00');
    // 2026-10-25: Berlin has 02:00-03:00 twice (a 25 h day); 02:30 keeps its wall clock.
    final twice = devicePointOf(wall(LocalDate(2026, 10, 25), 2, 30, 'Europe/Berlin'), 'Europe/Berlin')!;
    expect('${twice.time}', '02:30');
    // An item in UTC across the Berlin change: 00:30 UTC is 02:30 CEST, 01:30 UTC is 02:30 CET.
    expect('${devicePointOf(wall(LocalDate(2026, 10, 25), 0, 30, 'UTC'), 'Europe/Berlin')!.time}', '02:30');
    expect('${devicePointOf(wall(LocalDate(2026, 10, 25), 1, 30, 'UTC'), 'Europe/Berlin')!.time}', '02:30');
  });

  group('the queries carry the device times', () {
    late Directory base;
    late ProfileDirectory dir;
    late TestHost host;
    late DriftCalendarQueries cal;
    late DriftEventService events;
    late DriftTaskScheduling scheduling;
    late Services svc;

    setUp(() async {
      base = Directory.systemTemp.createTempSync('lifeflow_devtime_');
      dir = await openDirectory(base, MemoryKeys());
      host = TestHost(dir);
      await host.openActive();
      svc = Services(host, FakeAuthGateway());
      final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
      events = DriftEventService(host.db, gw);
      scheduling = DriftTaskScheduling(host.db, gw);
      cal = DriftCalendarQueries(host.db, DriftAgendaQueries(host.db, _Time('Asia/Ho_Chi_Minh')));
    });
    tearDown(() async {
      await host.close();
      await dir.close();
      if (base.existsSync()) base.deleteSync(recursive: true);
    });

    test('the hidden night hours are a device setting, 00:00-06:00 by default (U-D5)', () async {
      final s = DirectorySettingsService(dir);
      final p = await s.planningSettings();
      expect((p.hiddenFrom, p.hiddenTo), (0, 360));
      await s.setPlanningSettings(p.copyWith(hiddenFrom: 23 * 60, hiddenTo: 7 * 60));
      final again = await DirectorySettingsService(dir).planningSettings();
      expect((again.hiddenFrom, again.hiddenTo), (1380, 420));
      await s.setPlanningSettings(p.copyWith(hiddenFrom: -5, hiddenTo: 2000));
      final clamped = await s.planningSettings();
      expect((clamped.hiddenFrom, clamped.hiddenTo), (0, 1440));
    });

    test('an event and a task in Berlin show at Ho Chi Minh City times', () async {
      final r = await events.create(EventInput(
        title: 'Call Berlin',
        start: SchedulePointInput.at(nov12, TimeOfDayValue(9, 0), 'Europe/Berlin'),
        end: SchedulePointInput.at(nov12, TimeOfDayValue(10, 0), 'Europe/Berlin'),
      ));
      expect(r, isA<CommandOk>(), reason: '$r');
      final t = (await svc.tasks.create('Report') as CommandOk).entityId;
      expect(
          await scheduling.setSchedule(
              t, TaskScheduleInput(start: SchedulePointInput.at(nov12, TimeOfDayValue(8, 0), 'Europe/Berlin'))),
          isA<CommandOk>());
      final day = await cal.range(nov12, nov12);
      final e = day.events.single;
      expect(('${e.deviceStart!.time}', '${e.deviceEnd!.time}', e.deviceStart!.zone), ('15:00', '16:00', 'Asia/Ho_Chi_Minh'));
      expect('${e.start.time}', '09:00'); // the stored wall clock is unchanged
      final task = day.tasks.single;
      expect('${task.deviceStart!.time}', '14:00');
      expect(task.deviceEnd, isNull);
    });
  });
}
