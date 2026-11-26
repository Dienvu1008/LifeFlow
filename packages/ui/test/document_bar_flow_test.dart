// P06b W3 (owner UI 2): the document page's app bar. The title fills it and
// slides when too long; the button beside it opens the title under the bar
// for editing, the cursor at its end. The save state is an icon. Read aloud
// and the backlinks are in the options menu, not on the bar or under the
// text.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/documents/document_page.dart';

import 'documents_flow_test.dart' show docMenu, docStatus, openDocuments, pumpApp, saves, tapKey, typeAtEnd, world;
import 'fake_documents.dart';
import 'fake_world.dart';

Future<String> openDoc(WidgetTester tester, FakeWorld w, String title, {double width = 1000, String body = 'Phở bò'}) async {
  final d = w.documents.put(title, body: FakeDocuments.text(body));
  await pumpApp(tester, w, width: width);
  await openDocuments(tester);
  await tester.tap(find.byKey(ValueKey('doc-$d')));
  await tester.pumpAndSettle();
  return d;
}

final _appTitle = find.byKey(const Key('doc-app-title'));
final _field = find.byKey(const Key('doc-title'));

void main() {
  testWidgets('the title is in the app bar; the button opens it below with the cursor at the end, and closes it', (tester) async {
    final w = world();
    final d = await openDoc(tester, w, 'Nhật ký');
    expect(find.descendant(of: find.byType(AppBar), matching: _appTitle), findsOneWidget);
    expect(find.descendant(of: _appTitle, matching: find.text('Nhật ký')), findsOneWidget);
    expect(_field, findsNothing, reason: 'closed at first: the text gets the room');

    await tapKey(tester, 'doc-title-edit');
    expect(_field, findsOneWidget);
    final field = tester.widget<TextField>(_field);
    expect(field.focusNode!.hasFocus, isTrue, reason: 'ready to type');
    expect(field.controller!.selection, const TextSelection.collapsed(offset: 7), reason: 'the cursor at the end');

    await tester.enterText(_field, 'Nhật ký tháng 11');
    await tester.pump();
    expect(find.descendant(of: _appTitle, matching: find.text('Nhật ký tháng 11')), findsOneWidget, reason: 'the bar follows');
    expect(docStatus(tester), 'Not saved yet');

    await tapKey(tester, 'doc-title-edit');
    expect(_field, findsNothing);
    await tester.pumpAndSettle();
    expect(saves(w), ['doc.save:$d:Nhật ký tháng 11:Phở bò'], reason: 'closing saves');
    expect(docStatus(tester), 'Saved');
  });

  testWidgets('Enter in the title closes it too', (tester) async {
    final w = world();
    await openDoc(tester, w, 'Nhật ký');
    await tapKey(tester, 'doc-title-edit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_field, findsNothing);
  });

  testWidgets('a long title slides inside the bar, then rests cut', (tester) async {
    final w = world();
    await openDoc(tester, w, 'Kế hoạch đi chơi Đà Lạt cùng cả nhà vào dịp cuối năm 2026', width: 360);
    // It played once on opening; a changed title plays again.
    await tapKey(tester, 'doc-title-edit');
    await tester.enterText(_field, 'Kế hoạch đi chơi Đà Lạt cùng cả nhà vào dịp Tết năm 2027');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.descendant(of: _appTitle, matching: find.byKey(const Key('marquee'))), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _appTitle, matching: find.byKey(const Key('marquee'))), findsNothing);
  });

  testWidgets('the save state is an icon with its words; a tap says them', (tester) async {
    final w = world();
    await openDoc(tester, w, 'Nháp');
    IconData iconOf() =>
        tester.widget<Icon>(find.descendant(of: find.byKey(const Key('doc-status')), matching: find.byType(Icon))).icon!;
    expect(find.byKey(const Key('doc-status-saved')), findsOneWidget);
    final saved = iconOf();
    expect(find.text('Saved'), findsNothing, reason: 'no line of text under the title any more');
    typeAtEnd(tester, ' ngon');
    await tester.pump();
    expect(find.byKey(const Key('doc-status-unsaved')), findsOneWidget);
    expect(iconOf(), isNot(saved), reason: 'another icon, not only other words');
    await tester.tap(find.byKey(const Key('doc-status')));
    await tester.pump();
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('Not saved yet')), findsOneWidget);
  });

  testWidgets('a document in the trash: the banner says it; the title cannot be opened', (tester) async {
    final w = world();
    final d = w.documents.put('Cũ', body: FakeDocuments.text('Ngày xưa'));
    w.documents.docs[d]!.trashed = true;
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tapKey(tester, 'doc-open-trash');
    await tester.tap(find.byKey(ValueKey('doc-trashed-$d')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-in-trash')), findsOneWidget);
    expect(find.byKey(const Key('doc-status')), findsNothing, reason: 'nothing is saved here; the banner says why');
    expect(find.byKey(const Key('doc-title-edit')), findsNothing);
    expect(find.byKey(const Key('doc-title')), findsNothing);
  });

  testWidgets('read aloud is in the menu, not on the bar; the entry then stops it', (tester) async {
    final w = world();
    await openDoc(tester, w, 'Thơ', body: 'Một câu. Hai câu.');
    expect(find.byKey(const Key('doc-read-aloud')), findsNothing, reason: 'not on the bar');
    await docMenu(tester, 'doc-read-aloud');
    expect(find.byKey(const Key('doc-reader')), findsOneWidget);
    await tapKey(tester, 'doc-page-menu');
    expect(find.descendant(of: find.byKey(const Key('doc-read-aloud')), matching: find.text('Stop reading aloud')), findsOneWidget);
    await tapKey(tester, 'doc-read-aloud');
    expect(find.byKey(const Key('doc-reader')), findsNothing);
  });

  testWidgets('the backlinks and linked items open in a sheet from the menu, not under the text', (tester) async {
    final w = world();
    w.documents.itemTitles['t1'] = 'Nấu phở bò';
    final d = await openDoc(tester, w, 'Kế hoạch');
    await w.documents.link(d, DocumentItemType.task, 't1');
    expect(find.byKey(const Key('doc-links-sheet')), findsNothing, reason: 'no panel under the text');
    expect(find.textContaining('backlink'), findsNothing);
    await docMenu(tester, 'doc-links');
    expect(find.byKey(const Key('doc-links-sheet')), findsOneWidget);
    expect(find.text('No backlinks · 1 linked'), findsOneWidget);
    expect(find.byKey(const ValueKey('linked-task-t1')), findsOneWidget);
    // Unlinked in the sheet: the sheet shows it at once.
    await tapKey(tester, 'unlink-task-t1');
    expect(find.byKey(const ValueKey('linked-task-t1')), findsNothing);
    expect(find.text('No backlinks · nothing linked'), findsOneWidget);
    expect(find.byType(DocumentPage), findsOneWidget);
  });
}
