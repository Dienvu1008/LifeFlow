// P05b T2 (ADR-0077; p05b-plan.md D3): the text of the PDFs on this device,
// for the one search ("in file.pdf, page 3").
//   when     a PDF is read when it is added on this device, and when the
//            app finds one a document names that is here and not read yet
//            (at the start of a session); one at a time
//   what     each page's text, in NFC as all search text, by the file's hash
//            (pdf_text_fts); a file with a password or that PDFium cannot
//            open is noted (pdf_text_state) and not tried again; a scan has
//            pages without text (no OCR)
//   where    the profile's own store, encrypted like the rest; device-only:
//            not synced, not exported. A file elsewhere is never read
//   how long as long as the file is on this device: once it is gone (the
//            sweep), its text is dropped
//   found    only through a live document of the shown space that names
//            the file (document_file_index, kept by catchUpSearch)
import 'dart:async';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdfrx;

import 'app_database.dart';
import 'search_index.dart';

enum PdfTextStatus { indexed, locked, unreadable }

/// What reading a PDF gave: its pages' text when [status] is indexed.
class PdfText {
  const PdfText(this.status, [this.pages = const []]);
  final PdfTextStatus status;
  final List<String> pages;
}

/// Reads a PDF's text; null when it could not be tried now (no engine).
typedef PdfTextReader = Future<PdfText?> Function(Uint8List bytes);

var _reads = 0;

/// The text of each page of [bytes], with PDFium (pdfrx_engine), from
/// memory. The engine must be started (the app starts it before a session;
/// tests call `pdfrxInitialize`).
Future<PdfText?> readPdfText(Uint8List bytes) async {
  pdfrx.PdfDocument? doc;
  try {
    doc = await pdfrx.PdfDocument.openData(bytes, sourceName: 'lifeflow-text-${_reads++}');
    final pages = <String>[];
    for (final p in doc.pages) {
      pages.add((await p.loadText())?.fullText ?? '');
    }
    return PdfText(PdfTextStatus.indexed, pages);
  } on pdfrx.PdfPasswordException {
    return const PdfText(PdfTextStatus.locked);
  } on pdfrx.PdfException {
    return const PdfText(PdfTextStatus.unreadable);
  } on Object {
    return null; // the engine is not there: try again in a later session
  } finally {
    await doc?.dispose();
  }
}

class PdfTextIndex {
  PdfTextIndex(this.db, this.files, {PdfTextReader? read}) : _read = read ?? readPdfText;
  final AppDatabase db;
  final AttachmentService files;
  final PdfTextReader _read;
  Future<void> _queue = Future.value();

  /// Completes when the reads started so far are done (search waits for it,
  /// so a PDF just added is found).
  Future<void> get idle => _queue;

  Future<void> _serial(Future<void> Function() f) {
    final next = _queue.then((_) => f()).catchError((Object _) {});
    _queue = next;
    return next;
  }

  /// A file just kept on this device: read now if it is a PDF.
  Future<void> added(AttachmentRef file, Uint8List bytes) =>
      fileViewOf(file) == FileView.pdf ? _serial(() => _index(file.hash, bytes)) : Future.value();

  /// Reads the PDFs documents name that are here and not read yet, and
  /// drops the text of files no longer here. Returns how many were read.
  Future<int> catchUp() async {
    var read = 0;
    await _serial(() async {
      await catchUpSearch(db);
      final known = {for (final r in await db.select(db.pdfTextState).get()) r.hash};
      for (final h in known) {
        if (await files.availability(h) != AttachmentAvailability.here) await _drop(h);
      }
      final named = [
        for (final r in await db.customSelect('SELECT DISTINCT hash FROM document_file_index ORDER BY hash').get())
          r.read<String>('hash'),
      ];
      for (final h in named) {
        if (known.contains(h)) continue;
        final c = await files.open(h);
        final bytes = c.bytes;
        if (bytes == null) continue; // elsewhere, or unreadable: never read
        if (await _index(h, bytes)) read++;
      }
    });
    return read;
  }

  Future<bool> _index(String hash, Uint8List bytes) async {
    if (await (db.select(db.pdfTextState)..where((s) => s.hash.equals(hash))).getSingleOrNull() != null) return false;
    final t = await _read(bytes);
    if (t == null) return false;
    await db.transaction(() async {
      await db.customStatement('DELETE FROM pdf_text_fts WHERE hash = ?', [hash]);
      for (var i = 0; i < t.pages.length; i++) {
        final text = searchForm(t.pages[i]);
        if (text.trim().isEmpty) continue;
        await db.customStatement('INSERT INTO pdf_text_fts(text, hash, page) VALUES (?, ?, ?)', [text, hash, i + 1]);
      }
      await db.into(db.pdfTextState).insertOnConflictUpdate(
          PdfTextStateCompanion.insert(hash: hash, status: t.status.name, pages: t.pages.length));
    });
    return true;
  }

  Future<void> _drop(String hash) => db.transaction(() async {
        await db.customStatement('DELETE FROM pdf_text_fts WHERE hash = ?', [hash]);
        await (db.delete(db.pdfTextState)..where((s) => s.hash.equals(hash))).go();
      });
}

/// The attachment service that also reads each PDF kept (ADR-0077).
class PdfIndexingAttachments implements AttachmentService {
  PdfIndexingAttachments(this.inner, this.index);
  final AttachmentService inner;
  final PdfTextIndex index;

  @override
  Future<AttachmentAdded> add(Uint8List bytes, {required String name, required String mime}) async {
    final r = await inner.add(bytes, name: name, mime: mime);
    final ref = r.ref;
    if (ref != null) unawaited(index.added(ref, bytes));
    return r;
  }

  @override
  Future<AttachmentAvailability> availability(String hash) => inner.availability(hash);

  @override
  Future<AttachmentContent> open(String hash) => inner.open(hash);

  @override
  Future<int> sweep({Duration grace = const Duration(days: 1)}) => inner.sweep(grace: grace);
}
