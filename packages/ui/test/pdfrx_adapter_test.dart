// P05b T1 (ADR-0076): the pdfrx adapter with the real engine (PDFium) and a
// real PDF: it opens from bytes, counts its pages, finds text across pages,
// goes to a page, and says when a file is not a PDF.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:ui/src/documents/pdf_adapter.dart';
import 'package:ui/src/documents/pdf_view.dart';

import 'pdf_fixture.dart';

Future<T> waitFor<T>(WidgetTester tester, Future<T> f) async {
  T? result;
  var done = false;
  unawaited(f.then((v) {
    result = v;
    done = true;
  }));
  for (var i = 0; i < 200 && !done; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 25));
  }
  if (!done) fail('timed out');
  return result as T;
}

Future<void> settle(WidgetTester tester, bool Function() until) async {
  for (var i = 0; i < 200 && !until(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 25));
  }
}

void main() {
  // pdfrxFlutterInitialize needs path_provider, which tests do not have.
  setUpAll(() => pdfrxInitialize(tmpPath: Directory.systemTemp.path));

  Future<(Completer<PdfViewControls>, Completer<PdfOpenFailure>)> show(WidgetTester tester, List<int> bytes, {int page = 1}) async {
    final ready = Completer<PdfViewControls>();
    final failed = Completer<PdfOpenFailure>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => buildPdfrxView(
            context,
            PdfViewSetup(
              bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
              sourceName: 'test:${bytes.length}:$page',
              initialPage: page,
              password: ({required wrong}) async => null,
              onReady: ready.complete,
              onFailed: failed.complete,
            ),
          ),
        ),
      ),
    ));
    return (ready, failed);
  }

  testWidgets('a real PDF opens from bytes: pages, find across pages, go to a page', (tester) async {
    final (ready, _) = await show(tester, pdfWithPages(['Invoice 1 of March', 'Nothing here', 'Invoice 2 and invoice 3']));
    final c = await waitFor(tester, ready.future);
    expect(c.pageCount, 3);
    expect(c.pageNumber, 1);
    expect(c.copyAllowed, isTrue);
    expect(c.hasSelection, isFalse);
    expect(await waitFor(tester, c.selectedText()), isNull);

    c.find('invoice');
    await settle(tester, () => !c.isFinding && c.matchCount == 3);
    expect(c.matchCount, 3, reason: 'ignoring case, on pages 1 and 3');
    expect(c.matchIndex, 0);
    await waitFor(tester, c.nextMatch());
    expect(c.matchIndex, 1);
    c.find('');
    await settle(tester, () => c.matchCount == 0);
    expect(c.matchCount, 0);

    await waitFor(tester, c.goToPage(3));
    await settle(tester, () => c.pageNumber == 3);
    expect(c.pageNumber, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('it opens at the page asked for', (tester) async {
    final (ready, _) = await show(tester, pdfWithPages(['one', 'two', 'three']), page: 2);
    final c = await waitFor(tester, ready.future);
    await settle(tester, () => c.pageNumber == 2);
    expect(c.pageNumber, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a file that is not a PDF is reported unreadable', (tester) async {
    final (_, failed) = await show(tester, 'not a pdf at all'.codeUnits);
    expect(await waitFor(tester, failed.future), PdfOpenFailure.unreadable);
    await tester.pumpWidget(const SizedBox());
  });
}
