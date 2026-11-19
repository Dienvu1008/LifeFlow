// P05a T8 (ADR-0073): LifeFlow's block format to and from flutter_quill.
import 'dart:convert';

import 'package:application/application.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/documents/quill_adapter.dart';

void main() {
  final file = AttachmentRef(hash: 'sha256:${'a' * 64}', name: 'bảng trắng.png', size: 1234, mime: 'image/png');
  DocumentBody rich() => DocumentBody([
        DocBlock('h1', BlockType.heading1, runs: [TextRun('Ghi chú họp')]),
        DocBlock('h2', BlockType.heading2, runs: [TextRun('Phần 1')]),
        DocBlock('h3', BlockType.heading3, runs: [TextRun('Chi tiết')]),
        DocBlock('p', BlockType.paragraph, runs: [
          TextRun('Xem '),
          TextRun('Kế hoạch', doc: 'doc-1', marks: {TextMark.bold}),
          TextRun(' và '),
          TextRun('trang web', url: 'https://lifeflow.vn'),
          TextRun(', '),
          TextRun('đậm nghiêng', marks: {TextMark.bold, TextMark.italic}),
          TextRun(' '),
          TextRun('gạch', marks: {TextMark.underline, TextMark.strike}),
          TextRun(' '),
          TextRun('mã', marks: {TextMark.code}),
        ]),
        DocBlock('b1', BlockType.bullet, runs: [TextRun('Một')]),
        DocBlock('b2', BlockType.bullet, indent: 2, runs: [TextRun('Hai, thụt vào')]),
        DocBlock('n', BlockType.numbered, runs: [TextRun('Số')]),
        DocBlock('t1', BlockType.todo, checked: true, runs: [TextRun('Đã xong')]),
        DocBlock('t2', BlockType.todo, indent: 1, runs: [TextRun('Chưa')]),
        DocBlock('q', BlockType.quote, runs: [TextRun('Trích dẫn')]),
        DocBlock('c', BlockType.code, runs: [TextRun('final x = 1;')]),
        DocBlock('f', BlockType.attachment, attachment: file),
        DocBlock('e', BlockType.paragraph),
      ]);

  test('every block type, mark and link survives the editor and back, with its ids', () {
    final body = rich();
    final back = bodyOf(deltaOf(body), ids: blockIdsOf(body));
    expect(back.encode(), body.encode());
    expect(back.validate(), isNull);
  });

  test('through a Quill document too (as the editor holds it)', () {
    final body = rich();
    final back = bodyOf(quillDocumentOf(body).toDelta(), ids: blockIdsOf(body));
    expect(back.encode(), body.encode());
  });

  test('ids by line: a new line gets a new id; an empty editor is one empty paragraph', () {
    final body = DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('A')])]);
    final d = Delta()
      ..insert('A\n')
      ..insert('B\n');
    final back = bodyOf(d, ids: blockIdsOf(body));
    expect(back.blocks.first.id, 'a');
    expect(back.blocks.last.id, isNot('a'));
    expect(back.blocks.last.id, matches(RegExp(r'^[0-9a-f]{16}$')));
    final empty = bodyOf(Delta()..insert('\n'), ids: const ['x']);
    expect([for (final b in empty.blocks) (b.id, b.type, b.text)], [('x', BlockType.paragraph, '')]);
    expect(bodyOf(Delta(), ids: const []).blocks, hasLength(1));
    expect(deltaOf(DocumentBody([])).toList().single.data, '\n');
  });

  test('a file put on a line with text: the text stays, as a block before or after it', () {
    for (final at in [0, 3, 1]) {
      final c = q.QuillController.basic();
      c.replaceText(0, 0, 'abc', const TextSelection.collapsed(offset: 3));
      c.replaceText(at, 0, q.BlockEmbed(attachmentEmbedType, jsonEncode(file.toJson())), null);
      final body = bodyOf(c.document.toDelta());
      expect(body.validate(), isNull);
      expect([for (final b in body.blocks) if (b.type != BlockType.attachment) b.text].join(), 'abc', reason: 'at $at');
      expect(body.blocks.where((b) => b.type == BlockType.attachment), hasLength(1), reason: 'at $at');
    }
  });

  test('what LifeFlow cannot keep is dropped, never stored half-read', () {
    final d = Delta()
      ..insert('lạ', {'link': 'javascript:alert(1)', 'color': '#ff0000', 'size': 'large'})
      ..insert('\n', {'align': 'center', 'indent': 3})
      ..insert({'image': 'https://example.com/a.png'})
      ..insert('\n')
      ..insert({attachmentEmbedType: 'not json'})
      ..insert('\n')
      ..insert('x', {'link': docLinkScheme})
      ..insert('\n', {'list': 'bullet', 'indent': 9});
    final body = bodyOf(d);
    expect(body.validate(), isNull);
    expect([for (final b in body.blocks) (b.type, b.text, b.indent)], [
      (BlockType.paragraph, 'lạ', 0),
      (BlockType.bullet, 'x', maxBlockIndent),
    ]);
    expect([for (final r in body.blocks.first.runs) (r.doc, r.url, r.marks.length)], [(null, null, 0)]);
    expect(body.blocks.last.runs.single.doc, isNull, reason: 'a link without an id is no link');
    expect(attachmentOfEmbed('{"hash":"h","name":"n","size":1,"mime":"m"}')?.name, 'n');
    expect(attachmentOfEmbed(3), isNull);
  });
}
