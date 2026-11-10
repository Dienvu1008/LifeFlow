// P03 T1 (ADR-0036): focus sessions.
//   LF-INV-EXEC-002  focus time derived from instants, exact, never negative
//   LF-INV-EXEC-003  a session stored after any step comes back (D1)
//   LF-INV-EXEC-004  one record per session: a second end is refused
//   D1–D5            recovery choices, one interval, records never complete a task
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

final t0 = Instant(DateTime.utc(2026, 11, 10, 8));
Instant at(int minutes, [int seconds = 0]) => Instant(t0.utc.add(Duration(minutes: minutes, seconds: seconds)));
T ok<T>(Result<T, FocusError> r) => switch (r) { Ok(:final value) => value, Err(:final error) => throw StateError('$error') };
FocusError err<T>(Result<T, FocusError> r) => switch (r) { Err(:final error) => error, Ok() => throw StateError('ok') };

FocusSession pomodoro([Duration p = defaultPomodoro]) =>
    ok(FocusSessionMachine.start(id: 's1', mode: FocusMode.pomodoro, now: t0, planned: p, taskId: 't1'));
FocusSession stopwatch() => ok(FocusSessionMachine.start(id: 's2', mode: FocusMode.stopwatch, now: t0));

void main() {
  group('start (D3)', () {
    test('a pomodoro needs a planned interval of up to 4 hours; a stopwatch has none', () {
      expect(err(FocusSessionMachine.start(id: 'x', mode: FocusMode.pomodoro, now: t0)), FocusError.plannedRequired);
      expect(err(FocusSessionMachine.start(id: 'x', mode: FocusMode.pomodoro, now: t0, planned: Duration.zero)),
          FocusError.plannedOutOfRange);
      expect(
          err(FocusSessionMachine.start(
              id: 'x', mode: FocusMode.pomodoro, now: t0, planned: const Duration(hours: 4, minutes: 1))),
          FocusError.plannedOutOfRange);
      expect(
          err(FocusSessionMachine.start(id: 'x', mode: FocusMode.stopwatch, now: t0, planned: defaultPomodoro)),
          FocusError.plannedOnlyForPomodoro);
      final s = pomodoro();
      expect((s.state, s.planned, s.taskId), (FocusState.running, defaultPomodoro, 't1'));
    });

    test('a session can be for an occurrence of a repeating task, or for no task (D5)', () {
      final s = ok(FocusSessionMachine.start(
          id: 'x', mode: FocusMode.stopwatch, now: t0, taskId: 't', occurrenceDate: LocalDate(2026, 11, 10)));
      expect(s.occurrenceDate, LocalDate(2026, 11, 10));
      expect(stopwatch().taskId, isNull);
    });
  });

  group('time (LF-INV-EXEC-002)', () {
    test('pauses are not focus time; the pomodoro end moves with them', () {
      var s = pomodoro();
      s = ok(FocusSessionMachine.pause(s, at(10)));
      expect(FocusSessionMachine.focusTime(s, at(15)), const Duration(minutes: 10)); // still paused
      s = ok(FocusSessionMachine.resume(s, at(15)));
      expect(FocusSessionMachine.focusTime(s, at(20)), const Duration(minutes: 15));
      expect(FocusSessionMachine.plannedEnd(s, at(20))!.utc, at(30).utc); // 25 + 5 paused
      expect(FocusSessionMachine.remaining(s, at(20)), const Duration(minutes: 10));
      expect(FocusSessionMachine.remaining(s, at(40)), Duration.zero); // never negative
    });

    test('a clock that jumps back never gives a negative time', () {
      final s = stopwatch();
      expect(FocusSessionMachine.focusTime(s, at(-30)), Duration.zero);
      final p = ok(FocusSessionMachine.pause(s, at(5)));
      expect(FocusSessionMachine.focusTime(ok(FocusSessionMachine.resume(p, at(2))), at(6)),
          const Duration(minutes: 6));
    });

    test('property: focus time = wall time - pauses, exactly, for any sequence', () {
      final rnd = Random(3);
      for (var i = 0; i < 500; i++) {
        var s = stopwatch();
        var now = 0; // seconds since t0
        var paused = 0;
        int? pausedAt;
        for (var step = 0; step < rnd.nextInt(12); step++) {
          now += rnd.nextInt(900);
          final t = Instant(t0.utc.add(Duration(seconds: now)));
          if (s.state == FocusState.running) {
            s = ok(FocusSessionMachine.pause(s, t));
            pausedAt = now;
          } else {
            s = ok(FocusSessionMachine.resume(s, t));
            paused += now - pausedAt!;
          }
        }
        final end = now + rnd.nextInt(900);
        final current = s.state == FocusState.paused ? end - pausedAt! : 0;
        expect(FocusSessionMachine.focusTime(s, Instant(t0.utc.add(Duration(seconds: end)))),
            Duration(seconds: end - paused - current));
      }
    });
  });

  group('end and cancel (D5, LF-INV-EXEC-004)', () {
    test('counting gives one record, without the pauses; a second end is refused', () {
      var s = pomodoro();
      s = ok(FocusSessionMachine.pause(s, at(5)));
      s = ok(FocusSessionMachine.resume(s, at(7)));
      final (ended, record) = ok(FocusSessionMachine.end(s, at(27), count: true));
      expect(ended.state, FocusState.ended);
      expect(record!.focusTime, const Duration(minutes: 25));
      expect((record.actualStart.utc, record.actualEnd.utc, record.taskId), (t0.utc, at(27).utc, 't1'));
      expect(err(FocusSessionMachine.end(ended, at(28), count: true)), FocusError.notActive);
    });

    test('not counting, or cancelling, leaves no record', () {
      final (_, none) = ok(FocusSessionMachine.end(stopwatch(), at(3), count: false));
      expect(none, isNull);
      final c = ok(FocusSessionMachine.cancel(stopwatch(), at(3)));
      expect(c.state, FocusState.cancelled);
      expect(err(FocusSessionMachine.end(c, at(4), count: true)), FocusError.notActive);
    });

    test('ending while paused counts the pause as paused', () {
      var s = stopwatch();
      s = ok(FocusSessionMachine.pause(s, at(10)));
      final (_, r) = ok(FocusSessionMachine.end(s, at(30), count: true));
      expect(r!.focusTime, const Duration(minutes: 10));
    });

    test('an end before the start is refused (UC-17 E1)', () {
      expect(err(FocusSessionMachine.end(stopwatch(), at(-1), count: true)), FocusError.endBeforeStart);
    });
  });

  group('recovery (D1, LF-INV-EXEC-003)', () {
    test('a running pomodoro past its planned end asks; the planned end counts the pauses', () {
      var s = pomodoro();
      s = ok(FocusSessionMachine.pause(s, at(10)));
      s = ok(FocusSessionMachine.resume(s, at(12)));
      final r = FocusSessionMachine.recover(s, at(60));
      expect(r, isA<AskPomodoroOverdue>());
      final end = (r as AskPomodoroOverdue).plannedEnd;
      expect(end.utc, at(27).utc);
      // "Count until the planned end" gives exactly the planned interval.
      final (_, rec) = ok(FocusSessionMachine.end(s, end, count: true));
      expect(rec!.focusTime, defaultPomodoro);
    });

    test('a pomodoro still within its time, a paused one, and a stopwatch resume as they were', () {
      expect(FocusSessionMachine.recover(pomodoro(), at(12)), isA<ResumeAsItWas>());
      final paused = ok(FocusSessionMachine.pause(pomodoro(), at(10)));
      expect(FocusSessionMachine.recover(paused, at(500)), isA<ResumeAsItWas>()); // the pause stops the clock
      expect(FocusSessionMachine.recover(stopwatch(), at(500)), isA<ResumeAsItWas>());
    });

    test('a stored session that cannot be trusted is unrecoverable, never dropped', () {
      final bad = FocusSession(
          id: 'b', mode: FocusMode.pomodoro, startedAt: t0, state: FocusState.paused, planned: defaultPomodoro);
      final r = FocusSessionMachine.recover(bad, at(1));
      expect(r, isA<Unrecoverable>());
      expect((r as Unrecoverable).session.id, 'b');
    });

    test('kill after any step: the stored session gives the same time on recovery (GS-13 at the domain level)', () {
      // Steps of one session; after each one the app could be killed.
      final steps = <FocusSession Function(FocusSession)>[
        (s) => ok(FocusSessionMachine.pause(s, at(12))),
        (s) => ok(FocusSessionMachine.resume(s, at(14))),
        (s) => ok(FocusSessionMachine.pause(s, at(20))),
      ];
      var stored = stopwatch();
      final truth = <Duration>[];
      for (final step in [null, ...steps]) {
        if (step != null) stored = step(stored);
        // Relaunch at 21:30.
        final r = FocusSessionMachine.recover(stored, at(21, 30)) as ResumeAsItWas;
        truth.add(FocusSessionMachine.focusTime(r.session, at(21, 30)));
      }
      expect(truth, [
        const Duration(minutes: 21, seconds: 30), // running since 0
        const Duration(minutes: 12), // paused at 12
        const Duration(minutes: 19, seconds: 30), // resumed at 14
        const Duration(minutes: 18), // paused at 20
      ]);
    });
  });
}
