// Pure UI logic: breakpoints (OQ-UI-1 provisional) and task-tree ordering.
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'fake_world.dart';

void main() {
  group('layoutClassFor', () {
    test('uses width, not device type, with the documented boundaries', () {
      expect(layoutClassFor(320), LayoutClass.compact);
      expect(layoutClassFor(599.9), LayoutClass.compact);
      expect(layoutClassFor(600), LayoutClass.medium);
      expect(layoutClassFor(839.9), LayoutClass.medium);
      expect(layoutClassFor(840), LayoutClass.expanded);
      expect(layoutClassFor(1920), LayoutClass.expanded);
    });
  });

  group('orderTree', () {
    test('depth-first, siblings keep creation order', () {
      final rows = orderTree([
        task('a', 'A'),
        task('b', 'B'),
        task('a1', 'A1', parent: 'a'),
        task('a2', 'A2', parent: 'a'),
        task('a1x', 'A1x', parent: 'a1'),
      ]);
      expect(rows.map((r) => r.task.id), ['a', 'a1', 'a1x', 'a2', 'b']);
      expect(rows.map((r) => r.depth), [0, 1, 2, 1, 0]);
    });

    test('hasOpenChildren is true only while a direct child is open', () {
      final open = orderTree([task('p', 'P'), task('c', 'C', parent: 'p')]);
      expect(open.first.hasOpenChildren, isTrue);
      final closed = orderTree([
        task('p', 'P'),
        task('c', 'C', parent: 'p', status: 'done'),
      ]);
      expect(closed.first.hasOpenChildren, isFalse);
    });

    test('a task whose parent is missing (trashed) is shown as a root', () {
      final rows = orderTree([task('c', 'C', parent: 'gone')]);
      expect(rows.single.depth, 0);
    });

    test('is cycle-safe: every task appears at most once', () {
      final rows = orderTree([
        task('x', 'X', parent: 'y'),
        task('y', 'Y', parent: 'x'),
      ]);
      // A pure cycle has no root; it must not hang and must not hide tasks.
      expect(rows.map((r) => r.task.id).toSet(), {'x', 'y'});
      expect(rows.length, 2);
    });

    test('empty input gives empty output', () {
      expect(orderTree(const []), isEmpty);
    });
  });
}
