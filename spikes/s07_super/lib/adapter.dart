// S-07 (throwaway): super_editor <-> LifeFlow blocks.
import 'package:s07_common/s07_common.dart';
import 'package:super_editor/super_editor.dart';

const docScheme = 'lifeflow-doc:';

List<Block> toBlocks(Document doc) {
  final out = <Block>[];
  for (final n in doc) {
    if (n is ImageNode) {
      out.add(Block(n.id, BlockType.image, image: n.imageUrl));
      continue;
    }
    if (n is! TextNode) {
      out.add(Block(n.id, BlockType.paragraph));
      continue;
    }
    final BlockType type;
    if (n is TaskNode) {
      type = BlockType.todo;
    } else if (n is ListItemNode) {
      type = n.type == ListItemType.ordered ? BlockType.numbered : BlockType.bullet;
    } else {
      final bt = n.getMetadataValue('blockType');
      type = bt == header1Attribution
          ? BlockType.heading1
          : bt == header2Attribution
              ? BlockType.heading2
              : BlockType.paragraph;
    }
    out.add(Block(n.id, type, spans: spansOf(n.text), checked: n is TaskNode && n.isComplete));
  }
  return out;
}

List<Span> spansOf(AttributedText t) {
  final text = t.text;
  if (text.isEmpty) return [];
  return [
    for (final s in t.computeAttributionSpans())
      Span(
        text.substring(s.start, s.end + 1),
        marks: {
          if (s.attributions.contains(boldAttribution)) 'bold',
          if (s.attributions.contains(italicsAttribution)) 'italic',
        },
        link: _linkOf(s.attributions),
      ),
  ];
}

String? _linkOf(Set<Attribution> a) {
  for (final x in a) {
    if (x is LinkAttribution && x.plainTextUri.startsWith(docScheme)) return x.plainTextUri.substring(docScheme.length);
  }
  return null;
}

AttributedText textOf(List<Span> spans) {
  final at = AttributedText(spans.map((s) => s.text).join());
  var i = 0;
  for (final s in spans) {
    if (s.text.isEmpty) continue;
    final r = SpanRange(i, i + s.text.length - 1);
    if (s.marks.contains('bold')) at.addAttribution(boldAttribution, r);
    if (s.marks.contains('italic')) at.addAttribution(italicsAttribution, r);
    if (s.link != null) at.addAttribution(LinkAttribution('$docScheme${s.link}'), r, autoMerge: false);
    i += s.text.length;
  }
  return at;
}

DocumentNode nodeOf(Block b) {
  final t = textOf(b.spans);
  return switch (b.type) {
    BlockType.paragraph => ParagraphNode(id: b.id, text: t),
    BlockType.heading1 => ParagraphNode(id: b.id, text: t, metadata: {'blockType': header1Attribution}),
    BlockType.heading2 => ParagraphNode(id: b.id, text: t, metadata: {'blockType': header2Attribution}),
    BlockType.bullet => ListItemNode.unordered(id: b.id, text: t),
    BlockType.numbered => ListItemNode.ordered(id: b.id, text: t),
    BlockType.todo => TaskNode(id: b.id, text: t, isComplete: b.checked),
    BlockType.image => ImageNode(id: b.id, imageUrl: b.image ?? ''),
  };
}

MutableDocument documentOf(List<Block> blocks) => MutableDocument(nodes: [for (final b in blocks) nodeOf(b)]);
