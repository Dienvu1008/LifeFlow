// P05b T1 (ADR-0076): what the PDF page asks of a PDF view. The app uses
// pdfrx (pdf_adapter.dart, the only file that knows it); widget tests use a
// fake through [pdfViewBuilderProvider].
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pdf_adapter.dart';

/// Why a PDF did not open.
enum PdfOpenFailure {
  /// It has a password and none (or no right one) was given.
  passwordNeeded,

  /// Damaged, or not a PDF.
  unreadable,
}

/// A shown PDF: pages, zoom, find and the selected text. Notifies when the
/// page, the matches or the selection change.
abstract class PdfViewControls implements Listenable {
  int get pageCount;

  /// The page shown (1 to [pageCount]).
  int get pageNumber;
  Future<void> goToPage(int pageNumber);

  Future<void> zoomIn();
  Future<void> zoomOut();

  /// Finds [text] in the whole PDF (ignoring case) and shows the first match;
  /// an empty text clears the matches.
  void find(String text);
  Future<void> nextMatch();
  Future<void> previousMatch();

  /// The matches found so far (more may follow while [isFinding]).
  int get matchCount;

  /// The match shown (0-based), or null.
  int? get matchIndex;
  bool get isFinding;

  /// Whether text is selected.
  bool get hasSelection;

  /// Whether the PDF allows copying its text (its permissions).
  bool get copyAllowed;

  /// The selected text, or null when nothing is selected.
  Future<String?> selectedText();
}

/// What the PDF page gives a PDF view.
class PdfViewSetup {
  const PdfViewSetup({
    required this.bytes,
    required this.sourceName,
    required this.initialPage,
    required this.password,
    required this.onReady,
    required this.onFailed,
  });

  /// The file, in memory only (ADR-0072: nothing is written to disk).
  final Uint8List bytes;

  /// Names the file for the engine's caches; unique per content (its hash).
  final String sourceName;

  /// The page to show first (clamped to the PDF's pages).
  final int initialPage;

  /// Asked for when the PDF has a password; [wrong] after a wrong one.
  /// Null: the person gave up.
  final Future<String?> Function({required bool wrong}) password;
  final void Function(PdfViewControls controls) onReady;
  final void Function(PdfOpenFailure failure) onFailed;
}

typedef PdfViewBuilder = Widget Function(BuildContext context, PdfViewSetup setup);

/// The PDF view used by the PDF page: pdfrx unless overridden (tests).
final pdfViewBuilderProvider = Provider<PdfViewBuilder>((ref) => buildPdfrxView);

/// Prepares the PDF engine. Call once at startup, before a PDF is shown.
Future<void> initPdfViewer() => initPdfrx();
