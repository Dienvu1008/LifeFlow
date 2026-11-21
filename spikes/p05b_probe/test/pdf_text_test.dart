// S-08 (throwaway): does PDFium give Vietnamese text back with its marks,
// from a PDF opened in memory? And how fast on many pages?
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;

const line = 'Ghi chú họp ở Đà Nẵng: thứ Hai lúc chín giờ, mang theo kế hoạch tuần.';

void main() {
  setUpAll(() => pdfrxInitialize(tmpPath: Directory.systemTemp.path));

  test('Vietnamese text comes back from a PDF opened from bytes; 300 pages timed', () async {
    final font = pw.Font.ttf(File('test/vi.ttf').readAsBytesSync().buffer.asByteData());
    final doc = pw.Document();
    for (var i = 1; i <= 300; i++) {
      doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Column(children: [
                pw.Text('Trang $i', style: pw.TextStyle(font: font, fontSize: 18)),
                for (var k = 0; k < 20; k++) pw.Text(line, style: pw.TextStyle(font: font, fontSize: 11)),
              ])));
    }
    final bytes = await doc.save();
    final sw = Stopwatch()..start();
    final opened = await PdfDocument.openData(bytes, sourceName: 'probe.pdf');
    final openMs = sw.elapsedMilliseconds;
    final first = (await opened.pages.first.loadText())!.fullText;
    var chars = 0 as int;
    for (final p in opened.pages) {
      chars = chars + ((await p.loadText())?.fullText.length ?? 0);
    }
    sw.stop();
    // ignore: avoid_print
    print('PROBE size=${(bytes.length / 1024).round()} KB pages=${opened.pages.length} open=${openMs} ms '
        'allText=${sw.elapsedMilliseconds} ms chars=$chars');
    // ignore: avoid_print
    print('PROBE first="${first.substring(0, 90).replaceAll('\n', ' ⏎ ')}"');
    // ignore: avoid_print
    print('PROBE codeunits of "chú": ${first.substring(first.indexOf('ch'), first.indexOf('ch') + 4).codeUnits}');
    expect(first, contains('Đà Nẵng'));
    expect(first, contains('Ghi chú họp'));
    await opened.dispose();
  });
}
