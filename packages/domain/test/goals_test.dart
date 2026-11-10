// P03 T1 (ADR-0036): goal progress (D11).
//   LF-INV-GOAL-001 / GS-21  progress is a pure function of the linked items;
//                            computing it changes nothing
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('with milestones: done milestones / all (milestones are completed by hand)', () {
    final p = goalProgress(milestonesDone: [true, false, true, false], links: const [LinkedTask(done: true)]);
    expect((p.basis, p.done, p.total, p.ratio), (ProgressBasis.milestones, 2.0, 4, 0.5));
  });

  test('without milestones: linked tasks count 0 or 1, habits their rate; trashed, cancelled and events do not count', () {
    final p = goalProgress(milestonesDone: const [], links: const [
      LinkedTask(done: true),
      LinkedTask(done: false),
      LinkedTask(done: true, trashed: true),
      LinkedTask(done: false, cancelled: true),
      LinkedHabit(successes: 3, judged: 4),
      LinkedHabit(successes: 0, judged: 0), // no ended period yet
      LinkedEvent(),
    ]);
    expect((p.basis, p.total), (ProgressBasis.links, 3));
    expect(p.ratio, closeTo((1 + 0 + 0.75) / 3, 1e-12));
  });

  test('nothing to count: no progress yet (not 0%)', () {
    final p = goalProgress(milestonesDone: const [], links: const [LinkedEvent()]);
    expect((p.basis, p.ratio), (ProgressBasis.none, null));
  });

  test('GS-21: the same items always give the same progress; the inputs are untouched', () {
    final links = [const LinkedTask(done: true), const LinkedHabit(successes: 1, judged: 2)];
    final milestones = <bool>[];
    final a = goalProgress(milestonesDone: milestones, links: links);
    final b = goalProgress(milestonesDone: milestones, links: links);
    expect((a.done, a.total), (b.done, b.total));
    expect(links, hasLength(2));
    expect(milestones, isEmpty);
  });
}
