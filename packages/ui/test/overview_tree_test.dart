// P03 UX U3 (ADR-0047): the Overview's rows and where a drop or a menu move
// puts an item. Pure functions; the store checks every move again.
import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/overview_tree.dart';

import 'fake_world.dart';

TaskListView list(String id, String key) => TaskListView(id: id, title: id, orderKey: key);
OverviewEventView event(String id, String key, {String? list}) =>
    OverviewEventView(id: id, title: id, orderKey: key, listId: list);
TaskView t(String id, String key, {String? parent, String? list}) => TaskView(
    id: id, title: id, status: 'todo', parentId: parent, createdAt: DateTime(2026), listId: list, orderKey: key);

/// Work: W1 (with W1a > W1b), event WE; Home: empty; loose: A, E, B.
OverviewIndex sample() => OverviewIndex(
      lists: [list('Work', 'a0'), list('Home', 'a1')],
      tasks: [
        t('W1', 'a0', list: 'Work'),
        t('W1a', 'a0', parent: 'W1'),
        t('W1b', 'a0', parent: 'W1a'),
        t('A', 'a0'),
        t('B', 'a2'),
      ],
      events: [event('WE', 'a1', list: 'Work'), event('E', 'a1')],
    );

String ids(List<OverviewRow> rows) => rows
    .map((r) => switch (r) {
          ListRow() => '[${r.id}]',
          LooseHeaderRow() => '--',
          TaskItemRow() => '${'.' * r.level}${r.id}',
          EventItemRow() => '@${r.id}',
        })
    .join(' ');

String place(MovePlan? p) => switch (p) {
      null => 'none',
      MoveListPlan(:final listId, :final afterId) => 'list $listId after $afterId',
      MoveItemPlan(:final id, :final place) => '$id ${FakeOverview.describe(place)}',
    };

void main() {
  test('rows: lists with their items, then the items in no list; collapse hides', () {
    final ix = sample();
    expect(ids(overviewRows(ix, {})), '[Work] W1 .W1a ..W1b @WE [Home] -- A @E B');
    expect(ids(overviewRows(ix, {'W1a'})), '[Work] W1 .W1a @WE [Home] -- A @E B');
    expect(ids(overviewRows(ix, {'Work'})), '[Work] [Home] -- A @E B');
    final rows = overviewRows(ix, {});
    expect((rows[1] as TaskItemRow).hasChildren, isTrue);
    expect((rows[3] as TaskItemRow).hasChildren, isFalse);
    expect([for (final r in rows) r.indent], [0, 1, 2, 3, 1, 0, 0, 0, 0, 0]);
    expect((rows[0] as ListRow).itemCount, 2);
    // No lists: no heading over the loose items.
    final bare = OverviewIndex(lists: const [], tasks: [t('A', 'a0')], events: const []);
    expect(ids(overviewRows(bare, {})), 'A');
  });

  test('an item in an unknown list, or under a missing parent, shows in no list', () {
    final ix = OverviewIndex(
        lists: const [], tasks: [t('X', 'a0', list: 'gone'), t('Y', 'a1', parent: 'missing')], events: const []);
    expect(ids(overviewRows(ix, {})), 'X Y');
  });

  group('drop', () {
    late OverviewIndex ix;
    late List<OverviewRow> rows;
    int at(String id) => rows.indexWhere((r) => r.id == id);
    setUp(() {
      ix = sample();
      rows = overviewRows(ix, {});
    });
    String drop(String id, String on, DropZone zone, [int shift = 0]) =>
        place(resolveDrop(ix, rows, id, at(on), zone, shift));

    test('below a row: same level after it; right = its first child; left = up a level', () {
      expect(drop('B', 'A', DropZone.after), 'B loose@A');
      expect(drop('A', 'E', DropZone.after), 'A loose@E');
      expect(drop('B', 'W1a', DropZone.after), 'B under:W1@W1a');
      expect(drop('B', 'W1a', DropZone.after, 1), 'B under:W1a@null');
      expect(drop('B', 'W1b', DropZone.after, -1), 'B under:W1@W1a');
      expect(drop('B', 'W1b', DropZone.after, -2), 'B in:Work@W1');
      expect(drop('B', 'W1b', DropZone.after, -9), 'B in:Work@W1');
    });

    test('above a row: right after the row before it, at this row\'s level', () {
      expect(drop('B', 'A', DropZone.before), 'B loose@null');
      expect(drop('B', 'WE', DropZone.before), 'B in:Work@W1');
      expect(drop('B', 'W1a', DropZone.before), 'B under:W1@null');
      // Above the first list: no place for an item.
      expect(drop('B', 'Work', DropZone.before), 'none');
    });

    test('onto a task: its last subtask; onto a list: the first in it', () {
      expect(drop('B', 'W1', DropZone.into), 'B under:W1@W1a');
      expect(drop('B', 'A', DropZone.into), 'B under:A@null');
      expect(drop('A', 'Home', DropZone.into), 'A in:Home@null');
      expect(drop('A', 'Work', DropZone.into), 'A in:Work@null');
    });

    test('an event is never put under a task (U-D1)', () {
      expect(drop('E', 'B', DropZone.into), 'E loose@B');
      expect(drop('E', 'W1a', DropZone.after, 1), 'E in:Work@W1');
      expect(drop('WE', 'B', DropZone.after), 'WE loose@B');
      // A task dragged right after an event stays beside it (an event has no subtasks).
      expect(drop('A', 'E', DropZone.after, 1), 'A loose@E');
    });

    test('never into its own subtree; never deeper than 4 levels with its subtasks', () {
      expect(drop('W1', 'W1b', DropZone.into), 'none');
      expect(drop('W1a', 'W1b', DropZone.after), 'none');
      // Shallow enough for the depth limit: only the cycle stops it.
      final small = OverviewIndex(lists: const [], tasks: [t('X', 'a0'), t('Y', 'a0', parent: 'X')], events: const []);
      final sr = overviewRows(small, {});
      expect(place(resolveDrop(small, sr, 'X', 1, DropZone.into, 0)), 'none');
      expect(place(indent(small, 'Y')), 'none');
      // W1 has 3 levels: under A (level 0) its deepest would be level 3: ok;
      // under W1b's sibling level it would not fit.
      expect(drop('W1', 'A', DropZone.into), 'W1 under:A@null');
      final deep = overviewRows(ix, {});
      expect(place(resolveDrop(ix, deep, 'A', deep.indexWhere((r) => r.id == 'W1b'), DropZone.into, 0)), 'A under:W1b@null');
      // B under W1b would be level 3: allowed; W1 there would be level 5: refused.
      final nested = OverviewIndex(
          lists: const [],
          tasks: [t('P', 'a0'), t('Q', 'a0', parent: 'P'), t('R', 'a0', parent: 'Q'), t('S', 'a1'), t('S1', 'a0', parent: 'S')],
          events: const []);
      final r = overviewRows(nested, {});
      expect(place(resolveDrop(nested, r, 'S', r.indexWhere((x) => x.id == 'R'), DropZone.into, 0)), 'none');
      expect(place(resolveDrop(nested, r, 'S', r.indexWhere((x) => x.id == 'Q'), DropZone.into, 0)), 'S under:Q@R');
    });

    test('a drop that changes nothing is no command', () {
      expect(drop('E', 'A', DropZone.after), 'none');
      expect(drop('B', 'E', DropZone.after), 'none');
      expect(drop('W1a', 'W1', DropZone.after, 1), 'none');
    });

    test('lists move among lists only', () {
      expect(drop('Home', 'Work', DropZone.before), 'list Home after null');
      expect(drop('Work', 'Home', DropZone.into), 'list Work after Home');
      expect(drop('Work', 'A', DropZone.after), 'list Work after Home');
      expect(drop('Home', 'W1b', DropZone.after), 'none'); // already after Work
      expect(drop('Work', 'Work', DropZone.into), 'none');
    });
  });

  group('menu moves (no drag needed, WCAG 2.5.7)', () {
    final ix = sample();
    test('up and down within the container', () {
      expect(place(moveUp(ix, 'E')), 'E loose@null');
      expect(place(moveUp(ix, 'B')), 'B loose@A');
      expect(place(moveUp(ix, 'A')), 'none');
      expect(place(moveDown(ix, 'A')), 'A loose@E');
      expect(place(moveDown(ix, 'B')), 'none');
      expect(place(moveDown(ix, 'Work')), 'list Work after Home');
      expect(place(moveUp(ix, 'Home')), 'list Home after null');
    });
    test('indent under the task above; outdent after the parent', () {
      expect(place(indent(ix, 'E')), 'none'); // an event
      expect(place(indent(ix, 'B')), 'none'); // the item above is an event
      expect(place(indent(ix, 'A')), 'none'); // first
      expect(place(outdent(ix, 'W1b')), 'W1b under:W1@W1a');
      expect(place(outdent(ix, 'W1a')), 'W1a in:Work@W1');
      expect(place(outdent(ix, 'A')), 'none');
      final two = OverviewIndex(lists: const [], tasks: [t('A', 'a0'), t('B', 'a1'), t('A1', 'a0', parent: 'A')], events: const []);
      expect(place(indent(two, 'B')), 'B under:A@A1');
    });
    test('to a list, at its end', () {
      expect(place(moveToList(ix, 'A', 'Work')), 'A in:Work@WE');
      expect(place(moveToList(ix, 'WE', null)), 'WE loose@B');
      expect(place(moveToList(ix, 'A', 'Home')), 'A in:Home@null');
    });
  });
}
