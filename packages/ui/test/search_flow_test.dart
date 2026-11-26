// P06b W2 (owner UI 1): Search is the first entry of every main screen's
// options menu and of the Overview's +; it opens one search page; the field
// left the Documents app bar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/documents/document_page.dart';
import 'package:ui/src/search/search_page.dart';

import 'documents_flow_test.dart' show pumpApp, tapKey, world;
import 'fake_documents.dart';
import 'nav.dart';

/// The labels of the open popup menu, top to bottom.
List<String> menuLabels(WidgetTester tester) => [
      for (final item in tester.widgetList<PopupMenuItem<int>>(find.byType(PopupMenuItem<int>)))
        tester.widget<Text>(find.descendant(of: find.byWidget(item), matching: find.byType(Text)).first).data!,
    ];

Future<void> openMenu(WidgetTester tester, [String key = 'screen-options']) async {
  await tester.tap(find.byKey(Key(key)).hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  for (final tab in ['Overview', 'Timeline', 'Calendar', 'Documents', 'Habits', 'Goals']) {
    testWidgets('$tab: the options menu starts with Search, which opens the search', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      if (tab != 'Overview') await goToTab(tester, tab);
      await openMenu(tester);
      expect(menuLabels(tester).first, 'Search');
      await tester.tap(find.byKey(const Key('options-search')));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
      // The field has the focus: typing needs no tap first.
      expect(tester.widget<TextField>(find.byKey(const Key('search-field'))).autofocus, isTrue);
      await searchFor(tester, 'phở');
      expect(find.byKey(const ValueKey('task-hit-t1')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsNothing);
    });
  }

  testWidgets('the Calendar keeps its own entries under Search', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await goToTab(tester, 'Calendar');
    await openMenu(tester);
    final labels = menuLabels(tester);
    expect(labels.first, 'Search');
    expect(labels.last, 'Manage calendars');
  });

  testWidgets("the Overview's + offers Search first, then list, event, task", (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await tapKey(tester, 'add-menu');
    final order = [
      for (final k in ['add-search', 'add-list', 'add-event', 'add-task']) tester.getTopLeft(find.byKey(Key(k))).dy,
    ];
    expect(order, orderedEquals([...order]..sort()), reason: 'top to bottom');
    await tapKey(tester, 'add-search');
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.byKey(const Key('add-search')), findsNothing, reason: 'the dial closed');
  });

  testWidgets('the document page: Search first, then its own entries', (tester) async {
    final w = world();
    final d = w.documents.put('Công thức', body: FakeDocuments.text('Phở bò'));
    await pumpApp(tester, w);
    await goToTab(tester, 'Documents');
    expect(find.byKey(const Key('search-field')), findsNothing, reason: 'no search field on the Documents screen');
    await tester.tap(find.byKey(ValueKey('doc-$d')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentPage), findsOneWidget);
    await openMenu(tester, 'doc-page-menu');
    final labels = menuLabels(tester);
    expect(labels.first, 'Search');
    expect(labels, containsAllInOrder(['Search', 'History', 'Move to trash']));
    await tester.tap(find.byKey(const Key('options-search')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
  });
}
