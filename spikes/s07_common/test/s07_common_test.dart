import 'package:s07_common/s07_common.dart';
import 'package:test/test.dart';

void main() {
  test('the format round-trips exactly and is deterministic', () {
    final doc = sampleDocument();
    final a = encodeBlocks(doc);
    expect(encodeBlocks(decodeBlocks(a)), a);
    expect(encodeBlocks(sampleDocument()), a, reason: 'the same content, the same bytes');
  });

  test('runs of the same style merge; empty runs go', () {
    final b = Block('x', BlockType.paragraph, spans: [Span('Ghi '), Span(''), Span('chú'), Span(' họp', marks: {'bold'})]);
    expect(encodeBlocks([b]), '[{"id":"x","type":"paragraph","spans":[{"t":"Ghi chú"},{"t":" họp","m":["bold"]}]}]');
  });

  test('50 pages: size and speed', () {
    final big = bigDocument();
    final sw = Stopwatch()..start();
    final s = encodeBlocks(big);
    final back = decodeBlocks(s);
    sw.stop();
    expect(back.length, big.length);
    // ignore: avoid_print
    print('50 pages: ${big.length} blocks, ${s.length} chars, encode+decode ${sw.elapsedMilliseconds} ms');
  });
}
