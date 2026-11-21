// S-09 (throwaway): the probe's DOCX reader on a hand-made file shaped as
// Word writes it (styles, numbering, a table, a picture, a tracked change).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p05b_probe/main.dart';

Uint8List docx(String body, String styles) {
  const ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
  final a = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', '<?xml version="1.0"?><w:document $ns><w:body>$body</w:body></w:document>'))
    ..addFile(ArchiveFile.string('word/styles.xml', '<?xml version="1.0"?><w:styles $ns>$styles</w:styles>'));
  return ZipEncoder().encodeBytes(a);
}

String p(String text, {String? style, int? ilvl, String extra = ''}) => '<w:p><w:pPr>'
    '${style == null ? '' : '<w:pStyle w:val="$style"/>'}'
    '${ilvl == null ? '' : '<w:numPr><w:ilvl w:val="$ilvl"/><w:numId w:val="1"/></w:numPr>'}'
    '</w:pPr>$extra<w:r><w:t xml:space="preserve">${const HtmlEscape().convert(text)}</w:t></w:r></w:p>';

void main() {
  test('headings (English ids and a Vietnamese style with an outline level), lists, a table, a picture', () {
    final bytes = docx(
      [
        p('Ghi chú họp', style: 'Heading1'),
        p('Phần một', style: 'TiuChng2'),
        p('Đoạn văn bình thường.'),
        p('Mục một', ilvl: 0),
        p('Mục con', ilvl: 1),
        '<w:tbl><w:tr><w:tc>${p('Tên')}</w:tc><w:tc>${p('Ngày')}</w:tc></w:tr></w:tbl>',
        '<w:p><w:r><w:drawing/></w:r></w:p>',
        p('Có sửa', extra: '<w:ins><w:r><w:t>thêm</w:t></w:r></w:ins>'),
      ].join(),
      '<w:style w:styleId="Heading1"/><w:style w:styleId="TiuChng2"><w:pPr><w:outlineLvl w:val="1"/></w:pPr></w:style>',
    );
    final r = readDocx(bytes);
    expect([for (final b in r.blocks) '${b.kind}:${b.level}:${b.text}'], [
      'heading1:0:Ghi chú họp',
      'heading2:0:Phần một',
      'paragraph:0:Đoạn văn bình thường.',
      'list:0:Mục một',
      'list:1:Mục con',
      'table:0:Tên | Ngày',
      'picture:0:[picture]',
      'paragraph:0:thêmCó sửa', // the insert is first in this file; deleted text (w:delText) is never read
    ]);
    expect(r.lost, {'tracked changes': 1});
  });
}
