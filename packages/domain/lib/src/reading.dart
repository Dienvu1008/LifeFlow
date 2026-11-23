// P05b T4 (ADR-0078; p05b-plan.md D4, D5, D7): what is read aloud from a
// document, sentence by sentence, so the one being read can be shown.
//   blocks     every block with text, in order: paragraphs, headings, list
//              items, to-dos, quotes, code; a file is skipped
//   sentences  a sentence ends at . ! ? or … followed by a space or the end
//              of the block (closing quotes and brackets stay with it), or at
//              a line break; "3.5" and "lifeflow.app" do not end one. A very
//              long sentence is cut at a comma or a space, so a voice never
//              gets too much at once
//   offsets    [start, end) in the block's text (its runs joined), spaces
//              around the sentence left out
//   language   Vietnamese or English, guessed from the letters: it picks the
//              voice, and says which language the device lacks (D5)

import 'documents.dart';

/// The longest piece a voice is given at once.
const maxReadingSentenceLength = 300;

/// A sentence to read: in block [blockId], from [start] to [end] of the
/// block's text.
class ReadingSentence {
  const ReadingSentence({required this.blockId, required this.start, required this.end, required this.text});
  final String blockId;
  final int start;
  final int end;
  final String text;

  @override
  bool operator ==(Object o) =>
      o is ReadingSentence && o.blockId == blockId && o.start == start && o.end == end && o.text == text;
  @override
  int get hashCode => Object.hash(blockId, start, end, text);
  @override
  String toString() => '$blockId[$start,$end) "$text"';
}

const _enders = '.!?…';
const _closers = '"\'”’»)]}';

bool _space(String c) => c.trim().isEmpty;

/// The sentences of [body], in reading order.
List<ReadingSentence> readingOf(DocumentBody body) => [
      for (final b in body.blocks)
        if (b.type != BlockType.attachment) ...sentencesOf(b.id, b.text),
    ];

/// The sentences of one block's [text].
List<ReadingSentence> sentencesOf(String blockId, String text) {
  final out = <ReadingSentence>[];
  void add(int from, int to) {
    while (from < to && _space(text[from])) {
      from++;
    }
    while (to > from && _space(text[to - 1])) {
      to--;
    }
    if (from >= to) return;
    // A very long one is cut at a comma or a space before the limit.
    while (to - from > maxReadingSentenceLength) {
      final limit = from + maxReadingSentenceLength;
      var cut = text.lastIndexOf(', ', limit - 1);
      if (cut <= from) {
        cut = text.lastIndexOf(' ', limit - 1);
      } else {
        cut += 1; // keep the comma
      }
      if (cut <= from) cut = limit;
      out.add(ReadingSentence(blockId: blockId, start: from, end: cut, text: text.substring(from, cut)));
      from = cut;
      while (from < to && _space(text[from])) {
        from++;
      }
    }
    if (from < to) out.add(ReadingSentence(blockId: blockId, start: from, end: to, text: text.substring(from, to)));
  }

  var start = 0;
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (c == '\n') {
      add(start, i);
      start = i + 1;
      i++;
      continue;
    }
    if (_enders.contains(c)) {
      var j = i + 1;
      while (j < text.length && (_enders.contains(text[j]) || _closers.contains(text[j]))) {
        j++;
      }
      if (j == text.length || _space(text[j])) {
        add(start, j);
        start = j;
        i = j;
        continue;
      }
    }
    i++;
  }
  add(start, text.length);
  return out;
}

const _vietnamese = 'ăâđêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ';

/// `vi` or `en`: Vietnamese when at least one word in seven has a letter only
/// Vietnamese uses (or a combining tone mark, for text typed decomposed).
String readingLanguageOf(DocumentBody body) {
  final words = body.plainText().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'en';
  var vi = 0;
  for (final w in words) {
    if (w.runes.any((r) => _vietnamese.runes.contains(r) || (r >= 0x300 && r <= 0x323))) vi++;
  }
  return vi * 7 >= words.length ? 'vi' : 'en';
}

/// P05b T5 (ADR-0079, D4): a PDF page's text as it is read. A line break in
/// a PDF is where a line ended on the page, not where a sentence ends: lines
/// are joined with a space, and a word cut by a hyphen at a line end is
/// joined back. A blank line (a new paragraph) still ends a sentence.
String pdfReadingText(String raw) {
  final t = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final joined = t.replaceAllMapped(RegExp(r'(\p{L})-\n[ \t]*(\p{Ll})', unicode: true), (m) => '${m[1]}${m[2]}');
  return joined
      .split(RegExp(r'\n[ \t]*\n\s*'))
      .map((para) => para.replaceAll(RegExp(r'[ \t]*\n[ \t]*'), ' '))
      .join('\n');
}

const _pageBlock = 'page-';

/// The pages of a PDF, from page [first] on, as a body to read: one block
/// per page (`page-<n>`), its text as [pdfReadingText] gives it.
DocumentBody pdfReadingBody(List<String> pages, {int first = 1}) => DocumentBody([
      for (var i = 0; i < pages.length; i++)
        DocBlock('$_pageBlock${first + i}', BlockType.paragraph, runs: [TextRun(pdfReadingText(pages[i]))]),
    ]);

/// The page of a block of [pdfReadingBody], or null.
int? pageOfReadingBlock(String blockId) =>
    blockId.startsWith(_pageBlock) ? int.tryParse(blockId.substring(_pageBlock.length)) : null;
