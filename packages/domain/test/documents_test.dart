// P05a T1 (ADR-0066): documents as pure values.
//   format    the body round-trips exactly; the same content gives the same
//             bytes (property over random bodies); a bad body is refused
//   rules     DOC-001 (no cycle), DOC-003 (a link resolves or shows broken),
//             DOC-004 (distinct relations), titles, limits
//   links     backlinks with the sentence around the link (C6)
//   search    the FTS5 query by the exact spelling (C4)
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

const hash = 'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

DocumentBody sample() => DocumentBody([
      DocBlock('b1', BlockType.heading1, runs: [TextRun('Chuyến đi Đà Nẵng')]),
      DocBlock('b2', BlockType.paragraph, runs: [
        TextRun('Đi vào '),
        TextRun('tháng Sáu', marks: {TextMark.italic, TextMark.bold}),
        TextRun('. Xem '),
        TextRun('Ghi chú họp', doc: 'doc-hop'),
        TextRun(' và '),
        TextRun('bản đồ', url: 'https://example.org/map'),
        TextRun('.'),
      ]),
      DocBlock('b3', BlockType.todo, runs: [TextRun('Đặt vé')], checked: true, indent: 1),
      DocBlock('b4', BlockType.bullet, runs: [TextRun('Kem chống nắng')]),
      DocBlock('b5', BlockType.attachment,
          attachment: const AttachmentRef(hash: hash, name: 'vé máy bay.pdf', size: 52000, mime: 'application/pdf')),
      DocBlock('b6', BlockType.paragraph),
    ]);

void main() {
  group('format', () {
    test('a body round-trips exactly, ids, marks, links, ticks, indents and files included', () {
      final s = sample().encode();
      final back = DocumentBody.decode(s);
      expect(back.encode(), s);
      expect(back.blocks.map((b) => b.id), ['b1', 'b2', 'b3', 'b4', 'b5', 'b6']);
      expect((back.blocks[2].checked, back.blocks[2].indent), (true, 1));
      expect(back.blocks[4].attachment, sample().blocks[4].attachment);
      expect(back.blocks[1].runs[1].marks, {TextMark.bold, TextMark.italic});
    });

    test('the stored form is fixed: key order, marks in a fixed order, runs merged, empty runs dropped', () {
      final b = DocumentBody([
        DocBlock('x', BlockType.paragraph, runs: [
          TextRun('Ghi '),
          TextRun(''),
          TextRun('chú'),
          TextRun(' họp', marks: {TextMark.strike, TextMark.bold}),
        ])
      ]);
      expect(b.encode(),
          '{"v":1,"blocks":[{"id":"x","type":"paragraph","runs":[{"t":"Ghi chú"},{"t":" họp","m":["bold","strike"]}]}]}');
    });

    test('two links side by side stay two; a link and plain text of the same marks do not merge', () {
      final b = DocBlock('x', BlockType.paragraph,
          runs: [TextRun('A', doc: 'd1'), TextRun('B', doc: 'd2'), TextRun('C'), TextRun('D', url: 'https://a.b')]);
      expect(b.runs.length, 4);
    });

    test('an empty run of another style does not split a run in two', () {
      final b = DocBlock('x', BlockType.paragraph,
          runs: [TextRun('Ghi '), TextRun('', marks: {TextMark.bold}), TextRun('chú')]);
      expect(b.runs, [TextRun('Ghi chú')]);
    });

    test('property: the same content always gives the same bytes, and decoding changes nothing', () {
      for (var seed = 0; seed < 200; seed++) {
        final body = _random(Random(seed));
        final once = body.encode();
        expect(DocumentBody.decode(once).encode(), once, reason: 'seed $seed');
        expect(_random(Random(seed)).encode(), once, reason: 'seed $seed: built again');
        expect(DocumentBody.decode(DocumentBody.decode(once).encode()).encode(), once);
      }
    });

    test('what is not a body is refused, never half read', () {
      for (final bad in [
        'not json',
        '[]',
        '{"blocks":[]}',
        '{"v":2,"blocks":[]}',
        '{"v":1,"blocks":[{"id":"x"}]}',
        '{"v":1,"blocks":[{"id":"x","type":"table","runs":[]}]}',
        '{"v":1,"blocks":[{"id":"x","type":"paragraph"}]}',
        '{"v":1,"blocks":[{"id":"x","type":"paragraph","runs":[{"t":"a","m":["shout"]}]}]}',
        '{"v":1,"blocks":[{"id":"x","type":"paragraph","runs":[{"t":1}]}]}',
        '{"v":1,"blocks":[{"id":"x","type":"attachment","file":{"hash":"h"}}]}',
        '{"v":1,"blocks":[{"id":"x","type":"bullet","runs":[],"indent":"2"}]}',
      ]) {
        expect(() => DocumentBody.decode(bad), throwsFormatException, reason: bad);
      }
    });

    test('the text a search indexes: every block, a file by its name', () {
      expect(sample().plainText(),
          'Chuyến đi Đà Nẵng\nĐi vào tháng Sáu. Xem Ghi chú họp và bản đồ.\nĐặt vé\nKem chống nắng\nvé máy bay.pdf\n');
    });
  });

  group('rules', () {
    test('a valid body passes; limits and shapes are checked', () {
      expect(sample().validate(), isNull);
      expect(DocumentBody.empty('b1').validate(), isNull);
      expect(DocumentBody([]).validate(), contains('at least one block'));
      expect(DocumentBody([DocBlock('a', BlockType.paragraph), DocBlock('a', BlockType.paragraph)]).validate(),
          contains('same id'));
      expect(DocumentBody([DocBlock('', BlockType.paragraph)]).validate(), contains('block id'));
      expect(DocumentBody([DocBlock('a', BlockType.bullet, indent: maxBlockIndent + 1)]).validate(), contains('indent'));
      expect(DocumentBody([DocBlock('a', BlockType.attachment)]).validate(), contains('names its file'));
      expect(
          DocumentBody([
            DocBlock('a', BlockType.attachment, attachment: const AttachmentRef(hash: 'md5:1', name: 'x', size: 1, mime: 'a/b'))
          ]).validate(),
          contains('sha256'));
      expect(
          DocumentBody([
            DocBlock('a', BlockType.paragraph, attachment: const AttachmentRef(hash: hash, name: 'x', size: 1, mime: 'a/b'))
          ]).validate(),
          contains('only an attachment'));
      expect(DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('x', doc: 'd', url: 'https://a.b')])]).validate(),
          contains('not both'));
      expect(DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('x', url: 'javascript:alert(1)')])]).validate(),
          contains('web link'));
      expect(DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('x', url: 'mailto:a@b.c')])]).validate(), isNull);
      final long = DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('x' * (maxDocumentTextLength + 1))])]);
      expect(long.validate(), contains('at most'));
      final many = DocumentBody([for (var i = 0; i <= maxDocumentBlocks; i++) DocBlock('b$i', BlockType.paragraph)]);
      expect(many.validate(), contains('blocks'));
    });

    test('titles: 1 to 200 characters after trimming', () {
      expect(documentTitleError('Ghi chú'), isNull);
      expect(documentTitleError('   '), isNotNull);
      expect(documentTitleError('x' * maxDocumentTitleLength), isNull);
      expect(documentTitleError('x' * (maxDocumentTitleLength + 1)), isNotNull);
    });

    test('DOC-001: no document goes under itself or one of its subdocuments', () {
      expect(DocumentTreeRules.moveError(docId: 'a', newParentId: null, newParentAncestorsIncludingSelf: {}), isNull);
      expect(DocumentTreeRules.moveError(docId: 'a', newParentId: 'b', newParentAncestorsIncludingSelf: {'b', 'r'}), isNull);
      expect(DocumentTreeRules.moveError(docId: 'a', newParentId: 'a', newParentAncestorsIncludingSelf: {'a'}), isNotNull);
      expect(DocumentTreeRules.moveError(docId: 'a', newParentId: 'c', newParentAncestorsIncludingSelf: {'c', 'b', 'a'}),
          isNotNull);
    });

    test('DOC-001 property: random moves checked by the rule never make a cycle', () {
      for (var seed = 0; seed < 50; seed++) {
        final rnd = Random(seed);
        final parent = <String, String?>{for (var i = 0; i < 12; i++) 'd$i': null};
        Set<String> chain(String id) {
          final out = <String>{};
          String? at = id;
          while (at != null && out.add(at)) {
            at = parent[at];
          }
          return out;
        }

        for (var step = 0; step < 80; step++) {
          final doc = 'd${rnd.nextInt(12)}';
          final to = rnd.nextInt(4) == 0 ? null : 'd${rnd.nextInt(12)}';
          final err = DocumentTreeRules.moveError(
              docId: doc, newParentId: to, newParentAncestorsIncludingSelf: to == null ? {} : chain(to));
          if (err == null) parent[doc] = to;
        }
        for (final id in parent.keys) {
          final seen = <String>{};
          String? at = id;
          while (at != null) {
            expect(seen.add(at), isTrue, reason: 'seed $seed: a cycle through $at');
            at = parent[at];
          }
        }
      }
    });

    test('DOC-003: a link resolves, or shows as in the trash or missing; it is never dropped', () {
      final docs = {'live': false, 'trashed': true};
      bool? lookup(String id) => docs[id];
      expect(resolveLink('live', lookup), LinkState.ok);
      expect(resolveLink('trashed', lookup), LinkState.inTrash);
      expect(resolveLink('gone', lookup), LinkState.missing);
      final b = DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('Cũ', doc: 'gone')])]);
      expect(DocumentBody.decode(b.encode()).blocks.single.runs.single.doc, 'gone', reason: 'kept as it was');
    });

    test('DOC-004: the tree, [[…]] links, web links and files are separate relations', () {
      final r = relationsOf(parentId: 'p', body: sample());
      expect(r.parent, 'p');
      expect(r.docLinks, {'doc-hop'});
      expect(r.webLinks, {'https://example.org/map'});
      expect(r.attachments, {hash});
      final linkedToParent = DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('Cha', doc: 'p')])]);
      final r2 = relationsOf(parentId: null, body: linkedToParent);
      expect(r2.parent, isNull, reason: 'a link to a document does not put it in the tree');
      expect(r2.docLinks, {'p'});
    });
  });

  group('backlinks', () {
    test('the sentence around each link; one entry per sentence', () {
      final b = DocumentBody([
        DocBlock('a', BlockType.paragraph, runs: [
          TextRun('Hôm qua trời mưa. Nhớ đọc '),
          TextRun('Ghi chú họp', doc: 'hop'),
          TextRun(' trước thứ Hai! Sau đó nghỉ.'),
        ]),
        DocBlock('b', BlockType.bullet, runs: [TextRun('Xem '), TextRun('họp', doc: 'hop')]),
        DocBlock('c', BlockType.paragraph, runs: [TextRun('Không liên quan', doc: 'khac')]),
      ]);
      expect(backlinkSnippets(b, 'hop'), ['Nhớ đọc Ghi chú họp trước thứ Hai!', 'Xem họp']);
      expect(backlinkSnippets(b, 'none'), isEmpty);
      final twice = DocumentBody([
        DocBlock('a', BlockType.paragraph,
            runs: [TextRun('Xem '), TextRun('họp', doc: 'hop'), TextRun(' và lại '), TextRun('họp', doc: 'hop'), TextRun('.')]),
      ]);
      expect(backlinkSnippets(twice, 'hop'), ['Xem họp và lại họp.'], reason: 'two links in one sentence: one entry');
    });

    test('a long sentence is cut around the link', () {
      final b = DocumentBody([
        DocBlock('a', BlockType.paragraph,
            runs: [TextRun('chữ ' * 100), TextRun('ĐÍCH', doc: 't'), TextRun(' chữ' * 100)])
      ]);
      final s = backlinkSnippets(b, 't').single;
      expect(s, contains('ĐÍCH'));
      expect(s.length, lessThanOrEqualTo(maxBacklinkSnippet + 2));
      expect((s.startsWith('…'), s.endsWith('…')), (true, true));
    });
  });

  group('link titles (T6, ADR-0071)', () {
    final titles = {'a': 'Ghi chú họp', 'b': 'Sách'};
    String? titleOf(String id) => titles[id];

    test('a link shows its target\'s current title; marks kept; a broken link keeps its text', () {
      final b = DocumentBody([
        DocBlock('x', BlockType.bullet, indent: 2, runs: [
          TextRun('Xem '),
          TextRun('Họp cũ', doc: 'a', marks: {TextMark.bold}),
          TextRun(' và '),
          TextRun('Đã xoá', doc: 'gone'),
        ]),
        DocBlock('y', BlockType.todo, checked: true, runs: [TextRun('Sách', doc: 'b'), TextRun(' web', url: 'https://x.vn')]),
      ]);
      final out = withLinkTitles(b, titleOf);
      expect(out.blocks[0].runs.map((r) => (r.text, r.doc, r.marks.map((m) => m.name).join())).toList(), [
        ('Xem ', null, ''),
        ('Ghi chú họp', 'a', 'bold'),
        (' và ', null, ''),
        ('Đã xoá', 'gone', ''),
      ]);
      expect((out.blocks[0].type, out.blocks[0].indent, out.blocks[1].checked), (BlockType.bullet, 2, true));
      expect(identical(withLinkTitles(out, titleOf), out), isTrue, reason: 'nothing to change: the same body');
      expect(out.blocks[1].runs.last.url, 'https://x.vn');
    });

    test('a title that would make the body too long leaves it as it was', () {
      final long = 'x' * (maxDocumentTextLength - 1);
      final b = DocumentBody([
        DocBlock('x', BlockType.paragraph, runs: [TextRun(long), TextRun('a', doc: 'a')]),
      ]);
      expect(identical(withLinkTitles(b, titleOf), b), isTrue);
    });
  });

  // P06b W4: the assistant's chat searches a whole question by any word.
  group('a question searched (P06b W4)', () {
    test('any of its words; common words and punctuation left out', () {
      expect(searchAnyQueryOf('Tôi có việc gì về thuế không?'), '"thuế"');
      expect(searchAnyQueryOf('Khi nào họp tổ dân phố?'), '"họp" OR "tổ" OR "dân" OR "phố"');
      expect(searchAnyQueryOf('What is in my tax return?'), '"tax" OR "return"');
      expect(searchAnyQueryOf('Gì vậy?'), isNull);
      expect(searchAnyQueryOf(''), isNull);
    });

    test('each word once, numbers kept, FTS syntax cannot break it, at most 12 words', () {
      expect(searchAnyQueryOf('Thuế thuế THUẾ 2026 năm 5'), '"Thuế" OR "2026" OR "năm" OR "5"');
      expect(searchAnyQueryOf('NEAR(xy) "yz" a*b'), '"NEAR" OR "xy" OR "yz"');
      final many = List.generate(20, (i) => 'từ$i').join(' ');
      expect(searchAnyQueryOf(many)!.split(' OR '), hasLength(12));
    });
  });
  group('search query (C4)', () {
    test('words must all be there; the last may be the start of a word', () {
      expect(searchQueryOf('ghi chú'), '"ghi" "chú"*');
      expect(searchQueryOf('ghi chú '), '"ghi" "chú"');
      expect(searchQueryOf('  '), isNull);
      expect(searchQueryOf(''), isNull);
    });

    test('quotes make a phrase; quotes and FTS syntax in words cannot break the query', () {
      expect(searchQueryOf('"ghi chú" họp'), '"ghi chú" "họp"*');
      expect(searchQueryOf('"ghi chú"'), '"ghi chú"');
      expect(searchQueryOf('a"b'), '"a" "b"*');
      expect(searchQueryOf('NEAR(x) OR y*'), '"NEAR(x)" "OR" "y*"*');
    });
  });
}

DocumentBody _random(Random rnd) {
  const words = ['Ghi', 'chú', 'họp', 'Đà', 'Nẵng', 'ăn', 'sách', ' ', '. ', '', 'quan trọng'];
  final blocks = <DocBlock>[];
  for (var i = 0; i < 1 + rnd.nextInt(12); i++) {
    final type = BlockType.values[rnd.nextInt(BlockType.values.length)];
    if (type == BlockType.attachment) {
      blocks.add(DocBlock('b$i', type,
          attachment: AttachmentRef(hash: hash, name: 'f$i.png', size: rnd.nextInt(9999), mime: 'image/png')));
      continue;
    }
    final runs = [
      for (var j = 0; j < rnd.nextInt(6); j++)
        TextRun(words[rnd.nextInt(words.length)],
            marks: {for (final m in TextMark.values) if (rnd.nextInt(4) == 0) m},
            doc: rnd.nextInt(5) == 0 ? 'd${rnd.nextInt(3)}' : null),
    ];
    blocks.add(DocBlock('b$i', type, runs: runs, checked: rnd.nextBool(), indent: rnd.nextInt(3)));
  }
  return DocumentBody(blocks);
}
