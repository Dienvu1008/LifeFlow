// P05a T8 (ADR-0073; p05-plan.md C4–C11, §4): documents in the UI, with fakes.
//   C10     Documents after Calendar: the tree, search at the top, "New
//           document", the trash
//   C7      the editor saves by itself: 10 s after typing, on leaving
//   §4      `[[` offers documents and links one; a link shows the current
//           title; backlinks with their sentence; tasks and goals linked
//   C5/C9   the history, newest first; a version restored as a new one
//   C3      a file attached is kept on the device; one from elsewhere says so
//   B4      a viewer edits nothing; a document in the trash or unreadable
//           is not edited over
import 'dart:async';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/documents/document_page.dart';

import 'fake_documents.dart';
import 'fake_spaces.dart';
import 'fake_world.dart';
import 'nav.dart';

FakeWorld world({List<TaskView>? tasks}) => FakeWorld(
      tasks: {'A': tasks ?? [task('t1', 'Nấu phở bò')]},
      profiles: [profile('A', 'Dien')],
      activeId: 'A',
    );

Future<void> pumpApp(WidgetTester tester, FakeWorld w, {FakeSpaces? spaces, double width = 1000}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w, spaces: spaces, sharing: spaces, spaceSync: spaces));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> openDocuments(WidgetTester tester) => goToTab(tester, 'Documents');

/// P06b W3: the save state, in the tooltip of the icon in the app bar.
String docStatus(WidgetTester tester) => tester.widget<IconButton>(find.byKey(const Key('doc-status'))).tooltip!;

/// P06b W3: an entry [key] of the document page's options menu.
Future<void> docMenu(WidgetTester tester, String key) async {
  await tapKey(tester, 'doc-page-menu');
  await tapKey(tester, key);
}

DocumentPageState pageState(WidgetTester tester) => tester.state<DocumentPageState>(find.byType(DocumentPage));

/// Types [text] at the end of the editor's text.
void typeAtEnd(WidgetTester tester, String text) {
  final c = pageState(tester).controller!;
  final at = c.document.length - 1;
  c.replaceText(at, 0, text, TextSelection.collapsed(offset: at + text.length));
}

List<String> saves(FakeWorld w) => [for (final c in w.calls) if (c.startsWith('doc.save:')) c];

void main() {
  testWidgets('C10: Documents after Calendar; New document opens it; typing saves after 10 s (C7)', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    final rail = find.byType(NavigationRail);
    final labels = [for (final t in tester.widgetList<Text>(find.descendant(of: rail, matching: find.byType(Text)))) t.data];
    expect(labels.indexOf('Documents'), labels.indexOf('Calendar') + 1);
    await openDocuments(tester);
    expect(find.byKey(const Key('docs-empty')), findsOneWidget);

    await tester.tap(find.byTooltip('New document'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ghi chú họp');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(w.calls, contains('doc.create:Ghi chú họp:null'));
    expect(find.byType(DocumentPage), findsOneWidget);
    expect(docStatus(tester), 'Saved');

    typeAtEnd(tester, 'Thứ Hai lúc 9 giờ');
    await tester.pump();
    expect(docStatus(tester), 'Not saved yet');
    expect(saves(w), isEmpty, reason: 'not before 10 s without typing');
    await tester.pump(const Duration(seconds: 9));
    expect(saves(w), isEmpty);
    typeAtEnd(tester, '.');
    await tester.pump(const Duration(seconds: 9));
    expect(saves(w), isEmpty, reason: 'typing again starts the 10 s again');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(saves(w), ['doc.save:d0:Ghi chú họp:Thứ Hai lúc 9 giờ.']);
    expect(docStatus(tester), 'Saved');

    // Nothing changed: leaving writes nothing more.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(saves(w), hasLength(1));
    expect(find.byKey(const ValueKey('doc-d0')), findsOneWidget);
  });

  testWidgets('C7: leaving the page saves it, the title too', (tester) async {
    final w = world();
    final id = w.documents.put('Nhật ký');
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tester.tap(find.byKey(ValueKey('doc-$id')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'doc-title-edit');
    await tester.enterText(find.byKey(const Key('doc-title')), 'Nhật ký tháng 11');
    typeAtEnd(tester, 'Trời mưa');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(saves(w), ['doc.save:$id:Nhật ký tháng 11:Trời mưa']);
    expect(find.text('Nhật ký tháng 11'), findsOneWidget, reason: 'the tree shows the new title');
  });

  testWidgets('C7: the page closed without "back" (the app replaced, a profile switch) still saves', (tester) async {
    final w = world();
    final id = w.documents.put('Nháp');
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tester.tap(find.byKey(ValueKey('doc-$id')));
    await tester.pumpAndSettle();
    typeAtEnd(tester, 'chưa lưu');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(saves(w), ['doc.save:$id:Nháp:chưa lưu']);
  });

  testWidgets('C7: the app going to the background saves; opening a linked document saves first', (tester) async {
    final w = world();
    final other = w.documents.put('Sách');
    final id = w.documents.put('Nhật ký', body: DocumentBody([
      DocBlock('b1', BlockType.paragraph, runs: [TextRun('Xem '), TextRun('Sách', doc: other)]),
    ]));
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tester.tap(find.byKey(ValueKey('doc-$id')));
    await tester.pumpAndSettle();
    typeAtEnd(tester, ' hôm nay');
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(saves(w), ['doc.save:$id:Nhật ký:Xem Sách hôm nay']);

    typeAtEnd(tester, '!');
    await tester.pump();
    final state = pageState(tester);
    // Completes when the opened page is closed; not awaited here.
    unawaited(state.openLinkForTest('lifeflow-doc:$other'));
    await tester.pumpAndSettle();
    expect(saves(w), hasLength(2), reason: 'switching documents saves this one');
    expect(find.byType(DocumentPage, skipOffstage: false), findsNWidgets(2));
  });

  testWidgets('the tree: subdocuments indented and folded; new subdocument, move under, trash and restore', (tester) async {
    final w = world();
    final a = w.documents.put('Du lịch');
    final b = w.documents.put('Huế', parentId: a);
    w.documents.put('Hội An', parentId: a);
    final c = w.documents.put('Công thức');
    await pumpApp(tester, w);
    await openDocuments(tester);
    double left(String id) => tester.getTopLeft(find.descendant(of: find.byKey(ValueKey('doc-$id')), matching: find.text(w.documents.docs[id]!.title))).dx;
    expect(left(b), greaterThan(left(a)));
    await tapKey(tester, 'doc-toggle-$a');
    expect(find.text('Huế'), findsNothing, reason: 'folded');
    await tapKey(tester, 'doc-toggle-$a');
    expect(find.text('Huế'), findsOneWidget);

    await tapKey(tester, 'doc-menu-$c');
    await tester.tap(find.text('Move under…'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('doc-move-to-$c')), findsNothing, reason: 'never under itself');
    await tapKey(tester, 'doc-move-to-$b');
    expect(w.calls, contains('doc.move:$c:$b'));

    await tapKey(tester, 'doc-menu-$a');
    await tester.tap(find.text('New subdocument'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Đà Nẵng');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(w.calls, contains('doc.create:Đà Nẵng:$a'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapKey(tester, 'doc-menu-$a');
    await tester.tap(find.text('Move to trash'));
    await tester.pumpAndSettle();
    expect(find.textContaining('and its subdocuments are in the trash'), findsOneWidget);
    expect(find.text('Du lịch'), findsNothing);
    expect(find.text('Huế'), findsNothing);
    await tapKey(tester, 'doc-open-trash');
    expect(find.byKey(ValueKey('doc-trashed-$a')), findsOneWidget);
    expect(find.byKey(ValueKey('doc-trashed-$b')), findsNothing, reason: 'it went with its parent');
    await tapKey(tester, 'doc-restore-$a');
    expect(w.calls, contains('doc.restore:$a'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Huế'), findsOneWidget);
  });

  testWidgets('one search (C4, C12): documents with their passage, tasks; a hit opens', (tester) async {
    final w = world();
    final d = w.documents.put('Công thức', body: FakeDocuments.text('Phở bò: nấu nước dùng 6 giờ'));
    await pumpApp(tester, w);
    await openDocuments(tester);
    // P06b W2: the field left the Documents app bar; the menu opens it.
    expect(find.byKey(const Key('search-field')), findsNothing);
    await openSearchFromMenu(tester);
    await searchFor(tester, 'phở');
    expect(find.byKey(ValueKey('doc-hit-$d')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-hit-t1')), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    await searchFor(tester, 'không có');
    expect(find.byKey(const Key('doc-no-results')), findsOneWidget);
    await searchFor(tester, 'nước');
    await tester.tap(find.byKey(ValueKey('doc-hit-$d')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentPage), findsOneWidget);
    // Back from the hit: the search with its results is still there.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('doc-hit-$d')), findsOneWidget);
    await tapKey(tester, 'search-clear');
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-tree')), findsOneWidget);
  });

  testWidgets('§4: [[ offers documents and links one; a link shows the current title; backlinks with the sentence',
      (tester) async {
    final w = world();
    final plan = w.documents.put('Kế hoạch');
    final from = w.documents.put('Nhật ký', body: DocumentBody([
      DocBlock('b1', BlockType.paragraph, runs: [TextRun('Đọc '), TextRun('Kế hoạch cũ', doc: plan), TextRun(' trước.')]),
    ]));
    final notes = w.documents.put('Ghi chú');
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tester.tap(find.byKey(ValueKey('doc-$from')));
    await tester.pumpAndSettle();
    final c = pageState(tester).controller!;
    expect(c.document.toPlainText(), contains('Đọc Kế hoạch trước.'), reason: 'the current title, not the stored text');

    typeAtEnd(tester, ' [[');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-link-picker')), findsOneWidget);
    expect(find.byKey(ValueKey('doc-link-pick-$from')), findsNothing, reason: 'never itself');
    await tester.enterText(find.byKey(const Key('doc-link-search')), 'ghi');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('doc-link-pick-$notes')));
    await tester.pumpAndSettle();
    expect(c.document.toPlainText(), contains('trước. Ghi chú'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    final runs = w.documents.docs[from]!.body.blocks.first.runs;
    expect([for (final r in runs) (r.text, r.doc)], [('Đọc ', null), ('Kế hoạch', plan), (' trước. ', null), ('Ghi chú', notes)]);

    // "Create …" from the picker makes the document and links it.
    await tester.tap(find.byKey(ValueKey('doc-$from')));
    await tester.pumpAndSettle();
    final again = pageState(tester).controller!;
    again.updateSelection(TextSelection.collapsed(offset: again.document.length - 1), q.ChangeSource.local);
    typeAtEnd(tester, ' ');
    await tapKey(tester, 'doc-tool-link');
    await tester.enterText(find.byKey(const Key('doc-link-search')), 'Sách hay');
    await tester.pumpAndSettle();
    await tapKey(tester, 'doc-link-create');
    expect(w.calls, contains('doc.create:Sách hay:null'));
    expect(pageState(tester).controller!.document.toPlainText(), contains('Sách hay'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('doc-$plan')));
    await tester.pumpAndSettle();
    await docMenu(tester, 'doc-links');
    expect(find.byKey(ValueKey('backlink-$from')), findsOneWidget);
    expect(find.text('Đọc Kế hoạch trước.'), findsOneWidget, reason: 'the sentence around the link');
  });

  testWidgets('linked tasks and goals: link from the menu, shown with their state, opened, unlinked', (tester) async {
    final w = world();
    final d = w.documents.put('Kế hoạch');
    w.documents.itemTitles['t1'] = 'Nấu phở bò';
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tester.tap(find.byKey(ValueKey('doc-$d')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'doc-page-menu');
    await tester.tap(find.text('Link to a task or goal…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('doc-item-search')), 'phở');
    await tester.pumpAndSettle();
    await tapKey(tester, 'doc-item-task-t1');
    expect(w.calls, contains('doc.link:$d:task:t1'));
    await docMenu(tester, 'doc-links');
    expect(find.byKey(const ValueKey('linked-task-t1')), findsOneWidget);
    expect(find.text('Nấu phở bò'), findsOneWidget);
    await tapKey(tester, 'unlink-task-t1');
    expect(w.calls, contains('doc.unlink:$d:task:t1'));
  });

  testWidgets('C5/C9: the history newest first; a version opens and is restored as a new one', (tester) async {
    final w = world();
    final d = w.documents.put('Thơ');
    await w.documents.save(d, title: 'Thơ', body: FakeDocuments.text('Câu một'));
    await w.documents.save(d, title: 'Thơ', body: FakeDocuments.text('Câu hai'));
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tester.tap(find.byKey(ValueKey('doc-$d')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'doc-page-menu');
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    final versions = [for (final t in tester.widgetList<Text>(find.textContaining('Version '))) t.data];
    expect(versions, ['Version 3', 'Version 2', 'Version 1']);
    await tapKey(tester, 'revision-$d-r2');
    expect(find.textContaining('Câu một', findRichText: true), findsOneWidget);
    await tapKey(tester, 'revision-restore');
    expect(w.calls, contains('doc.restoreRevision:$d:$d-r2'));
    expect(pageState(tester).controller!.document.toPlainText(), contains('Câu một'), reason: 'opened again');
  });

  testWidgets('C3: a file attached is kept and shown; a file from elsewhere says so; a copy can be saved', (tester) async {
    final w = world();
    final elsewhere = AttachmentRef(hash: 'sha256:${'b' * 64}', name: 'biên bản.pdf', size: 2048, mime: 'application/pdf');
    final d = w.documents.put('Họp', body: DocumentBody([
      DocBlock('a', BlockType.paragraph, runs: [TextRun('Xem tệp')]),
      DocBlock('f', BlockType.attachment, attachment: elsewhere),
    ]));
    w.pickFileResult = PickedFile(name: 'ghi chú.txt', mime: 'text/plain', bytes: Uint8List.fromList([1, 2, 3]));
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tester.tap(find.byKey(ValueKey('doc-$d')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('doc-file-elsewhere-${elsewhere.hash}')), findsOneWidget);
    expect(find.text('On another device · biên bản.pdf · 2 KB'), findsOneWidget);

    pageState(tester).controller!.updateSelection(const TextSelection.collapsed(offset: 7), q.ChangeSource.local);
    await tapKey(tester, 'doc-tool-attach');
    expect(w.calls, containsAllInOrder(['pickFile', 'file.add:ghi chú.txt']));
    expect(find.text('ghi chú.txt · 3 B'), findsOneWidget);
    final hash = w.documents.files.keys.single;
    await tapKey(tester, 'doc-file-save-$hash');
    expect(w.savedFiles['ghi chú.txt'], [1, 2, 3]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final saved = w.documents.docs[d]!.body;
    expect([for (final b in saved.blocks) b.attachment?.name].whereType<String>(), containsAll(['biên bản.pdf', 'ghi chú.txt']));
  });

  testWidgets('B4: a viewer reads only: no new document, no toolbar, "View only"', (tester) async {
    final w = world();
    final d = w.documents.put('Quy tắc nhà', body: FakeDocuments.text('Rửa bát sau bữa tối'));
    final s = FakeSpaces(spaces: [const SpaceView(id: 'personal', shared: false, isShown: false), SpaceView(
        id: family.id, shared: true, isShown: true, name: family.name, role: SpaceRole.viewer, members: family.members)]);
    await pumpApp(tester, w, spaces: s);
    await openDocuments(tester);
    expect(find.byTooltip('New document'), findsNothing);
    expect(find.byKey(ValueKey('doc-menu-$d')), findsNothing);
    await tester.tap(find.byKey(ValueKey('doc-$d')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-toolbar')), findsNothing);
    expect(docStatus(tester), 'View only');
    expect(find.byKey(const Key('doc-title-edit')), findsNothing, reason: 'the title cannot be opened for editing');
    expect(pageState(tester).controller!.readOnly, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(saves(w), isEmpty);
  });

  testWidgets('in the trash: read only with Restore; unreadable: said, never edited over; gone: said', (tester) async {
    final w = world();
    final t = w.documents.put('Cũ', body: FakeDocuments.text('Ngày xưa'));
    w.documents.docs[t]!.trashed = true;
    final u = w.documents.put('Mới hơn');
    w.documents.docs[u]!.unreadable = true;
    await pumpApp(tester, w);
    await openDocuments(tester);
    await tapKey(tester, 'doc-open-trash');
    await tester.tap(find.byKey(ValueKey('doc-trashed-$t')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-in-trash')), findsOneWidget);
    expect(pageState(tester).controller!.readOnly, isTrue);
    await tapKey(tester, 'doc-restore');
    expect(w.calls, contains('doc.restore:$t'));
    expect(find.byKey(const Key('doc-in-trash')), findsNothing);
    expect(pageState(tester).controller!.readOnly, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('doc-$u')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-unreadable')), findsOneWidget);
    expect(pageState(tester).controller, isNull);
    expect(find.byKey(const Key('doc-toolbar')), findsNothing);
  });

  testWidgets('a task\'s page lists its documents; one opens', (tester) async {
    final w = world();
    final d = w.documents.put('Công thức phở');
    await w.documents.link(d, DocumentItemType.task, 't1');
    await pumpApp(tester, w);
    await openTaskPageFor(tester, 'Nấu phở bò');
    expect(find.byKey(ValueKey('item-doc-$d')), findsOneWidget);
    await tapKey(tester, 'item-doc-$d');
    expect(find.byType(DocumentPage), findsOneWidget);
  });
}

/// Opens a task's page from the Overview.
Future<void> openTaskPageFor(WidgetTester tester, String title) async {
  await goToTab(tester, 'Overview');
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}
