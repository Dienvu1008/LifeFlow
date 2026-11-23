// P05b T2 (ADR-0077; p05b-plan.md D3): the text of this device's PDFs in the
// one search, on the real store with real PDFs (PDFium).
//   found       a Vietnamese word on page 2 of a PDF kept in a document:
//               "in file.pdf, page 2", with its passage; by the exact
//               spelling, whichever way the marks were typed
//   where       only through a live document of the shown space that names
//               the file: not from the trash, not from another space, not
//               after the file is taken out of the document
//   when        read as it is added; at the start of a session for one not
//               read yet; never a file that is elsewhere
//   how long    the text goes when the file leaves the device
//   noted       a PDF with a password or a damaged one is not read again; no
//               engine: tried again later
//   upgrade     v16 -> v17 lists the files of existing documents
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

import 'profile_harness.dart';

const me = 'acc-me';
const space = '30000000-0000-4000-8000-0000000000aa';

/// A real PDF with one page per text, in an embedded Vietnamese font.
Future<Uint8List> pdfOf(List<String> pages) async {
  final font = pw.Font.ttf(File('../ui/fonts/BeVietnamPro/BeVietnamPro-400.ttf').readAsBytesSync().buffer.asByteData());
  final doc = pw.Document();
  for (final text in pages) {
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a5, build: (_) => pw.Text(text, style: pw.TextStyle(font: font, fontSize: 14))));
  }
  return doc.save();
}

class _Counting implements AttachmentService {
  _Counting(this.inner, this.opened);
  final AttachmentService inner;
  final List<String> opened;
  @override
  Future<AttachmentAdded> add(Uint8List bytes, {required String name, required String mime}) => inner.add(bytes, name: name, mime: mime);
  @override
  Future<AttachmentAvailability> availability(String hash) => inner.availability(hash);
  @override
  Future<AttachmentContent> open(String hash) {
    opened.add(hash);
    return inner.open(hash);
  }

  @override
  Future<int> sweep({Duration grace = const Duration(days: 1)}) => inner.sweep(grace: grace);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => pdfrxInitialize(tmpPath: Directory.systemTemp.path));

  late Directory base;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late FixedClock clock;
  late DriftDocumentService docs;
  late DriftAttachmentService store;
  late PdfTextIndex index;
  late AttachmentService files;
  late DriftSearchQueries search;
  late DriftSpaceService spaces;
  late String personal;
  late Uint8List invoice;

  setUpAll(() async {
    invoice = await pdfOf(['Hóa đơn tiền điện tháng 11', 'Biên bản họp tổ dân phố ở Đà Nẵng', 'Ký tên']);
  });

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_pdf_search_');
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    final p = await ProfileStore(db).ensureFirstProfile();
    personal = p.activeWorkspaceId.value;
    await (db.update(db.profiles)..where((x) => x.id.equals(p.profileId.value)))
        .write(const ProfilesCompanion(accountId: Value(me), accountProvider: Value('github')));
    await ProfileStore(db).cacheSpace(const SpaceSnapshot(
        workspaceId: space, ownerAccountId: me, name: 'Family', members: [SpaceMemberSnapshot(accountId: me, role: 'owner')]));
    clock = FixedClock(Instant(DateTime.utc(2026, 11, 4, 9)));
    docs = DriftDocumentService(db, gw, clock: clock, deviceId: 'windows');
    store = DriftAttachmentService(db, folder: Directory('${base.path}/p1.files'), keys: MemoryKeys()('lifeflow.attach.key.p1'));
    index = PdfTextIndex(db, store);
    files = PdfIndexingAttachments(store, index);
    search = DriftSearchQueries(db, pdfs: index);
    spaces = DriftSpaceService(db, gw);
  });

  tearDown(() async {
    await index.idle;
    await db.close();
    base.deleteSync(recursive: true);
  });

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
    return (r as CommandOk).entityId;
  }

  DocumentBody withFile(AttachmentRef f, [String text = 'Xem tệp']) => DocumentBody([
        DocBlock('a', BlockType.paragraph, runs: [TextRun(text)]),
        DocBlock('f', BlockType.attachment, attachment: f),
      ]);

  Future<String> docWith(String title, AttachmentRef f) async {
    final id = ok(await docs.create(title));
    ok(await docs.save(id, title: title, body: withFile(f)));
    return id;
  }

  Future<AttachmentRef> keep(AttachmentService s, Uint8List bytes, [String name = 'biên bản.pdf']) async =>
      (await s.add(bytes, name: name, mime: 'application/pdf')).ref!;

  Future<List<String>> found(String typed) async => [
        for (final h in (await search.search(typed)).files) '${h.documentTitle} | ${h.file.name} | ${h.page}',
      ];

  test('a Vietnamese word on page 2 of a PDF just added: "in file.pdf, page 2", with its passage', () async {
    final f = await keep(files, invoice);
    final d = await docWith('Họp tháng 11', f);
    final r = await search.search('họp tổ');
    expect(r.files, hasLength(1));
    final h = r.files.single;
    expect((h.documentId, h.documentTitle, h.file.hash, h.file.name, h.page), (d, 'Họp tháng 11', f.hash, 'biên bản.pdf', 2));
    expect(h.passage, contains('Biên bản họp tổ dân phố'));
    expect([for (final m in h.matches) h.passage.substring(m.start, m.end)], ['họp', 'tổ']);
    expect(r.documents, isEmpty, reason: 'the words are in the PDF, not in the document');
    expect(await found('Đà Nẵng'), ['Họp tháng 11 | biên bản.pdf | 2']);
    expect(await found('tiền điện'), ['Họp tháng 11 | biên bản.pdf | 1']);
  });

  test('by the exact spelling: marks typed any way are found; other marks are not', () async {
    await docWith('Họp', await keep(files, invoice));
    const nfd = 'ho\u0323p'; // "họp" decomposed
    const half = 't\u00f4\u0309'; // "tổ": ô precomposed, its tone mark apart
    expect(await found(nfd), ['Họp | biên bản.pdf | 2']);
    expect(await found(half), ['Họp | biên bản.pdf | 2']);
    expect(await found('tổ'), ['Họp | biên bản.pdf | 2']);
    expect(await found('HỌP'), ['Họp | biên bản.pdf | 2'], reason: 'case is ignored');
    expect(await found('hop'), isEmpty, reason: 'without its mark it is another word');
    expect(await found('hợp'), isEmpty);
  });

  test('only through a live document of the shown space that names the file', () async {
    final f = await keep(files, invoice);
    final d = await docWith('Họp', f);
    expect(await found('Đà Nẵng'), hasLength(1));
    ok(await docs.trash(d));
    expect(await found('Đà Nẵng'), isEmpty, reason: 'in the trash');
    ok(await docs.restore(d));
    expect(await found('Đà Nẵng'), hasLength(1));
    ok(await docs.save(d, title: 'Họp', body: DocumentBody([DocBlock('a', BlockType.paragraph, runs: [TextRun('Không còn tệp')])])));
    expect(await found('Đà Nẵng'), isEmpty, reason: 'the file was taken out');

    ok(await spaces.show(space));
    await docWith('Tổ dân phố', f);
    expect(await found('Đà Nẵng'), ['Tổ dân phố | biên bản.pdf | 2']);
    ok(await spaces.show(personal));
    expect(await found('Đà Nẵng'), isEmpty, reason: 'the space is not shown');
  });

  test('the same PDF in two documents: a hit for each; its own name in each', () async {
    final f = await keep(files, invoice);
    await docWith('Một', f);
    final again = await keep(files, invoice, 'bản sao.pdf');
    expect(again.hash, f.hash);
    await docWith('Hai', again);
    expect(await found('Đà Nẵng'), unorderedEquals(['Một | biên bản.pdf | 2', 'Hai | bản sao.pdf | 2']));
  });

  test('a file elsewhere is never read; one not read yet is read at the next session start, once', () async {
    final elsewhere = AttachmentRef(hash: 'sha256:${'b' * 64}', name: 'ở máy khác.pdf', size: 10, mime: 'application/pdf');
    await docWith('Khác', elsewhere);
    var reads = 0;
    final opened = <String>[];
    final counting = PdfTextIndex(db, _Counting(store, opened), read: (_) async {
      reads++;
      return const PdfText(PdfTextStatus.indexed, ['x']);
    });
    expect(await counting.catchUp(), 0);
    expect(reads, 0, reason: 'a file elsewhere is never read');
    expect(opened, [elsewhere.hash], reason: 'looked for, not there');
    expect(await db.select(db.pdfTextState).get(), isEmpty, reason: 'nothing noted: it may come later');

    // Kept without being read (as a restore keeps files).
    final f = await keep(store, invoice);
    await docWith('Họp', f);
    expect(await found('Đà Nẵng'), isEmpty);
    expect(await index.catchUp(), 1);
    expect(await found('Đà Nẵng'), ['Họp | biên bản.pdf | 2']);
    expect(await index.catchUp(), 0, reason: 'read once');
    opened.clear();
    expect(await counting.catchUp(), 0);
    expect(reads, 0);
    expect(opened, [elsewhere.hash], reason: 'a file read before is not even decrypted again');
    final states = await db.select(db.pdfTextState).get();
    expect([for (final s in states) (s.hash, s.status, s.pages)], [(f.hash, 'indexed', 3)]);
  });

  test('the text goes when the file leaves the device', () async {
    final f = await keep(files, invoice);
    await docWith('Họp', f);
    expect(await found('Đà Nẵng'), hasLength(1));
    for (final x in Directory('${base.path}/p1.files').listSync().whereType<File>()) {
      x.deleteSync();
    }
    await index.catchUp();
    expect(await found('Đà Nẵng'), isEmpty);
    expect(await db.customSelect('SELECT COUNT(*) AS n FROM pdf_text_fts').getSingle().then((r) => r.read<int>('n')), 0);
    expect(await db.select(db.pdfTextState).get(), isEmpty);
  });

  test('a damaged PDF, one with a password: noted, not read again; no engine: tried again later', () async {
    final damaged = await keep(files, Uint8List.fromList('%PDF-1.4 not really'.codeUnits), 'hỏng.pdf');
    await docWith('Hỏng', damaged);
    await index.idle;
    final s = await (db.select(db.pdfTextState)..where((x) => x.hash.equals(damaged.hash))).getSingle();
    expect(s.status, 'unreadable');

    var calls = 0;
    PdfText? answer = const PdfText(PdfTextStatus.locked);
    final fake = PdfTextIndex(db, store, read: (_) async {
      calls++;
      return answer;
    });
    final locked = await keep(store, await pdfOf(['Mật']), 'khóa.pdf');
    await docWith('Khóa', locked);
    expect(await fake.catchUp(), 1);
    expect(await fake.catchUp(), 0);
    expect(calls, 1, reason: 'not tried again');

    answer = null; // no engine
    final later = await keep(store, await pdfOf(['Sau']), 'sau.pdf');
    await docWith('Sau', later);
    expect(await fake.catchUp(), 0);
    answer = const PdfText(PdfTextStatus.indexed, ['Sau này']);
    expect(await fake.catchUp(), 1, reason: 'tried again');
  });

  test('a PDF whose text comes back decomposed is indexed in NFC; the same PDF kept twice is read once', () async {
    var calls = 0;
    final fake = PdfTextIndex(db, store, read: (_) async {
      calls++;
      return const PdfText(PdfTextStatus.indexed, ['Bie\u0302n ba\u0309n ho\u0323p']); // NFD
    });
    final s = DriftSearchQueries(db, pdfs: fake);
    final kept = PdfIndexingAttachments(store, fake);
    final f = await keep(kept, invoice);
    await keep(kept, invoice, 'lần hai.pdf');
    await docWith('Họp', f);
    await fake.idle;
    expect(calls, 1);
    expect([for (final h in (await s.search('biên bản họp')).files) h.page], [1]);
  });

  test('a picture or another file is not read', () async {
    var calls = 0;
    final fake = PdfTextIndex(db, store, read: (_) async {
      calls++;
      return const PdfText(PdfTextStatus.indexed, ['x']);
    });
    final png = (await store.add(Uint8List.fromList([1, 2, 3]), name: 'ảnh.png', mime: 'image/png')).ref!;
    final docx = (await store.add(Uint8List.fromList([4, 5]), name: 'tờ khai.docx', mime: 'application/octet-stream')).ref!;
    await docWith('Ảnh', png);
    await docWith('Tờ khai', docx);
    await fake.added(png, Uint8List.fromList([1, 2, 3]));
    expect(await fake.catchUp(), 0);
    expect(calls, 0);
  });

  test('device-only: the PDF text tables are not exported', () {
    expect(notExportedTables, containsAll(['documentFileIndex', 'pdfTextState']));
    expect(exportedTables, isNot(contains('documentFileIndex')));
  });

  test('v16 -> v17: the files of existing documents are listed and their PDFs read', () async {
    final file = File('${base.path}/old.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    final oldGw = DriftCommandGateway(old, WorkspaceOwnerAuthorization(old));
    await ProfileStore(old).ensureFirstProfile();
    final oldFiles = DriftAttachmentService(old, folder: Directory('${base.path}/old.files'), keys: MemoryKeys()('k'));
    final f = (await oldFiles.add(invoice, name: 'cũ.pdf', mime: 'application/pdf')).ref!;
    final oldDocs = DriftDocumentService(old, oldGw, clock: clock, deviceId: 'windows');
    final id = ok(await oldDocs.create('Cũ'));
    ok(await oldDocs.save(id, title: 'Cũ', body: withFile(f)));
    await DriftSearchQueries(old).search('cũ'); // v16 caught up: nothing left pending
    await rewindProfileStore(old, 16);
    await old.customStatement('PRAGMA user_version = 16');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final idx = PdfTextIndex(upgraded, oldFiles);
    expect(await idx.catchUp(), 1);
    final r = await DriftSearchQueries(upgraded, pdfs: idx).search('Đà Nẵng');
    expect([for (final h in r.files) (h.documentTitle, h.file.name, h.page)], [('Cũ', 'cũ.pdf', 2)]);
  });
}
