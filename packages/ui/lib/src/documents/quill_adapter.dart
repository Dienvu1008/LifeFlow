// P05a T8 (ADR-0073; S-07, ADR-0020): the only place that knows flutter_quill's
// format. A document is stored in LifeFlow's own block format (ADR-0066);
// the editor gets a Quill Delta made from it and gives back blocks.
//   lines      one Quill line is one block; a line's attributes give its type
//              (header 1–3, list bullet / ordered / checked / unchecked,
//              blockquote, code-block) and its indent (lists and to-dos)
//   inline     bold, italic, underline, strike, code; a `[[…]]` link is a
//              link to `lifeflow-doc:<id>`, a web link its address (http,
//              https, mailto only; anything else pasted in is dropped)
//   files      an attachment is a block embed of its own type, its
//              reference as JSON; other embeds (a pasted picture) are dropped
//   ids        Quill has none: they are kept by line position since the last
//              load (ADR-0066 §5)
import 'dart:convert';
import 'dart:math';

import 'package:application/application.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_quill/quill_delta.dart';

/// A `[[…]]` link in Quill: a link to this scheme and the document's id.
const docLinkScheme = 'lifeflow-doc:';

/// The embed type of an attachment block.
const attachmentEmbedType = 'lifeflow-file';

final _random = Random.secure();

/// A new block id (16 hex digits).
String newBlockId() => [for (var i = 0; i < 8; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();

const _marks = {
  'bold': TextMark.bold,
  'italic': TextMark.italic,
  'underline': TextMark.underline,
  'strike': TextMark.strike,
  'code': TextMark.code,
};

bool _webAddress(String u) {
  final p = Uri.tryParse(u);
  return p != null && (p.scheme == 'http' || p.scheme == 'https' || p.scheme == 'mailto');
}

/// The blocks of an editor's [delta]. [ids] are the block ids of the last
/// load, by line.
DocumentBody bodyOf(Delta delta, {List<String> ids = const []}) {
  final out = <DocBlock>[];
  var runs = <TextRun>[];
  AttachmentRef? file;
  var embedded = false;

  void endLine(Map<String, dynamic>? a) {
    final id = out.length < ids.length ? ids[out.length] : newBlockId();
    if (embedded) {
      if (file != null) out.add(DocBlock(id, BlockType.attachment, attachment: file));
    } else {
      final list = a?['list'];
      final type = switch ((a?['header'], list)) {
        (1, _) => BlockType.heading1,
        (2, _) => BlockType.heading2,
        (3, _) => BlockType.heading3,
        (_, 'bullet') => BlockType.bullet,
        (_, 'ordered') => BlockType.numbered,
        (_, 'checked' || 'unchecked') => BlockType.todo,
        _ when a?['code-block'] == true => BlockType.code,
        _ when a?['blockquote'] == true => BlockType.quote,
        _ => BlockType.paragraph,
      };
      final indented = type == BlockType.bullet || type == BlockType.numbered || type == BlockType.todo;
      final indent = a?['indent'];
      out.add(DocBlock(id, type,
          runs: runs,
          checked: list == 'checked',
          indent: indented && indent is int ? indent.clamp(0, maxBlockIndent) : 0));
    }
    runs = [];
    file = null;
    embedded = false;
  }

  for (final op in delta.toList()) {
    if (!op.isInsert) continue;
    final data = op.data;
    if (data is Map) {
      // Quill can put a block embed on a line with text ("abc[file]\n"):
      // the text before it is a block of its own, never lost.
      if (runs.isNotEmpty || embedded) endLine(null);
      embedded = true;
      final raw = data[attachmentEmbedType];
      file = raw is String ? _fileOf(raw) : null;
      continue;
    }
    final parts = (data as String).split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        // Text after a file on the same line: the file ends there.
        if (embedded) endLine(null);
        runs.add(_run(parts[i], op.attributes));
      }
      if (i < parts.length - 1) endLine(op.attributes);
    }
  }
  if (runs.isNotEmpty || embedded) endLine(null);
  if (out.isEmpty) out.add(DocBlock(ids.isNotEmpty ? ids.first : newBlockId(), BlockType.paragraph));
  return DocumentBody(out);
}

AttachmentRef? _fileOf(String raw) {
  try {
    final j = jsonDecode(raw);
    if (j is Map && j['hash'] is String && j['name'] is String && j['size'] is int && j['mime'] is String) {
      return AttachmentRef(hash: j['hash'] as String, name: j['name'] as String, size: j['size'] as int, mime: j['mime'] as String);
    }
  } on FormatException {
    // not one of ours: dropped
  }
  return null;
}

TextRun _run(String text, Map<String, dynamic>? a) {
  final link = a?['link'];
  String? doc, url;
  if (link is String) {
    if (link.startsWith(docLinkScheme) && link.length > docLinkScheme.length) {
      doc = link.substring(docLinkScheme.length);
    } else if (_webAddress(link)) {
      url = link;
    }
  }
  return TextRun(text, marks: {for (final e in _marks.entries) if (a?[e.key] == true) e.value}, doc: doc, url: url);
}

/// The editor's Delta for [body].
Delta deltaOf(DocumentBody body) {
  final d = Delta();
  for (final b in body.blocks) {
    if (b.type == BlockType.attachment) {
      final a = b.attachment;
      if (a != null) {
        d.insert(q.BlockEmbed(attachmentEmbedType, jsonEncode(a.toJson())).toJson());
        d.insert('\n');
      }
      continue;
    }
    for (final r in b.runs) {
      final attrs = <String, dynamic>{
        for (final e in _marks.entries) if (r.marks.contains(e.value)) e.key: true,
        if (r.doc != null) 'link': '$docLinkScheme${r.doc}',
        if (r.url != null) 'link': r.url,
      };
      d.insert(r.text, attrs.isEmpty ? null : attrs);
    }
    final line = <String, dynamic>{
      ...switch (b.type) {
        BlockType.heading1 => {'header': 1},
        BlockType.heading2 => {'header': 2},
        BlockType.heading3 => {'header': 3},
        BlockType.bullet => {'list': 'bullet'},
        BlockType.numbered => {'list': 'ordered'},
        BlockType.todo => {'list': b.checked ? 'checked' : 'unchecked'},
        BlockType.quote => {'blockquote': true},
        BlockType.code => {'code-block': true},
        _ => const <String, dynamic>{},
      },
      if (b.indent > 0 && (b.type == BlockType.bullet || b.type == BlockType.numbered || b.type == BlockType.todo))
        'indent': b.indent,
    };
    d.insert('\n', line.isEmpty ? null : line);
  }
  if (d.isEmpty) d.insert('\n');
  return d;
}

/// A Quill document for [body].
q.Document quillDocumentOf(DocumentBody body) => q.Document.fromDelta(deltaOf(body));

/// The block ids of [body], by line, for [bodyOf].
List<String> blockIdsOf(DocumentBody body) => [
      for (final b in body.blocks)
        if (b.type != BlockType.attachment || b.attachment != null) b.id
    ];

/// The attachment of an embed's data, or null.
AttachmentRef? attachmentOfEmbed(Object? data) => data is String ? _fileOf(data) : null;
