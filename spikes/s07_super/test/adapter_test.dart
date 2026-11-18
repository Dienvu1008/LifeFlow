import 'package:flutter_test/flutter_test.dart';
import 'package:s07_common/s07_common.dart';
import 'package:s07_super/adapter.dart';

void main() {
  test('blocks -> super_editor -> blocks is exact, ids kept', () {
    final a = encodeBlocks(sampleDocument());
    expect(encodeBlocks(toBlocks(documentOf(sampleDocument()))), a);
  });

  test('two links side by side stay two links', () {
    final b = [
      Block('x', BlockType.paragraph, spans: [Span('Họp', link: 'doc-hop'), Span('Đà Nẵng', link: 'doc-danang')])
    ];
    expect(encodeBlocks(toBlocks(documentOf(b))), encodeBlocks(b));
  });

  test('50 pages in and out', () {
    final big = bigDocument();
    final sw = Stopwatch()..start();
    final doc = documentOf(big);
    final back = toBlocks(doc);
    sw.stop();
    expect(encodeBlocks(back), encodeBlocks(big));
    // ignore: avoid_print
    print('super_editor 50 pages: blocks->doc->blocks ${sw.elapsedMilliseconds} ms');
  });
}
