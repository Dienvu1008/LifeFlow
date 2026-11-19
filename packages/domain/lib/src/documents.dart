// P05a T1 (ADR-0066; p05-plan.md; document-knowledge.md): documents as pure
// domain values. The body is LifeFlow's own block format, serialized
// deterministically (the same content, the same bytes), so revisions, sync and
// conflicts never depend on an editor library (ADR-0020: the editor sits
// behind an adapter). No Flutter, no database (FF-ARCH-01).
//   DOC-001  the tree has no cycle                     [DocumentTreeRules]
//   DOC-003  a link resolves or shows as broken        [resolveLink]
//   DOC-004  tree, [[…]] links, web links, attachments and links to other
//            things are distinct relations             [DocumentRelations]
import 'dart:convert';

/// The longest title a document may have.
const maxDocumentTitleLength = 200;

/// The most text one document holds (about 100 pages), and the most blocks.
const maxDocumentTextLength = 300000;
const maxDocumentBlocks = 10000;

/// The deepest indent of a list item or a to-do.
const maxBlockIndent = 5;

/// The longest file name an attachment keeps.
const maxAttachmentNameLength = 255;

/// The version of the body format; a body names it, so a later app can read
/// an older body.
const documentFormatVersion = 1;

enum BlockType { paragraph, heading1, heading2, heading3, bullet, numbered, todo, quote, code, attachment }

/// Inline marks a run of text may carry.
enum TextMark { bold, italic, underline, strike, code }

/// A run of text with the same marks. It may link to a document of the same
/// workspace ([doc], a `[[…]]` link) or to a web address ([url]), not both.
class TextRun {
  TextRun(this.text, {Set<TextMark> marks = const {}, this.doc, this.url}) : marks = Set.unmodifiable(marks);
  final String text;
  final Set<TextMark> marks;
  final String? doc;
  final String? url;

  bool sameStyle(TextRun o) =>
      doc == o.doc && url == o.url && marks.length == o.marks.length && marks.containsAll(o.marks);

  Map<String, Object?> toJson() => {
        't': text,
        if (marks.isNotEmpty) 'm': [for (final m in TextMark.values) if (marks.contains(m)) m.name],
        if (doc != null) 'doc': doc,
        if (url != null) 'url': url,
      };

  @override
  bool operator ==(Object o) => o is TextRun && o.text == text && sameStyle(o);
  @override
  int get hashCode => Object.hash(text, doc, url, Object.hashAllUnordered(marks));
}

/// A file kept by its content hash (p05-plan C3: the file stays on the
/// device; the reference syncs).
class AttachmentRef {
  const AttachmentRef({required this.hash, required this.name, required this.size, required this.mime});

  /// `sha256:` followed by 64 hex digits.
  final String hash;
  final String name;
  final int size;
  final String mime;

  bool get isImage => mime.startsWith('image/');

  Map<String, Object?> toJson() => {'hash': hash, 'name': name, 'size': size, 'mime': mime};

  @override
  bool operator ==(Object o) => o is AttachmentRef && o.hash == hash && o.name == name && o.size == size && o.mime == mime;
  @override
  int get hashCode => Object.hash(hash, name, size, mime);
}

/// One block of a document. Text blocks have [runs]; an attachment block has
/// [attachment] and no runs.
class DocBlock {
  DocBlock(this.id, this.type, {List<TextRun> runs = const [], this.checked = false, this.indent = 0, this.attachment})
      : runs = List.unmodifiable(normalizeRuns(runs));
  final String id;
  final BlockType type;
  final List<TextRun> runs;

  /// A to-do's tick.
  final bool checked;

  /// A list item's or a to-do's level, 0 to [maxBlockIndent].
  final int indent;
  final AttachmentRef? attachment;

  String get text => runs.map((r) => r.text).join();

  bool get _indented => type == BlockType.bullet || type == BlockType.numbered || type == BlockType.todo;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        if (type == BlockType.attachment) 'file': attachment?.toJson() else 'runs': [for (final r in runs) r.toJson()],
        if (type == BlockType.todo) 'checked': checked,
        if (_indented && indent > 0) 'indent': indent,
      };
}

/// Adjacent runs with the same style become one; empty runs go. Two bodies
/// that look the same are the same.
List<TextRun> normalizeRuns(List<TextRun> runs) {
  final out = <TextRun>[];
  for (final r in runs) {
    if (r.text.isEmpty) continue;
    if (out.isNotEmpty && out.last.sameStyle(r)) {
      final last = out.removeLast();
      out.add(TextRun(last.text + r.text, marks: last.marks, doc: last.doc, url: last.url));
    } else {
      out.add(r);
    }
  }
  return out;
}

/// A document's body: its blocks in order.
class DocumentBody {
  DocumentBody(List<DocBlock> blocks) : blocks = List.unmodifiable(blocks);

  /// A new document: one empty paragraph.
  factory DocumentBody.empty(String firstBlockId) => DocumentBody([DocBlock(firstBlockId, BlockType.paragraph)]);

  final List<DocBlock> blocks;

  /// The stored form: one JSON text with a fixed key order, marks in a fixed
  /// order and runs merged, so the same content always gives the same bytes.
  String encode() => jsonEncode({'v': documentFormatVersion, 'blocks': [for (final b in blocks) b.toJson()]});

  /// Reads a stored body; a [FormatException] for anything that is not one.
  static DocumentBody decode(String stored) {
    final Object? j;
    try {
      j = jsonDecode(stored);
    } on FormatException {
      throw const FormatException('a document body is JSON');
    }
    if (j is! Map || j['v'] is! int || j['blocks'] is! List) throw const FormatException('not a document body');
    if ((j['v'] as int) > documentFormatVersion) throw const FormatException('a newer document format');
    return DocumentBody([for (final b in j['blocks'] as List) _block(b)]);
  }

  /// All the text, block by block (what search indexes, with [title]).
  String plainText() => [
        for (final b in blocks) b.type == BlockType.attachment ? (b.attachment?.name ?? '') : b.text,
      ].join('\n');

  int get textLength => blocks.fold(0, (n, b) => n + b.text.length);

  /// Why this body cannot be saved, or null.
  String? validate() {
    if (blocks.isEmpty) return 'a document has at least one block';
    if (blocks.length > maxDocumentBlocks) return 'a document has at most $maxDocumentBlocks blocks';
    if (textLength > maxDocumentTextLength) return 'a document holds at most $maxDocumentTextLength characters';
    final ids = <String>{};
    for (final b in blocks) {
      if (b.id.isEmpty || b.id.length > 64) return 'a block id is 1 to 64 characters';
      if (!ids.add(b.id)) return 'two blocks have the same id';
      if (b.indent < 0 || b.indent > maxBlockIndent) return 'an indent is 0 to $maxBlockIndent';
      if (b.type == BlockType.attachment) {
        final a = b.attachment;
        if (a == null) return 'an attachment block names its file';
        if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(a.hash)) return 'an attachment is named by its sha256';
        if (a.name.trim().isEmpty || a.name.length > maxAttachmentNameLength) return 'an attachment has a name';
        if (a.size < 0) return 'an attachment\'s size is 0 or more';
      } else {
        if (b.attachment != null) return 'only an attachment block names a file';
        for (final r in b.runs) {
          if (r.doc != null && r.url != null) return 'a run links to a document or to a web address, not both';
          if (r.doc != null && r.doc!.isEmpty) return 'a link names a document';
          final u = r.url;
          if (u != null && !_webAddress(u)) return 'a web link is an http, https or mailto address';
        }
      }
    }
    return null;
  }
}

bool _webAddress(String u) {
  final p = Uri.tryParse(u);
  return p != null && (p.scheme == 'http' || p.scheme == 'https' || p.scheme == 'mailto');
}

DocBlock _block(Object? b) {
  if (b is! Map) throw const FormatException('a block is an object');
  final id = b['id'], typeName = b['type'];
  if (id is! String || typeName is! String) throw const FormatException('a block has an id and a type');
  final type = BlockType.values.where((t) => t.name == typeName).firstOrNull;
  if (type == null) throw FormatException('unknown block type $typeName');
  final indent = b['indent'] ?? 0;
  if (indent is! int) throw const FormatException('an indent is a number');
  if (type == BlockType.attachment) {
    final f = b['file'];
    if (f is! Map || f['hash'] is! String || f['name'] is! String || f['size'] is! int || f['mime'] is! String) {
      throw const FormatException('an attachment block names its file');
    }
    return DocBlock(id, type,
        attachment: AttachmentRef(hash: f['hash'], name: f['name'], size: f['size'], mime: f['mime']), indent: indent);
  }
  final runs = b['runs'];
  if (runs is! List) throw const FormatException('a text block has runs');
  return DocBlock(id, type, runs: [for (final r in runs) _run(r)], checked: b['checked'] == true, indent: indent);
}

TextRun _run(Object? r) {
  if (r is! Map || r['t'] is! String) throw const FormatException('a run has text');
  final marks = <TextMark>{};
  for (final m in (r['m'] as List?) ?? const []) {
    final mark = TextMark.values.where((x) => x.name == m).firstOrNull;
    if (mark == null) throw FormatException('unknown mark $m');
    marks.add(mark);
  }
  final doc = r['doc'], url = r['url'];
  if ((doc != null && doc is! String) || (url != null && url is! String)) throw const FormatException('a link is text');
  return TextRun(r['t'] as String, marks: marks, doc: doc as String?, url: url as String?);
}

/// Why a title cannot be used, or null.
String? documentTitleError(String title) {
  final t = title.trim();
  if (t.isEmpty) return 'a document has a title';
  if (t.length > maxDocumentTitleLength) return 'a title is at most $maxDocumentTitleLength characters';
  return null;
}

// --- relations (DOC-004) ---------------------------------------------------

/// The relations of one document, each of its own kind (DOC-004): its place
/// in the tree, the documents its text links to, the web addresses, the
/// files. Links to tasks, events and goals are records of their own
/// (`documentLink`), never part of the body.
class DocumentRelations {
  const DocumentRelations({required this.parent, required this.docLinks, required this.webLinks, required this.attachments});
  final String? parent;
  final Set<String> docLinks;
  final Set<String> webLinks;
  final Set<String> attachments;
}

DocumentRelations relationsOf({required String? parentId, required DocumentBody body}) {
  final docs = <String>{}, urls = <String>{}, files = <String>{};
  for (final b in body.blocks) {
    if (b.attachment case final a?) files.add(a.hash);
    for (final r in b.runs) {
      if (r.doc case final d?) docs.add(d);
      if (r.url case final u?) urls.add(u);
    }
  }
  return DocumentRelations(parent: parentId, docLinks: docs, webLinks: urls, attachments: files);
}

// --- [[…]] links and backlinks (DOC-003, C6) --------------------------------

enum LinkState { ok, inTrash, missing }

/// What a `[[…]]` link shows (DOC-003): the document, a document in the
/// trash, or one that is gone. A link is never removed for being broken.
/// [lookup] gives the target's trash state, or null when there is none in
/// the link's workspace.
LinkState resolveLink(String target, bool? Function(String id) lookup) => switch (lookup(target)) {
      null => LinkState.missing,
      true => LinkState.inTrash,
      false => LinkState.ok,
    };

/// P05a T6 (ADR-0071): [body] with the text of each `[[…]]` link set to its
/// target's current title, so the stored text (and search) follows a rename.
/// [titleOf] gives the title of a live target in the link's workspace, or
/// null: a broken link keeps the text it had (DOC-003). [body] itself when
/// nothing changes, or when the result would not be a valid body.
DocumentBody withLinkTitles(DocumentBody body, String? Function(String id) titleOf) {
  TextRun current(TextRun r) {
    final d = r.doc;
    final title = d == null ? null : titleOf(d);
    return title == null || title == r.text ? r : TextRun(title, marks: r.marks, doc: d);
  }

  final blocks = [
    for (final b in body.blocks)
      DocBlock(b.id, b.type, checked: b.checked, indent: b.indent, attachment: b.attachment, runs: [
        for (final r in b.runs) current(r),
      ]),
  ];
  final out = DocumentBody(blocks);
  if (out.encode() == body.encode()) return body;
  return out.validate() == null ? out : body;
}

/// The longest sentence a backlink shows; a longer one is cut around the link.
const maxBacklinkSnippet = 200;

/// Under a document: each place in [body] that links to [target], with the
/// sentence around it (C6). One entry per linking block and sentence.
List<String> backlinkSnippets(DocumentBody body, String target) {
  final out = <String>[];
  for (final b in body.blocks) {
    var at = 0;
    for (final r in b.runs) {
      if (r.doc == target) {
        final s = _sentenceAround(b.text, at, at + r.text.length);
        if (!out.contains(s)) out.add(s);
      }
      at += r.text.length;
    }
  }
  return out;
}

String _sentenceAround(String text, int start, int end) {
  bool stop(int i) => '.!?…'.contains(text[i]) && (i + 1 == text.length || text[i + 1] == ' ');
  // From after the stop before the link to the first stop after it (kept).
  var a = start;
  while (a > 0 && !stop(a - 1)) {
    a--;
  }
  var z = end;
  while (z < text.length && !stop(z)) {
    z++;
  }
  if (z < text.length) z++;
  var s = text.substring(a, z).trim();
  if (s.length <= maxBacklinkSnippet) return s;
  final mid = (start + end) ~/ 2 - a;
  final from = (mid - maxBacklinkSnippet ~/ 2).clamp(0, s.length - maxBacklinkSnippet);
  s = s.substring(from, from + maxBacklinkSnippet).trim();
  return '${from > 0 ? '…' : ''}$s…';
}

// --- the tree (DOC-001) -----------------------------------------------------

class DocumentTreeRules {
  /// Why [docId] cannot go under [newParentId], or null. The caller gives
  /// the new parent and all its ancestors ([newParentAncestorsIncludingSelf]),
  /// read in the same workspace. To the top level is always allowed.
  static String? moveError({
    required String docId,
    required String? newParentId,
    required Set<String> newParentAncestorsIncludingSelf,
  }) {
    if (newParentId == null) return null;
    if (newParentAncestorsIncludingSelf.contains(docId)) return 'a document cannot go under itself or its own subdocuments';
    return null;
  }
}

// --- revisions (C5, C7) -----------------------------------------------------

/// Why a revision was written.
enum RevisionReason {
  /// A save (C7: leaving, switching, the app to the background, 10 s idle).
  save,

  /// The other side of a sync conflict, kept (DOC-005, GS-08).
  conflict,

  /// A restore of an earlier revision, saved as a new one.
  restore,
}

/// When the editor saves on its own (C7).
const documentIdleSave = Duration(seconds: 10);

// --- search (C4) -------------------------------------------------------------

/// An FTS5 query for what a person typed, by the exact spelling (C4): every
/// word must be there; the last one may be the start of a word unless the
/// input ends with a space; text in double quotes is a phrase. Null when there
/// is nothing to look for. The caller normalizes [input] (NFC) as it
/// normalized the indexed text.
String? searchQueryOf(String input) {
  final parts = <String>[];
  final phrase = RegExp(r'"([^"]*)"');
  var rest = input;
  for (final m in phrase.allMatches(input)) {
    final p = m.group(1)!.trim();
    if (p.isNotEmpty) parts.add(_quote(p));
  }
  rest = input.replaceAll(phrase, ' ').replaceAll('"', ' ');
  final words = rest.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final prefixLast = words.isNotEmpty && !RegExp(r'\s$').hasMatch(input) && !input.trimRight().endsWith('"');
  for (var i = 0; i < words.length; i++) {
    final w = _quote(words[i]);
    parts.add(prefixLast && i == words.length - 1 ? '$w*' : w);
  }
  return parts.isEmpty ? null : parts.join(' ');
}

/// Every `"` was taken out above (phrases end at one), so a word or a phrase
/// never holds one: quoting is enough to keep FTS5's syntax out.
String _quote(String s) => '"$s"';
