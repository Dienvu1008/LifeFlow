// P06b W5 (owner UI 3): documents are dragged in the tree as items are in
// the Overview.
//   rule      before / into / after a row; after an open row with
//             subdocuments: its first one; never into itself or under it;
//             where it already is: nothing
//   tree      a long press drags (touch); the handle drags (desktop); the line
//             or the highlight shows where it lands; the move is sent with
//             its place; a folded target opens; a viewer drags nothing
import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/documents/documents_screen.dart';
import 'package:ui/src/overview_tree.dart' show DropZone;

import 'documents_flow_test.dart' show openDocuments, pumpApp, world;
import 'fake_spaces.dart';
import 'fake_world.dart' show FakeWorld;

DocumentNodeView n(String id, {String? parent}) => DocumentNodeView(id: id, title: id, parentId: parent, orderKey: '');

/// A
///   A1
///   A2
/// B
/// C
final tree = [n('A'), n('A1', parent: 'A'), n('A2', parent: 'A'), n('B'), n('C')];

void main() {
  group('the rule', () {
    DocumentDrop? drop(String dragged, String target, DropZone z, {Set<String> collapsed = const {}}) =>
        resolveDocumentDrop(tree, collapsed, dragged, target, z);

    test('before, into and after a row', () {
      expect(drop('C', 'B', DropZone.before), (parentId: null, afterId: 'A'));
      expect(drop('C', 'A', DropZone.before), (parentId: null, afterId: null), reason: 'first at the top');
      expect(drop('C', 'B', DropZone.into), (parentId: 'B', afterId: null));
      expect(drop('C', 'A', DropZone.into), (parentId: 'A', afterId: 'A2'), reason: 'its last subdocument');
      expect(drop('A1', 'B', DropZone.after), (parentId: null, afterId: 'B'));
      expect(drop('B', 'A2', DropZone.before), (parentId: 'A', afterId: 'A1'));
    });

    test('after an open row with subdocuments: its first one; folded: after it', () {
      expect(drop('C', 'A', DropZone.after), (parentId: 'A', afterId: null));
      expect(drop('C', 'A', DropZone.after, collapsed: {'A'}), (parentId: null, afterId: 'A'));
    });

    test('never into itself or under it; where it already is: nothing', () {
      expect(drop('A', 'A', DropZone.into), isNull);
      expect(drop('A', 'A1', DropZone.into), isNull);
      expect(drop('A', 'A2', DropZone.after), isNull);
      expect(drop('B', 'A', DropZone.after, collapsed: {'A'}), isNull, reason: 'B is after A already');
      expect(drop('B', 'C', DropZone.before), isNull);
      expect(drop('A2', 'A1', DropZone.after), isNull);
      expect(drop('A1', 'A2', DropZone.after), (parentId: 'A', afterId: 'A2'));
      expect(drop('x', 'A', DropZone.into), isNull);
    });
  });

  group('the tree', () {
    late Map<String, String> ids;

    Future<FakeWorld> setUpTree(WidgetTester tester, {FakeSpaces? spaces}) async {
      final w = world();
      final a = w.documents.put('Dự án');
      final a1 = w.documents.put('Ngân sách', parentId: a);
      final b = w.documents.put('Nhật ký');
      final c = w.documents.put('Công thức');
      ids = {'A': a, 'A1': a1, 'B': b, 'C': c};
      await pumpApp(tester, w, spaces: spaces);
      await openDocuments(tester);
      return w;
    }

    List<String> order(WidgetTester tester) {
      final tiles = tester.widgetList<ListTile>(find.descendant(of: find.byKey(const Key('doc-tree')), matching: find.byType(ListTile)));
      return [for (final t in tiles) (t.title as Text).data!];
    }

    /// Long-presses [dragged] and moves it to [fraction] of [target]'s row
    /// height; [check] runs while it hovers there.
    Future<void> drag(WidgetTester tester, String dragged, String target, double fraction, {void Function()? check}) async {
      final from = tester.getCenter(find.byKey(ValueKey('doc-${ids[dragged]}')));
      final rect = tester.getRect(find.byKey(ValueKey('doc-slot-${ids[target]}')));
      final to = Offset(rect.center.dx, rect.top + rect.height * fraction);
      final g = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await g.moveTo(Offset.lerp(from, to, 0.5)!);
      await tester.pump();
      await g.moveTo(to);
      await tester.pump();
      check?.call();
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a long press drags a document after another: the line shows, the move is sent with its place', (tester) async {
      final w = await setUpTree(tester);
      expect(order(tester), ['Dự án', 'Ngân sách', 'Nhật ký', 'Công thức']);
      await drag(tester, 'B', 'C', 0.9, check: () => expect(find.byKey(const Key('doc-drop-line')), findsOneWidget));
      expect(w.calls, containsAllInOrder(['doc.move:${ids['B']}:null', 'doc.after:${ids['B']}:${ids['C']}']));
      expect(order(tester), ['Dự án', 'Ngân sách', 'Công thức', 'Nhật ký']);
    });

    testWidgets('into a document: highlighted, it goes last under it; a folded one opens', (tester) async {
      final w = await setUpTree(tester);
      await tester.tap(find.byKey(ValueKey('doc-toggle-${ids['A']}')));
      await tester.pumpAndSettle();
      expect(order(tester), ['Dự án', 'Nhật ký', 'Công thức'], reason: 'folded');
      await drag(tester, 'C', 'A', 0.5, check: () => expect(find.byKey(const Key('doc-drop-into')), findsOneWidget));
      expect(w.calls, containsAllInOrder(['doc.move:${ids['C']}:${ids['A']}', 'doc.after:${ids['C']}:${ids['A1']}']));
      expect(order(tester), ['Dự án', 'Ngân sách', 'Công thức', 'Nhật ký'], reason: 'opened, the document last under it');
    });

    testWidgets('over itself or under itself: nothing shown, nothing sent', (tester) async {
      final w = await setUpTree(tester);
      await drag(tester, 'A', 'A1', 0.5, check: () {
        expect(find.byKey(const Key('doc-drop-into')), findsNothing);
        expect(find.byKey(const Key('doc-drop-line')), findsNothing);
      });
      expect(w.calls.where((c) => c.startsWith('doc.move:')), isEmpty);
    });

    testWidgets('on a desktop the handle drags', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final w = await setUpTree(tester);
      final handle = find.byKey(ValueKey('drag-${ids['C']}'));
      expect(handle, findsOneWidget);
      final rect = tester.getRect(find.byKey(ValueKey('doc-slot-${ids['B']}')));
      final g = await tester.startGesture(tester.getCenter(handle));
      await g.moveBy(const Offset(0, -10));
      await tester.pump();
      await g.moveTo(Offset(rect.center.dx, rect.top + rect.height * 0.1));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(w.calls, containsAllInOrder(['doc.move:${ids['C']}:null', 'doc.after:${ids['C']}:${ids['A']}']));
      expect(order(tester), ['Dự án', 'Ngân sách', 'Công thức', 'Nhật ký']);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a viewer drags nothing', (tester) async {
      final s = FakeSpaces(spaces: [
        const SpaceView(id: 'personal', shared: false, isShown: false),
        SpaceView(id: family.id, shared: true, isShown: true, name: family.name, role: SpaceRole.viewer, members: family.members),
      ]);
      await setUpTree(tester, spaces: s);
      expect(find.byKey(ValueKey('doc-slot-${ids['A']}')), findsNothing);
      expect(find.byKey(ValueKey('doc-${ids['A']}')), findsOneWidget);
    });
  });
}

