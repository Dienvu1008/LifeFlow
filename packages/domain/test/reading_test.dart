// P05b T4 (ADR-0078): what is read aloud, sentence by sentence.
//   sentences  ends at . ! ? … before a space or the end, closers kept, line
//              breaks; not inside numbers or names; spaces left out
//   offsets    each sentence is exactly its block's text between them
//   long       cut at a comma, else a space, never over the limit
//   blocks     every kind with text, in order; files skipped; empty skipped
//   language   Vietnamese or English from the letters (NFC or decomposed)
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

DocBlock p(String id, String text, [BlockType type = BlockType.paragraph]) => DocBlock(id, type, runs: [TextRun(text)]);

List<String> texts(String text) => [for (final s in sentencesOf('b', text)) s.text];

void main() {
  group('sentences', () {
    test('end at . ! ? … before a space or the end; closing quotes and brackets stay', () {
      expect(texts('Chào anh. Hôm nay trời đẹp! Đi chơi không? Có lẽ… để mai.'),
          ['Chào anh.', 'Hôm nay trời đẹp!', 'Đi chơi không?', 'Có lẽ…', 'để mai.']);
      expect(texts('Anh nói: “Đi thôi.” Rồi đi. (Thật vậy.) Hết'), ['Anh nói: “Đi thôi.”', 'Rồi đi.', '(Thật vậy.)', 'Hết']);
      expect(texts('Wait... what?! Yes.'), ['Wait...', 'what?!', 'Yes.']);
    });

    test('not inside a number, a web address or a file name', () {
      expect(texts('Giá 3.500 đồng, xem lifeflow.app hoặc bảng.pdf nhé. Xong.'),
          ['Giá 3.500 đồng, xem lifeflow.app hoặc bảng.pdf nhé.', 'Xong.']);
    });

    test('a line break ends a sentence; blank lines and spaces are left out', () {
      expect(texts('  dòng một\n\n  dòng hai  \nba.  '), ['dòng một', 'dòng hai', 'ba.']);
      expect(texts('   '), isEmpty);
      expect(texts(''), isEmpty);
    });

    test('offsets give back exactly the sentence, on random text', () {
      final r = Random(7);
      const pieces = ['Một', 'hai', 'ba.', 'bốn!', '“năm?”', '…', ' ', '  ', '\n', '3.5', 'x.y', '(sáu.)'];
      for (var n = 0; n < 300; n++) {
        final text = [for (var k = 0; k < r.nextInt(30); k++) pieces[r.nextInt(pieces.length)]].join(r.nextBool() ? ' ' : '');
        var last = 0;
        for (final s in sentencesOf('b', text)) {
          expect(text.substring(s.start, s.end), s.text);
          expect(s.text.trim(), s.text, reason: 'no spaces around: "$text"');
          expect(s.text.contains('\n'), isFalse);
          expect(s.start, greaterThanOrEqualTo(last), reason: 'in order, not overlapping');
          last = s.end;
        }
        // Nothing but spaces is left out.
        final kept = sentencesOf('b', text).map((s) => s.text).join();
        expect(kept.replaceAll(RegExp(r'\s'), ''), text.replaceAll(RegExp(r'\s'), ''));
      }
    });

    test('a very long sentence is cut at a comma, else a space, never over the limit', () {
      final clause = 'một vế câu khá dài để đọc lên, ';
      final long = '${clause * 30}kết thúc.';
      final parts = sentencesOf('b', long);
      expect(parts.length, greaterThan(1));
      for (final s in parts) {
        expect(s.text.length, lessThanOrEqualTo(maxReadingSentenceLength));
        expect(long.substring(s.start, s.end), s.text);
      }
      expect(parts.first.text, endsWith(','), reason: 'cut after a comma');
      final words = '${'chữ ' * 120}hết';
      for (final s in sentencesOf('b', words)) {
        expect(s.text.length, lessThanOrEqualTo(maxReadingSentenceLength));
        expect(s.text, isNot(startsWith(' ')));
      }
      final solid = 'x' * 700;
      expect([for (final s in sentencesOf('b', solid)) s.text.length], [300, 300, 100]);
    });
  });

  group('a document', () {
    test('every block with text in order, whatever its kind; files and empty blocks skipped', () {
      final body = DocumentBody([
        p('h', 'Họp tổ', BlockType.heading1),
        p('a', 'Chín giờ sáng. Ở nhà văn hoá.'),
        DocBlock('f', BlockType.attachment,
            attachment: const AttachmentRef(hash: 'sha256:0', name: 'biên bản.pdf', size: 1, mime: 'application/pdf')),
        p('e', '   '),
        p('l', 'Mang ghế', BlockType.bullet),
        p('t', 'Gọi anh Ba', BlockType.todo),
        p('q', 'Đoàn kết là sức mạnh.', BlockType.quote),
        p('c', 'x = 1\ny = 2', BlockType.code),
      ]);
      expect(readingOf(body), [
        const ReadingSentence(blockId: 'h', start: 0, end: 6, text: 'Họp tổ'),
        const ReadingSentence(blockId: 'a', start: 0, end: 14, text: 'Chín giờ sáng.'),
        const ReadingSentence(blockId: 'a', start: 15, end: 29, text: 'Ở nhà văn hoá.'),
        const ReadingSentence(blockId: 'l', start: 0, end: 8, text: 'Mang ghế'),
        const ReadingSentence(blockId: 't', start: 0, end: 10, text: 'Gọi anh Ba'),
        const ReadingSentence(blockId: 'q', start: 0, end: 21, text: 'Đoàn kết là sức mạnh.'),
        const ReadingSentence(blockId: 'c', start: 0, end: 5, text: 'x = 1'),
        const ReadingSentence(blockId: 'c', start: 6, end: 11, text: 'y = 2'),
      ]);
    });

    test('a sentence across runs (bold, a link) is one sentence, offsets in the joined text', () {
      final body = DocumentBody([
        DocBlock('a', BlockType.paragraph, runs: [
          TextRun('Xem '),
          TextRun('Kế hoạch', doc: 'd2'),
          TextRun(' trước. ', marks: {TextMark.bold}),
          TextRun('Rồi gọi.'),
        ]),
      ]);
      expect([for (final s in readingOf(body)) (s.start, s.end, s.text)], [(0, 19, 'Xem Kế hoạch trước.'), (20, 28, 'Rồi gọi.')]);
    });
  });

  group('language', () {
    DocumentBody of(String s) => DocumentBody([p('a', s)]);
    test('Vietnamese from its letters, typed composed or decomposed; English otherwise', () {
      expect(readingLanguageOf(of('Hôm nay họp tổ dân phố lúc chín giờ.')), 'vi');
      expect(readingLanguageOf(of('Ho\u0302m nay ho\u0323p to\u0302\u0309 da\u0302n pho\u0302\u0301')), 'vi');
      expect(readingLanguageOf(of('Meeting at nine with the team about the plan.')), 'en');
      expect(readingLanguageOf(of('Toi di hoc')), 'en', reason: 'without marks it cannot be told');
      expect(readingLanguageOf(DocumentBody([])), 'en');
    });

    test('a few Vietnamese words in English text stay English; one in seven makes it Vietnamese', () {
      expect(readingLanguageOf(of('We ate phở at a small place near the river with many friends today')), 'en');
      expect(readingLanguageOf(of('We ate phở and bún at the river')), 'vi');
    });
  });

  group('a PDF (P05b T5)', () {
    test('lines are joined, a hyphenated word too; a blank line still ends a sentence', () {
      expect(pdfReadingText('Biên bản họp tổ\r\ndân phố ở Đà\nNẵng\n\nNgày 4 tháng 11'),
          'Biên bản họp tổ dân phố ở Đà Nẵng\nNgày 4 tháng 11');
      expect(pdfReadingText('the infor-\nmation is here.\n  \n\nNext'), 'the information is here.\nNext');
      expect(pdfReadingText('Đà Nẵng -\nHội An'), 'Đà Nẵng - Hội An', reason: 'a dash between words is kept');
      expect(pdfReadingText('Hà Nội-\nHuế'), 'Hà Nội- Huế', reason: 'a capital after: not a cut word');
      expect(texts(pdfReadingText('Một câu\ntrên hai dòng. Câu khác.')), ['Một câu trên hai dòng.', 'Câu khác.']);
    });

    test('pages from the one shown, one block each, and back to their page', () {
      final body = pdfReadingBody(['Trang ba.', 'Trang\nbốn.'], first: 3);
      expect([for (final s in readingOf(body)) (pageOfReadingBlock(s.blockId), s.text)], [(3, 'Trang ba.'), (4, 'Trang bốn.')]);
      expect(pageOfReadingBlock('b1'), isNull);
      expect(readingOf(pdfReadingBody(['', '  '])), isEmpty, reason: 'a scan has no text');
    });
  });
}
