// S-07 (throwaway): flutter_quill (Delta) <-> LifeFlow blocks. Quill has no
// block ids: the adapter keeps them by line position from the last load.
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:flutter_quill/quill_delta.dart';
import 'package:s07_common/s07_common.dart';

const docScheme = 'lifeflow-doc:';

List<Block> toBlocks(Delta delta, {List<String> ids = const []}) {
  final out = <Block>[];
  var spans = <Span>[];
  String? image;
  void endLine(Map<String, dynamic>? a) {
    final id = out.length < ids.length ? ids[out.length] : newBlockId();
    if (image != null) {
      out.add(Block(id, BlockType.image, image: image));
    } else {
      final header = a?['header'];
      final list = a?['list'];
      final type = switch ((header, list)) {
        (1, _) => BlockType.heading1,
        (2, _) => BlockType.heading2,
        (_, 'bullet') => BlockType.bullet,
        (_, 'ordered') => BlockType.numbered,
        (_, 'checked' || 'unchecked') => BlockType.todo,
        _ => BlockType.paragraph,
      };
      out.add(Block(id, type, spans: normalize(spans), checked: list == 'checked'));
    }
    spans = [];
    image = null;
  }

  for (final op in delta.toList()) {
    if (op.key != Operation.insertKey) continue;
    final data = op.data;
    final a = op.attributes;
    if (data is Map) {
      image = '${data[BlockEmbed.imageType] ?? ''}';
      continue;
    }
    final text = data as String;
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(_span(parts[i], a));
      if (i < parts.length - 1) endLine(a);
    }
  }
  return out;
}

Span _span(String text, Map<String, dynamic>? a) {
  final link = a?['link'];
  return Span(text,
      marks: {if (a?['bold'] == true) 'bold', if (a?['italic'] == true) 'italic'},
      link: link is String && link.startsWith(docScheme) ? link.substring(docScheme.length) : null);
}

Delta deltaOf(List<Block> blocks) {
  final d = Delta();
  for (final b in blocks) {
    if (b.type == BlockType.image) {
      d.insert({BlockEmbed.imageType: b.image ?? ''});
      d.insert('\n');
      continue;
    }
    for (final s in b.spans) {
      d.insert(s.text, {
        if (s.marks.contains('bold')) 'bold': true,
        if (s.marks.contains('italic')) 'italic': true,
        if (s.link != null) 'link': '$docScheme${s.link}',
      }.isEmpty
          ? null
          : {
              if (s.marks.contains('bold')) 'bold': true,
              if (s.marks.contains('italic')) 'italic': true,
              if (s.link != null) 'link': '$docScheme${s.link}',
            });
    }
    d.insert('\n', switch (b.type) {
      BlockType.heading1 => {'header': 1},
      BlockType.heading2 => {'header': 2},
      BlockType.bullet => {'list': 'bullet'},
      BlockType.numbered => {'list': 'ordered'},
      BlockType.todo => {'list': b.checked ? 'checked' : 'unchecked'},
      _ => null,
    });
  }
  return d;
}

Document documentOf(List<Block> blocks) => Document.fromDelta(deltaOf(blocks));
