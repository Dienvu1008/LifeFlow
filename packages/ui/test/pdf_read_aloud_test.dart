// P05b T5 (ADR-0079; p05b-plan.md D4, D6, D7): a PDF read aloud from the
// page shown, with the fake PDF view and fake voices.
//   from      the page shown to the end; lines joined, so a sentence over
//             two lines is one
//   shown     the sentence read in the reader bar; the page turns with it,
//             only when the sentence changes
//   voice     by the PDF's language; speed and controls as for documents
//   scan      no text: said, nothing to read
//   leaving   stops; the background pauses
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/documents/pdf_page.dart';

import 'documents_flow_test.dart' show tapKey;
import 'fake_world.dart';
import 'pdf_flow_test.dart' show openDocWithPdf, openPdf, pageOf;

List<String> spoken(FakeWorld w) => [for (final c in w.calls) if (c.startsWith('tts.speak:')) c.substring('tts.speak:'.length)];
String sentence(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('tts-sentence'))).data!;
String position(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('tts-position'))).data!;

const pages = ['Hóa đơn tiền điện.', 'Biên bản họp\ntổ dân phố. Ký tên.', 'Hết.'];

void main() {
  testWidgets('D4: read from the page shown, lines joined; the sentence shown and the page turned with it',
      (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) {
      w.pdf.pages = pages;
      w.pdfPages['sha256:${'c' * 64}'] = 2;
    });
    await openPdf(tester);
    expect(pageOf(tester), 'Page 2 of 3');
    await tapKey(tester, 'pdf-read-aloud');
    expect(find.byKey(const Key('doc-reader')), findsOneWidget);
    expect(position(tester), 'Sentence 1 of 3', reason: 'from page 2: two sentences there, one on page 3');
    expect(tester.widget<Text>(find.byKey(const Key('tts-voice-name'))).data, 'Microsoft An');

    await tapKey(tester, 'tts-play');
    expect(spoken(w), ['Microsoft An:1.0:Biên bản họp tổ dân phố.']);
    expect(sentence(tester), 'Biên bản họp tổ dân phố.');
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(sentence(tester), 'Ký tên.');
    expect(pageOf(tester), 'Page 2 of 3');
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(spoken(w).last, 'Microsoft An:1.0:Hết.');
    expect(pageOf(tester), 'Page 3 of 3', reason: 'the page follows the reading');
    expect(w.calls, contains('pdf.page:3'));
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byKey(const Key('tts-play'))).tooltip, 'Read', reason: 'done');

    await tapKey(tester, 'pdf-read-aloud');
    expect(find.byKey(const Key('doc-reader')), findsNothing);
  });

  testWidgets('the person may look at another page while a sentence is read; the next sentence brings the page back',
      (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) => w.pdf.pages = ['Một. Hai.', 'Ba.']);
    await openPdf(tester);
    await tapKey(tester, 'pdf-read-aloud');
    await tapKey(tester, 'tts-play');
    w.pdf.controls!.scrollTo(2);
    await tester.pumpAndSettle();
    expect(pageOf(tester), 'Page 2 of 2', reason: 'not pulled back while the sentence is read');
    await tapKey(tester, 'tts-speed');
    await tapKey(tester, 'tts-speed-1.5');
    expect(spoken(w).last, 'Microsoft An:1.5:Một.', reason: 'the sentence starts over at the new speed');
    expect(pageOf(tester), 'Page 2 of 2', reason: 'still the same sentence: the page is left where the person looks'); 
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(spoken(w).last, 'Microsoft An:1.5:Hai.');
    expect(pageOf(tester), 'Page 1 of 2', reason: 'the next sentence is on page 1');
  });

  testWidgets('an English PDF gets an English voice; a scan has nothing to read', (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) => w.pdf.pages = ['Invoice for November.', 'Thank you.']);
    await openPdf(tester);
    await tapKey(tester, 'pdf-read-aloud');
    await tapKey(tester, 'tts-play');
    expect(spoken(w), ['Microsoft David:1.0:Invoice for November.']);
    await tapKey(tester, 'pdf-read-aloud');
    expect(w.tts.speaking, isNull, reason: 'closing stops it');

    w.pdf.pages = ['', '  '];
    w.pdf.controls!.scrollTo(1);
    await tapKey(tester, 'pdf-read-aloud');
    expect(find.text('There is no text to read in this document.'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('tts-play'))).onPressed, isNull);
  });

  testWidgets('D6: the background pauses the reading; leaving the page stops it', (tester) async {
    final (w, _) = await openDocWithPdf(tester, setUp: (w) => w.pdf.pages = pages);
    await openPdf(tester);
    await tapKey(tester, 'pdf-read-aloud');
    await tapKey(tester, 'tts-play');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(w.tts.speaking, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byKey(const Key('tts-play'))).tooltip, 'Read', reason: 'paused, not playing');
    await tapKey(tester, 'tts-play');
    expect(w.tts.speaking, 'Hóa đơn tiền điện.');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PdfPage), findsNothing);
    expect(w.tts.speaking, isNull, reason: 'stopped on leaving');
  });
}
