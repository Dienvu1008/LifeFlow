/// S-07 (throwaway): LifeFlow's own block format, which every editor adapter
/// reads and writes. The stored format is ours, not the library's (p05-plan
/// §5, the editor port).
library;

import 'dart:convert';

enum BlockType { paragraph, heading1, heading2, bullet, numbered, todo, image }

/// A run of text with the same marks. [link] is a `[[…]]` link: the id of
/// the document it points to.
class Span {
  Span(this.text, {Set<String>? marks, this.link}) : marks = {...?marks};
  final String text;
  final Set<String> marks; // 'bold', 'italic'
  final String? link;

  bool sameStyle(Span o) => link == o.link && marks.length == o.marks.length && marks.containsAll(o.marks);

  Map<String, Object?> toJson() => {
        't': text,
        if (marks.isNotEmpty) 'm': (marks.toList()..sort()),
        if (link != null) 'l': link,
      };

  static Span fromJson(Map<String, Object?> j) =>
      Span(j['t'] as String, marks: {...((j['m'] as List?) ?? const []).cast<String>()}, link: j['l'] as String?);
}

class Block {
  Block(this.id, this.type, {List<Span>? spans, this.checked = false, this.image}) : spans = spans ?? [];
  final String id;
  final BlockType type;
  final List<Span> spans;
  final bool checked;
  final String? image; // an attachment's hash (P05a: kept on the device)

  String get text => spans.map((s) => s.text).join();

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        if (type == BlockType.image) 'image': image ?? '' else 'spans': [for (final s in normalize(spans)) s.toJson()],
        if (type == BlockType.todo) 'checked': checked,
      };

  static Block fromJson(Map<String, Object?> j) {
    final type = BlockType.values.byName(j['type'] as String);
    return Block(
      j['id'] as String,
      type,
      spans: [for (final s in (j['spans'] as List?) ?? const []) Span.fromJson((s as Map).cast())],
      checked: j['checked'] == true,
      image: j['image'] as String?,
    );
  }
}

/// Adjacent runs with the same style become one; empty runs go. Two
/// documents that look the same serialize the same.
List<Span> normalize(List<Span> spans) {
  final out = <Span>[];
  for (final s in spans) {
    if (s.text.isEmpty) continue;
    if (out.isNotEmpty && out.last.sameStyle(s)) {
      out[out.length - 1] = Span(out.last.text + s.text, marks: out.last.marks, link: s.link);
    } else {
      out.add(s);
    }
  }
  return out;
}

/// The stored body: deterministic (fixed key order, sorted marks, merged runs).
String encodeBlocks(List<Block> blocks) => jsonEncode([for (final b in blocks) b.toJson()]);

List<Block> decodeBlocks(String body) => [for (final b in jsonDecode(body) as List) Block.fromJson((b as Map).cast())];

/// The text a search indexes.
String plainText(List<Block> blocks) => blocks.where((b) => b.type != BlockType.image).map((b) => b.text).join('\n');

/// Documents the `[[` picker offers (fake, for the probe).
const fakeDocuments = <String, String>{
  'doc-hop': 'Ghi chú họp gia đình',
  'doc-danang': 'Chuyến đi Đà Nẵng',
  'doc-sach': 'Sách muốn đọc',
  'doc-congthuc': 'Công thức nấu ăn',
  'doc-ke-hoach': 'Kế hoạch năm 2027',
};

var _n = 0;
String newBlockId() => 'b${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_n++).toRadixString(36)}';

/// A small document with every block type, marks and a link.
List<Block> sampleDocument() => [
      Block('s1', BlockType.heading1, spans: [Span('Chuyến đi Đà Nẵng')]),
      Block('s2', BlockType.paragraph, spans: [
        Span('Đi vào '),
        Span('tháng Sáu', marks: {'bold'}),
        Span(', ở gần biển Mỹ Khê. Xem thêm '),
        Span('Ghi chú họp gia đình', link: 'doc-hop'),
        Span('.'),
      ]),
      Block('s3', BlockType.heading2, spans: [Span('Cần chuẩn bị')]),
      Block('s4', BlockType.todo, spans: [Span('Đặt vé máy bay')], checked: true),
      Block('s5', BlockType.todo, spans: [Span('Đặt khách sạn')]),
      Block('s6', BlockType.bullet, spans: [Span('Kem chống nắng')]),
      Block('s7', BlockType.bullet, spans: [Span('Áo mưa', marks: {'italic'})]),
      Block('s8', BlockType.numbered, spans: [Span('Ngày 1: Bà Nà')]),
      Block('s9', BlockType.numbered, spans: [Span('Ngày 2: Hội An')]),
      Block('s10', BlockType.image, image: 'sha256-example'),
      Block('s11', BlockType.paragraph, spans: [Span('Ước tính chi phí: 12 triệu đồng.')]),
    ];

/// About [pages] pages of mixed text (a page ~ 3 000 characters).
List<Block> bigDocument({int pages = 50}) {
  const para = 'Mỗi buổi sáng tôi dậy lúc sáu giờ, uống một cốc nước ấm rồi đi bộ quanh hồ. '
      'Không khí trong lành giúp đầu óc tỉnh táo, và tôi thường nghĩ về những việc cần làm trong ngày. '
      'Sau đó tôi ghi lại ba điều quan trọng nhất vào sổ tay, để không bị cuốn vào những việc nhỏ nhặt. ';
  final out = <Block>[];
  for (var p = 0; p < pages; p++) {
    out.add(Block('h$p', BlockType.heading2, spans: [Span('Trang ${p + 1}')]));
    for (var i = 0; i < 10; i++) {
      out.add(Block('p$p-$i', i % 5 == 4 ? BlockType.bullet : BlockType.paragraph,
          spans: [Span(para.substring(0, 120)), Span('quan trọng', marks: {'bold'}), Span(para.substring(120))]));
    }
  }
  return out;
}
