// P06b W6 (ADR-0094; the owner's UI 4): the Archive and the Trash on screen.
//   navigation  both in the drawer and the rail, between Goals and Settings
//   Archive     what is archived, by kind; Unarchive; Move to trash; the
//               switch for scheduled archived items on the Calendar and the
//               Timeline; empty said
//   Trash       what is there, by kind; Restore; Delete forever and Empty
//               trash ask first; the retention is a choice; opening it deletes
//               for good what is old enough; a viewer can only look
//   actions     "Archive" on a task, a list, an event, a document, and the
//               task page, with Undo
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart' show LocalDate;
import 'package:ui/src/documents/document_page.dart' show DocumentPage;
import 'package:ui/src/screens/shelf_screens.dart';
import 'package:ui/ui.dart';

import 'fake_documents.dart';
import 'fake_shelf.dart';
import 'fake_spaces.dart';
import 'fake_world.dart';
import 'nav.dart';

ShelfEntry entry(ShelfKind kind, String id, String title, {int contents = 0, String? place, int day = 3}) =>
    ShelfEntry(kind: kind, id: id, title: title, at: DateTime.utc(2026, 11, day, 12), contents: contents, place: place);

void main() {
  late FakeWorld w;
  late FakeShelf shelf;

  Future<void> pump(WidgetTester tester, {double width = 1200, FakeSpaces? spaces, double height = 1200}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(w.dispose);
    await tester.pumpWidget(appWith(w,
        spaces: spaces,
        sharing: spaces,
        spaceSync: spaces,
        extra: [shelfServiceProvider.overrideWithValue(shelf), shelfQueriesProvider.overrideWithValue(shelf)]));
    await tester.pumpAndSettle();
  }

  setUp(() {
    w = FakeWorld(tasks: {'A': [task('t1', 'Call mum'), task('t2', 'Buy bread')]}, profiles: [profile('A', 'Dien')], activeId: 'A');
    shelf = FakeShelf(w.calls);
  });

  group('navigation', () {
    testWidgets('on the rail and in the drawer, between Goals and Settings', (tester) async {
      await pump(tester);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      final labels = [for (final d in rail.destinations) (d.label as Text).data];
      expect(labels, ['Overview', 'Timeline', 'Calendar', 'Documents', 'Assistant', 'Habits', 'Goals', 'Archive', 'Trash', 'Settings']);
      await goToTab(tester, 'Archive');
      expect(find.byType(ArchiveScreen), findsOneWidget);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 7);
      await goToTab(tester, 'Trash');
      expect(find.byType(TrashScreen), findsOneWidget);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 8);
    });

    testWidgets('the rail does not overflow in a short window', (tester) async {
      await pump(tester, height: 560);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the drawer', (tester) async {
      await pump(tester, width: 400);
      await openDrawer(tester);
      for (final label in ['Archive', 'Trash']) {
        expect(find.descendant(of: find.byKey(const Key('nav-drawer')), matching: find.text(label)), findsOneWidget);
      }
      await tester.tap(find.descendant(of: find.byKey(const Key('nav-drawer')), matching: find.text('Trash')));
      await tester.pumpAndSettle();
      expect(find.byType(TrashScreen), findsOneWidget);
    });
  });

  group('the Archive', () {
    testWidgets('what is archived, with where it was and how many went with it; filtered by kind', (tester) async {
      shelf.archivedList.addAll([
        entry(ShelfKind.list, 'l1', 'Chuyển nhà', contents: 3),
        entry(ShelfKind.task, 't9', 'Thuê xe', place: 'Chuyển nhà', day: 2),
        entry(ShelfKind.document, 'd1', 'Hóa đơn', day: 1),
        entry(ShelfKind.event, 'e1', 'Họp', day: 1),
      ]);
      await pump(tester);
      await goToTab(tester, 'Archive');
      expect(find.text('Chuyển nhà'), findsOneWidget);
      expect(find.textContaining('and 3 more'), findsOneWidget);
      expect(find.textContaining('in Chuyển nhà'), findsOneWidget);
      expect(find.textContaining('Archived'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('shelf-filter-document')));
      await tester.pumpAndSettle();
      expect(find.text('Hóa đơn'), findsOneWidget);
      expect(find.text('Thuê xe'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shelf-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Thuê xe'), findsOneWidget);
    });

    testWidgets('Unarchive brings it back and says so; Move to trash sends it to the trash', (tester) async {
      shelf.archivedList.addAll([entry(ShelfKind.task, 't9', 'Thuê xe'), entry(ShelfKind.event, 'e1', 'Họp')]);
      await pump(tester);
      await goToTab(tester, 'Archive');
      await tester.tap(find.byKey(const ValueKey('unarchive-t9')));
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.unarchive:task:t9'));
      expect(find.text('Thuê xe'), findsNothing);
      expect(find.text('“Thuê xe” is back'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('archived-menu-e1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to trash'));
      await tester.pumpAndSettle();
      expect(w.calls, contains('event.trash:e1'));
    });

    testWidgets('nothing archived: said', (tester) async {
      await pump(tester);
      await goToTab(tester, 'Archive');
      expect(find.byKey(const Key('archive-empty')), findsOneWidget);
    });

    testWidgets('the switch for archived items on the Calendar and the Timeline', (tester) async {
      await pump(tester);
      await goToTab(tester, 'Archive');
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('archive-show-scheduled'))).value, isFalse, reason: 'hidden by default');
      await tester.tap(find.byKey(const Key('archive-show-scheduled')));
      await tester.pumpAndSettle();
      expect(w.calls, contains('showArchived:true'));
      expect(w.showArchived, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('archive-show-scheduled'))).value, isTrue);
      await tester.tap(find.byKey(const Key('archive-show-scheduled')));
      await tester.pumpAndSettle();
      expect(w.showArchived, isFalse);
    });

    testWidgets('the setting is read when it was on before', (tester) async {
      w.showArchived = true;
      await pump(tester);
      await goToTab(tester, 'Archive');
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('archive-show-scheduled'))).value, isTrue);
    });
  });

  group('the Trash', () {
    testWidgets('what is there; Restore; opening it deletes for good what is old enough', (tester) async {
      shelf.trashedList.addAll([
        entry(ShelfKind.task, 't9', 'Đơn cũ'),
        entry(ShelfKind.document, 'd1', 'Nháp', contents: 2),
      ]);
      await pump(tester);
      await goToTab(tester, 'Trash');
      expect(w.calls, contains('shelf.expire:30'), reason: 'the retention, 30 days by default');
      expect(find.text('Đơn cũ'), findsOneWidget);
      expect(find.textContaining('Trashed'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('restore-t9')));
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.restore:task:t9'));
      expect(find.text('“Đơn cũ” restored'), findsOneWidget);
      expect(find.byKey(const ValueKey('trashed-task-t9')), findsNothing);
    });

    testWidgets('Delete forever asks first; Cancel deletes nothing', (tester) async {
      shelf.trashedList.add(entry(ShelfKind.task, 't9', 'Đơn cũ'));
      await pump(tester);
      await goToTab(tester, 'Trash');
      await tester.tap(find.byKey(const ValueKey('purge-t9')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shelf-confirm')), findsOneWidget);
      expect(find.textContaining('This cannot be undone'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls.where((c) => c.startsWith('shelf.purge')), isEmpty);

      await tester.tap(find.byKey(const ValueKey('purge-t9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shelf-confirm-yes')));
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.purge:task:t9'));
      expect(find.text('Deleted for good'), findsOneWidget);
    });

    testWidgets('Empty trash asks first and says how many went', (tester) async {
      shelf.trashedList.addAll([entry(ShelfKind.task, 't9', 'A'), entry(ShelfKind.event, 'e1', 'B')]);
      await pump(tester);
      await goToTab(tester, 'Trash');
      await tester.tap(find.byKey(const Key('trash-empty')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 items'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shelf-confirm-yes')));
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.empty'));
      expect(find.text('2 items deleted for good'), findsOneWidget);
      expect(find.byKey(const Key('trash-empty-text')), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const Key('trash-empty'))).onPressed, isNull, reason: 'nothing to empty');
    });

    testWidgets('the retention is a choice; the new one is used at once', (tester) async {
      await pump(tester);
      await goToTab(tester, 'Trash');
      expect(tester.widget<DropdownButton<int>>(find.byKey(const Key('trash-retention'))).value, 30);
      await tester.tap(find.byKey(const Key('trash-retention')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days').last);
      await tester.pumpAndSettle();
      expect(w.calls, contains('retention:7'));
      expect(w.retentionDays, 7);
      expect(w.calls, contains('shelf.expire:7'));
      await tester.tap(find.byKey(const Key('trash-retention')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Until I empty the trash').last);
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.expire:0'));
    });

    testWidgets('a viewer of a shared space can only look', (tester) async {
      shelf.trashedList.add(entry(ShelfKind.task, 't9', 'Đơn cũ'));
      final s = FakeSpaces(spaces: [
        const SpaceView(id: 'personal', shared: false, isShown: false),
        SpaceView(id: family.id, shared: true, isShown: true, name: family.name, role: SpaceRole.viewer, members: family.members),
      ]);
      await pump(tester, spaces: s);
      await goToTab(tester, 'Trash');
      expect(find.text('Đơn cũ'), findsOneWidget);
      expect(find.byKey(const ValueKey('restore-t9')), findsNothing);
      expect(find.byKey(const ValueKey('purge-t9')), findsNothing);
      expect(find.byKey(const Key('trash-empty')), findsNothing);
      expect(w.calls.where((c) => c.startsWith('shelf.expire')), isEmpty, reason: 'nothing is deleted for them');
    });

    testWidgets('empty: said', (tester) async {
      await pump(tester);
      await goToTab(tester, 'Trash');
      expect(find.byKey(const Key('trash-empty-text')), findsOneWidget);
    });
  });

  group('actions', () {
    Future<void> menuItem(WidgetTester tester, String title, String item) async {
      await tester.tap(find.byTooltip('Actions for $title'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    testWidgets('Archive on a task, a list and an event of the Overview, each with Undo', (tester) async {
      w.overview.lists.add(const TaskListView(id: 'L', title: 'Work', orderKey: ''));
      w.overview.events.add(const OverviewEventView(id: 'E', title: 'Dentist', orderKey: ''));
      w.overview.order.addAll(['L', 'E', 't1', 't2']);
      await pump(tester);
      await menuItem(tester, 'Call mum', 'Archive');
      expect(w.calls, contains('shelf.archive:task:t1'));
      expect(find.text('“Call mum” archived'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.unarchive:task:t1'));

      await menuItem(tester, 'Work', 'Archive');
      expect(w.calls, contains('shelf.archive:list:L'));
      await menuItem(tester, 'Dentist', 'Archive');
      expect(w.calls, contains('shelf.archive:event:E'));
    });

    testWidgets('Archive on the task page leaves it', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Buy bread'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-page')), findsOneWidget);
      await tester.tap(find.byKey(const Key('task-page-archive')));
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.archive:task:t2'));
      expect(find.byKey(const Key('task-page')), findsNothing);
    });

    testWidgets('Archive on a document, in the tree and on its page', (tester) async {
      final a = w.documents.put('Ghi chú', body: FakeDocuments.text('Nội dung'));
      final b = w.documents.put('Hợp đồng', body: FakeDocuments.text('Điều khoản'));
      await pump(tester);
      await goToTab(tester, 'Documents');
      await tester.tap(find.byKey(ValueKey('doc-menu-$a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.archive:document:$a'));

      await tester.tap(find.byKey(ValueKey('doc-$b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doc-page-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      expect(w.calls, contains('shelf.archive:document:$b'));
      expect(find.byType(DocumentPage), findsNothing, reason: 'archived from its page, it leaves it');
    });

    testWidgets('a refused archive is said, the page stays', (tester) async {
      shelf.failure = const CommandFailure(CommandFailureKind.validationFailed, reason: 'task is in the trash');
      await pump(tester);
      await tester.tap(find.text('Buy bread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-page-archive')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-page')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  test('changing the switch asks the Calendar, the Timeline and the agendas again', () async {
    final fake = FakeWorld(tasks: {'A': []}, profiles: [profile('A', 'Dien')], activeId: 'A');
    addTearDown(fake.dispose);
    final asked = _CountingCalendar();
    final c = ProviderContainer(overrides: [
      settingsServiceProvider.overrideWithValue(fake),
      calendarQueriesProvider.overrideWithValue(asked),
      activeProfileProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(c.dispose);
    final range = (from: testToday, to: testToday.addDays(6));
    final sub = c.listen(calendarRangeProvider(range), (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(asked.subscriptions, 1);
    await c.read(showArchivedScheduledProvider.notifier).set(true);
    await Future<void>.delayed(Duration.zero);
    expect(asked.subscriptions, 2, reason: 'the range is asked again, now with archived items');
    expect(fake.showArchived, isTrue, reason: 'written before it was asked again');
  });

  test('showArchivedScheduled: the setting is written before the screens read it again', () async {
    final fake = FakeWorld(tasks: {'A': []}, profiles: [profile('A', 'Dien')], activeId: 'A');
    addTearDown(fake.dispose);
    final c = ProviderContainer(overrides: [settingsServiceProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);
    await c.read(showArchivedScheduledProvider.notifier).set(true);
    expect(fake.showArchived, isTrue);
    expect(c.read(showArchivedScheduledProvider), isTrue);
  });
}

/// A calendar that counts how often a range is asked for.
class _CountingCalendar implements CalendarQueries {
  int subscriptions = 0;

  @override
  Stream<CalendarRange> watchRange(LocalDate from, LocalDate to) {
    subscriptions++;
    return Stream.value(const CalendarRange(events: [], tasks: [], conflicts: []));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
