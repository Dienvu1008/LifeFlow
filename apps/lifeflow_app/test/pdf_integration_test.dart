// P05b T1 (ADR-0076; LF-INV-FILE-001 proposed, GS-29 in part): a PDF
// attached in the real UI is kept encrypted, opens in the PDF page with the
// real engine (PDFium), and no clear copy of it is written anywhere: not in
// the app's folder, not in the engine's cache folder. The page shown is
// remembered on this device (D9).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:lifeflow_app/bootstrap.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:ui/src/documents/document_page.dart' show DocumentPage, DocumentPageState;
import 'package:ui/src/documents/pdf_page.dart' show PdfPage;

import 'app_integration_test.dart' show World, finish, pumpApp, settle;

class _NoHost implements ProfileHost {
  @override
  Future<void> activate(String profileId, {bool showProfiles = false}) async {}
}

/// A real two-page PDF; [secret] is on page 2, in the clear inside the file.
/// The pages are tall, so one page fills the view (the page shown is clear).
Uint8List pdfWith(String secret) {
  final out = BytesBuilder();
  final offsets = <int>[];
  void raw(String s) => out.add(latin1.encode(s));
  void obj(String body) {
    offsets.add(out.length);
    raw('${offsets.length} 0 obj\n$body\nendobj\n');
  }

  raw('%PDF-1.4\n');
  obj('<< /Type /Catalog /Pages 2 0 R >>');
  obj('<< /Type /Pages /Kids [4 0 R 6 0 R] /Count 2 >>');
  obj('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  for (final text in ['Invoice', secret]) {
    obj('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 800] /Resources << /Font << /F1 3 0 R >> >> /Contents ${offsets.length + 2} 0 R >>');
    final s = 'BT /F1 18 Tf 20 100 Td ($text) Tj ET';
    obj('<< /Length ${s.length} >>\nstream\n$s\nendstream');
  }
  final xref = out.length;
  raw('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    raw('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  raw('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return out.toBytes();
}

/// Files under [dir] whose bytes contain [marker].
List<String> filesContaining(Directory dir, List<int> marker) {
  if (!dir.existsSync()) return const [];
  bool contains(List<int> b) {
    outer:
    for (var i = 0; i + marker.length <= b.length; i++) {
      for (var j = 0; j < marker.length; j++) {
        if (b[i + j] != marker[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  return [
    for (final f in dir.listSync(recursive: true).whereType<File>())
      if (contains(f.readAsBytesSync())) f.path,
  ];
}

Future<void> until(WidgetTester tester, bool Function() done, {int rounds = 200}) async {
  for (var i = 0; i < rounds && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 25));
  }
}

/// Back from the page on top, once no page transition runs.
Future<void> back(WidgetTester tester) async {
  await until(tester, () => find.byTooltip('Back').evaluate().length == 1);
  await tester.pageBack();
  await tester.pump();
  await until(tester, () => find.byType(PdfPage).evaluate().isEmpty);
  await settle(tester);
}

void main() {
  late Directory engineCache;
  setUpAll(() async {
    engineCache = await Directory.systemTemp.createTemp('lifeflow_pdfrx_');
    await pdfrxInitialize(tmpPath: engineCache.path);
  });
  tearDownAll(() => engineCache.delete(recursive: true));

  test('P05b T2: a PDF kept but not read yet (a restore, an older build) is read when the session opens', () async {
    final w = World();
    await w.open(StoragePlatform.windows);
    addTearDown(w.dispose);
    final id = (await w.directory.active())!.id;
    Future<AppWiring> open() => openSession(
        directory: w.directory, profileId: id, platform: StoragePlatform.windows, auth: w.auth, host: _NoHost(), files: w.files);
    final first = await open();
    final kept = DriftAttachmentService(first.db, folder: w.directory.attachmentsDir(id), keys: w.directory.attachmentKeys(id));
    final f = (await kept.add(pdfWith('LifeFlowOlderPdf'), name: 'cũ.pdf', mime: 'application/pdf')).ref!;
    final gw = DriftCommandGateway(first.db, WorkspaceOwnerAuthorization(first.db));
    final docs = DriftDocumentService(first.db, gw, deviceId: 'windows');
    final doc = (await docs.create('Cũ') as CommandOk).entityId;
    await docs.save(doc, title: 'Cũ', body: DocumentBody([DocBlock('f', BlockType.attachment, attachment: f)]));
    expect((await DriftSearchQueries(first.db).search('lifeflowolder')).files, isEmpty, reason: 'not read yet');
    await first.close();

    final again = await open();
    addTearDown(again.close);
    await again.background!();
    final hits = (await DriftSearchQueries(again.db).search('lifeflowolder')).files;
    expect([for (final h in hits) (h.documentTitle, h.file.name, h.page)], [('Cũ', 'cũ.pdf', 2)]);
  });

  testWidgets('a PDF attached in the UI opens in the app; no clear copy is written; its page is remembered',
      (tester) async {
    const secret = 'LifeFlowSecretPage';
    final bytes = pdfWith(secret);
    final w = await pumpApp(tester, StoragePlatform.windows);
    w.files.nextFile = PickedFile(name: 'hóa đơn.pdf', mime: 'application/pdf', bytes: bytes);
    await tester.tap(find.text('Documents'));
    await settle(tester);
    await tester.tap(find.byTooltip('New document'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hóa đơn tháng 11');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    final page = tester.state<DocumentPageState>(find.byType(DocumentPage));
    page.controller!.replaceText(0, 0, 'Xem tệp', const TextSelection.collapsed(offset: 7));
    await tester.tap(find.byKey(const Key('doc-tool-attach')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();

    // The file's tile checks the file is here (real I/O).
    await until(tester, () => find.textContaining('hóa đơn.pdf').evaluate().isNotEmpty, rounds: 40);
    final open = find.byWidgetPredicate((x) => x.key is ValueKey<String> && (x.key! as ValueKey<String>).value.startsWith('doc-file-open-'));
    expect(open, findsOneWidget);
    final hash = (tester.widget(open).key! as ValueKey<String>).value.substring('doc-file-open-'.length);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pump();
    await until(tester, () => find.byKey(const Key('pdf-page-of')).evaluate().isNotEmpty);
    expect(find.byType(PdfPage), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('pdf-page-of'))).data, 'Page 1 of 2');

    // Find runs on the real text of the PDF.
    await tester.tap(find.byKey(const Key('pdf-find')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('pdf-find-field')), 'secretpage');
    await until(tester, () => tester.widget<Text>(find.byKey(const Key('pdf-find-status'))).data == '1 of 1');
    expect(tester.widget<Text>(find.byKey(const Key('pdf-find-status'))).data, '1 of 1');
    await until(tester, () => tester.widget<Text>(find.byKey(const Key('pdf-page-of'))).data == 'Page 2 of 2');
    expect(tester.widget<Text>(find.byKey(const Key('pdf-page-of'))).data, 'Page 2 of 2', reason: 'the match is on page 2');

    // LF-INV-FILE-001: shown from memory; nothing in the clear on disk.
    final marker = utf8.encode(secret);
    final leaks = await tester.runAsync(() async => [...filesContaining(w.base, marker), ...filesContaining(engineCache, marker)]);
    expect(leaks, isEmpty);

    await back(tester);
    // Saved on leaving, without waiting for it (real I/O): poll.
    int? remembered;
    for (var i = 0; i < 80 && remembered != 2; i++) {
      remembered = await tester.runAsync<int?>(() => DirectorySettingsService(w.directory).lastPdfPage(hash));
      await settle(tester, 1);
    }
    expect(remembered, 2, reason: 'D9: a device setting');
    await tester.tap(open);
    await tester.pump();
    await until(tester, () => find.text('Page 2 of 2').evaluate().isNotEmpty);
    expect(find.text('Page 2 of 2'), findsOneWidget, reason: 'it opens where it was left');
    await back(tester);

    // P05b T2 (ADR-0077, D3): the PDF's words are found by the one search,
    // "in file.pdf, page 2"; the hit opens at its page.
    await back(tester); // to the documents
    await tester.enterText(find.byKey(const Key('doc-search')), 'lifeflowsecret');
    await tester.pump(const Duration(milliseconds: 400));
    await until(tester, () => find.text('hóa đơn.pdf, page 2').evaluate().isNotEmpty);
    expect(find.text('In PDF files'), findsOneWidget);
    expect(find.text('hóa đơn.pdf, page 2'), findsOneWidget);
    await tester.tap(find.text('hóa đơn.pdf, page 2'));
    await tester.pump();
    await until(tester, () => find.text('Page 2 of 2').evaluate().isNotEmpty && find.text('1 match').evaluate().isNotEmpty);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('1 match'), findsOneWidget, reason: 'the words searched, highlighted');
    // The text index is in the encrypted store: not in the clear either.
    final leaks2 = await tester.runAsync(() async => [
          ...filesContaining(w.base, marker),
          ...filesContaining(w.base, utf8.encode(secret.toLowerCase())),
        ]);
    expect(leaks2, isEmpty);
    await back(tester);
    await finish(tester, w);
  });
}
