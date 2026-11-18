import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:flutter_test/flutter_test.dart';
import 'package:s07_common/s07_common.dart';
import 'package:s07_quill/adapter.dart';

void main() {
  List<String> idsOf(List<Block> b) => [for (final x in b) x.id];

  test('blocks -> Quill -> blocks is exact when the ids are given back by position', () {
    final s = sampleDocument();
    expect(encodeBlocks(toBlocks(documentOf(s).toDelta(), ids: idsOf(s))), encodeBlocks(s));
  });

  test('two links side by side stay two links', () {
    final b = [
      Block('x', BlockType.paragraph, spans: [Span('Họp', link: 'doc-hop'), Span('Đà Nẵng', link: 'doc-danang')])
    ];
    expect(encodeBlocks(toBlocks(documentOf(b).toDelta(), ids: idsOf(b))), encodeBlocks(b));
  });

  test('a line typed at the top shifts every id by position (Quill keeps none)', () {
    final s = sampleDocument();
    final c = QuillController(document: documentOf(s), selection: const TextSelection.collapsed(offset: 0));
    c.replaceText(0, 0, 'Dòng mới\n', null);
    final after = toBlocks(c.document.toDelta(), ids: idsOf(s));
    // The new line took the first id; the old first block now has the second.
    expect(after.first.text, 'Dòng mới');
    expect(after.first.id, s.first.id);
    expect(after[1].text, s.first.text);
    expect(after[1].id, isNot(s.first.id));
  });

  test('50 pages in and out', () {
    final big = bigDocument();
    final sw = Stopwatch()..start();
    final doc = documentOf(big);
    final back = toBlocks(doc.toDelta(), ids: idsOf(big));
    sw.stop();
    expect(encodeBlocks(back), encodeBlocks(big));
    // ignore: avoid_print
    print('flutter_quill 50 pages: blocks->doc->blocks ${sw.elapsedMilliseconds} ms');
  });
}
