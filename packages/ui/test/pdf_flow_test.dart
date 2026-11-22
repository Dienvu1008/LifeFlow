// P05b T1 (ADR-0076; p05b-plan.md D8, D9): a PDF kept in a document opens
// in the app, with the fake PDF view.
//   D8      the file in the document opens the PDF page; other files do not
//   bytes   the view gets the file's bytes from AttachmentService.open
//   pages   page of, previous and next, zoom
//   D9      it opens at the page last shown on this device; the page is
//           remembered a moment after it changes, and on leaving
//   find    matches counted, next and previous, none; closing clears them
//   copy    the selected text, unless the PDF forbids copying
//   password asked again after a wrong one; giving up says so, and Try again
//   damaged said
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/documents/pdf_page.dart';

import 'documents_flow_test.dart' show openDocuments, pumpApp, tapKey, world;
import 'fake_world.dart';

final pdfBytes = Uint8List.fromList('%PDF-1.7 fake'.codeUnits);
final pdfFile = AttachmentRef(hash: 'sha256:${'c' * 64}', name: 'hóa đơn.pdf', size: pdfBytes.length, mime: 'application/pdf');
final txtFile = AttachmentRef(hash: 'sha256:${'d' * 64}', name: 'ghi chú.txt', size: 3, mime: 'text/plain');

/// A document with [pdfFile] (and [txtFile]) on this device, its page open.
Future<(FakeWorld, String)> openDocWithPdf(WidgetTester tester, {void Function(FakeWorld w)? setUp}) async {
  final w = world();
  w.documents.files[pdfFile.hash] = pdfBytes;
  w.documents.files[txtFile.hash] = Uint8List.fromList([1, 2, 3]);
  final d = w.documents.put('Hóa đơn', body: DocumentBody([
    DocBlock('a', BlockType.paragraph, runs: [TextRun('Tệp')]),
    DocBlock('f', BlockType.attachment, attachment: pdfFile),
    DocBlock('g', BlockType.attachment, attachment: txtFile),
  ]));
  setUp?.call(w);
  await pumpApp(tester, w);
  await openDocuments(tester);
  await tester.tap(find.byKey(ValueKey('doc-$d')));
  await tester.pumpAndSettle();
  return (w, d);
}

Future<void> openPdf(WidgetTester tester) => tapKey(tester, 'doc-file-open-${pdfFile.hash}');

String pageOf(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('pdf-page-of'))).data!;
String findStatus(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('pdf-find-status'))).data!;
bool enabled(WidgetTester tester, String key) => tester.widget<IconButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  testWidgets('D8: a PDF in a document opens in the app from its bytes; pages and zoom', (tester) async {
    final (w, _) = await openDocWithPdf(tester);
    expect(find.byKey(ValueKey('doc-file-open-${txtFile.hash}')), findsNothing, reason: 'only a PDF opens');
    await openPdf(tester);
    expect(find.byType(PdfPage), findsOneWidget);
    expect(find.text('hóa đơn.pdf'), findsOneWidget);
    expect(w.pdf.shown.single, same(pdfBytes), reason: 'the bytes AttachmentService.open gave, in memory');
    expect(w.calls, contains('pdf.open:lifeflow:${pdfFile.hash}#0:1'));
    expect(pageOf(tester), 'Page 1 of 3');
    expect(find.text('page 1: Trang một'), findsOneWidget);
    expect(enabled(tester, 'pdf-page-previous'), isFalse);
    await tapKey(tester, 'pdf-page-next');
    expect(pageOf(tester), 'Page 2 of 3');
    await tapKey(tester, 'pdf-page-next');
    expect(enabled(tester, 'pdf-page-next'), isFalse);
    await tapKey(tester, 'pdf-page-previous');
    expect(pageOf(tester), 'Page 2 of 3');
    await tapKey(tester, 'pdf-zoom-in');
    await tapKey(tester, 'pdf-zoom-out');
    expect(w.calls, containsAllInOrder(['pdf.page:2', 'pdf.page:3', 'pdf.page:2', 'pdf.zoomIn', 'pdf.zoomOut']));
  });

  testWidgets('D9: it opens at the last page; a page is remembered after a moment and on leaving', (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) => w.pdfPages[pdfFile.hash] = 3);
    await openPdf(tester);
    expect(w.calls, contains('pdf.open:lifeflow:${pdfFile.hash}#0:3'));
    expect(pageOf(tester), 'Page 3 of 3');
    w.pdf.controls!.scrollTo(2);
    await tester.pump(const Duration(milliseconds: 500));
    expect(w.pdfPages[pdfFile.hash], 3, reason: 'not yet: the page may still change');
    await tester.pump(pdfPageSaveDelay);
    expect(w.pdfPages[pdfFile.hash], 2);
    w.pdf.controls!.scrollTo(1);
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(w.pdfPages[pdfFile.hash], 1, reason: 'leaving remembers it');
  });

  testWidgets('find: matches counted, next and previous go to their page; none; closing clears', (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) => w.pdf.pages = ['Hóa đơn số 1', 'Không có', 'Hóa đơn số 2, hóa đơn số 3']);
    await openPdf(tester);
    await tapKey(tester, 'pdf-find');
    await tester.enterText(find.byKey(const Key('pdf-find-field')), 'hóa đơn');
    await tester.pumpAndSettle();
    expect(findStatus(tester), '1 of 3');
    expect(pageOf(tester), 'Page 1 of 3');
    await tapKey(tester, 'pdf-find-next');
    expect(findStatus(tester), '2 of 3');
    expect(pageOf(tester), 'Page 3 of 3');
    await tapKey(tester, 'pdf-find-previous');
    await tapKey(tester, 'pdf-find-previous');
    expect(findStatus(tester), '3 of 3', reason: 'previous from the first goes round to the last');
    await tester.enterText(find.byKey(const Key('pdf-find-field')), 'phở');
    await tester.pumpAndSettle();
    expect(findStatus(tester), 'No matches');
    expect(enabled(tester, 'pdf-find-next'), isFalse);
    await tapKey(tester, 'pdf-find-close');
    expect(find.byKey(const Key('pdf-find-field')), findsNothing);
    expect(w.calls.last, 'pdf.find:');
  });

  testWidgets('find opens with Ctrl+F and closes with Escape', (tester) async {
    await openDocWithPdf(tester);
    await openPdf(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdf-find-field')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdf-find-field')), findsNothing);
  });

  testWidgets('copy: the selected text goes to the clipboard; a PDF that forbids copying says so', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final (w, _) = await openDocWithPdf(tester);
    await openPdf(tester);
    expect(find.byKey(const Key('pdf-copy')), findsNothing, reason: 'nothing selected');
    w.pdf.controls!.select('Trang một');
    await tester.pumpAndSettle();
    await tapKey(tester, 'pdf-copy');
    expect(copied, ['Trang một']);
    expect(find.text('Copied the selected text.'), findsOneWidget);

    w.pdf.copyAllowed = false;
    await tapKey(tester, 'pdf-copy');
    expect(copied, hasLength(1));
    expect(find.text('This PDF does not allow copying its text.'), findsOneWidget);
  });

  testWidgets('password: asked again after a wrong one, then it opens', (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) => w.pdf.password = 'bí mật');
    await openPdf(tester);
    expect(find.byKey(const Key('pdf-password')), findsOneWidget);
    expect(find.text('“hóa đơn.pdf” is protected by a password.'), findsOneWidget);
    expect(find.byKey(const Key('pdf-password-wrong')), findsNothing);
    await tester.enterText(find.byKey(const Key('pdf-password-field')), 'sai');
    await tapKey(tester, 'pdf-password-open');
    expect(find.byKey(const Key('pdf-password-wrong')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pdf-password-field')), 'bí mật');
    await tapKey(tester, 'pdf-password-open');
    expect(find.byKey(const Key('pdf-password')), findsNothing);
    expect(pageOf(tester), 'Page 1 of 3');
    expect(w.pdf.controls, isNotNull);
  });

  testWidgets('password: giving up says so; Try again asks again, as a new source for the engine', (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) => w.pdf.password = 'bí mật');
    await openPdf(tester);
    await tapKey(tester, 'pdf-password-cancel');
    expect(find.text('This PDF opens only with its password.'), findsOneWidget);
    expect(find.byKey(const Key('pdf-find')), findsNothing);
    await tapKey(tester, 'pdf-try-again');
    expect(find.byKey(const Key('pdf-password')), findsOneWidget);
    // pdfrx shares a loaded document by its source name: a new try must not
    // get the one that failed.
    expect([for (final c in w.calls) if (c.startsWith('pdf.open:')) c],
        ['pdf.open:lifeflow:${pdfFile.hash}#0:1', 'pdf.open:lifeflow:${pdfFile.hash}#1:1']);
    await tester.enterText(find.byKey(const Key('pdf-password-field')), 'bí mật');
    await tapKey(tester, 'pdf-password-open');
    expect(pageOf(tester), 'Page 1 of 3');
  });

  testWidgets('a damaged PDF says it cannot be opened', (tester) async {
    await openDocWithPdf(tester, setUp: (w) => w.pdf.damaged = true);
    await openPdf(tester);
    expect(find.text('This PDF cannot be opened. It may be damaged.'), findsOneWidget);
    expect(find.byKey(const Key('pdf-page-of')), findsNothing);
  });

  testWidgets('a PDF whose file is gone from this device since the document showed it says so', (tester) async {
    final (w, _) = await openDocWithPdf(tester);
    w.documents.files.remove(pdfFile.hash);
    await openPdf(tester);
    expect(find.byKey(const Key('pdf-not-here')), findsOneWidget);
    expect(w.pdf.shown, isEmpty);
  });

  test('fileViewOf: pictures, PDFs by type or by name when the type is generic, the rest not shown', () {
    AttachmentRef f(String name, String mime) => AttachmentRef(hash: 'sha256:${'e' * 64}', name: name, size: 1, mime: mime);
    expect(fileViewOf(f('a.png', 'image/png')), FileView.picture);
    expect(fileViewOf(f('a.pdf', 'application/pdf')), FileView.pdf);
    expect(fileViewOf(f('A.PDF', 'application/octet-stream')), FileView.pdf);
    expect(fileViewOf(f('a.pdf', 'text/plain')), FileView.none, reason: 'a given type wins over the name');
    expect(fileViewOf(f('a.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')), FileView.none);
    expect(fileViewOf(f('a.bin', 'application/octet-stream')), FileView.none);
  });
}
