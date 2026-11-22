// P05b T1 (ADR-0076; S-08, ADR-0075): the only place that knows pdfrx. The
// PDF page talks to [PdfViewControls] (pdf_view.dart); this file makes one
// from pdfrx's viewer, controller and text searcher.
//   bytes      the file opens from memory (PdfViewer.data), never from a path:
//              nothing of it is written to disk (ADR-0072). pdfrx's cache
//              folder only holds fonts.
//   password   pdfrx first tries none, then asks [PdfViewSetup.password]
//              until it is right or the person gives up
//   find       pdfrx's searcher, ignoring case, matches painted on the pages
//   links      a link in a PDF does nothing (nothing leaves the device)
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_view.dart';

/// pdfrx's start-up (the PDFium library, its cache folder).
Future<void> initPdfrx() => pdfrxFlutterInitialize();

/// The pdfrx view of [setup].
Widget buildPdfrxView(BuildContext context, PdfViewSetup setup) =>
    _PdfrxView(key: ValueKey(setup.sourceName), setup: setup);

class _PdfrxView extends StatefulWidget {
  const _PdfrxView({super.key, required this.setup});
  final PdfViewSetup setup;

  @override
  State<_PdfrxView> createState() => _PdfrxViewState();
}

class _PdfrxViewState extends State<_PdfrxView> {
  final _controller = PdfViewerController();
  late final _searcher = PdfTextSearcher(_controller);
  _PdfrxControls? _controls;
  var _asked = 0;
  var _reported = false;

  @override
  void dispose() {
    _controls?.dispose();
    _searcher.dispose();
    super.dispose();
  }

  void _failed(Object error) {
    if (_reported) return;
    _reported = true;
    final failure = error is PdfPasswordException ? PdfOpenFailure.passwordNeeded : PdfOpenFailure.unreadable;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.setup.onFailed(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.setup;
    return PdfViewer.data(
      s.bytes,
      sourceName: s.sourceName,
      controller: _controller,
      initialPageNumber: s.initialPage < 1 ? 1 : s.initialPage,
      passwordProvider: () => s.password(wrong: _asked++ > 0),
      params: PdfViewerParams(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
        onViewerReady: (document, controller) {
          final c = _PdfrxControls(controller, _searcher, document);
          _controls = c;
          s.onReady(c);
        },
        onPageChanged: (n) => _controls?._pageChanged(n),
        textSelectionParams: PdfTextSelectionParams(onTextSelectionChange: (t) => _controls?._selectionChanged(t)),
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          _failed(error);
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _PdfrxControls extends ChangeNotifier implements PdfViewControls {
  _PdfrxControls(this._c, this._searcher, PdfDocument document)
      : _page = _c.pageNumber ?? 1,
        _copyAllowed = document.permissions?.allowsCopying != false {
    _searcher.addListener(notifyListeners);
  }

  final PdfViewerController _c;
  final PdfTextSearcher _searcher;
  int _page;
  final bool _copyAllowed;
  PdfTextSelection? _selection;

  void _pageChanged(int? n) {
    if (n == null || n == _page) return;
    _page = n;
    notifyListeners();
  }

  void _selectionChanged(PdfTextSelection s) {
    _selection = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _searcher.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  int get pageCount => _c.pageCount;

  @override
  int get pageNumber => _page;

  @override
  Future<void> goToPage(int pageNumber) => _c.goToPage(pageNumber: pageNumber.clamp(1, pageCount));

  @override
  Future<void> zoomIn() => _c.zoomUp();

  @override
  Future<void> zoomOut() => _c.zoomDown();

  @override
  void find(String text) {
    if (text.isEmpty) {
      _searcher.resetTextSearch();
    } else {
      _searcher.startTextSearch(text, caseInsensitive: true);
    }
  }

  @override
  Future<void> nextMatch() async {
    if (_searcher.matches.isNotEmpty) await _searcher.goToNextMatch();
  }

  @override
  Future<void> previousMatch() async {
    if (_searcher.matches.isNotEmpty) await _searcher.goToPrevMatch();
  }

  @override
  int get matchCount => _searcher.matches.length;

  @override
  int? get matchIndex => _searcher.currentIndex;

  @override
  bool get isFinding => _searcher.isSearching;

  @override
  bool get hasSelection => _selection?.hasSelectedText ?? false;

  @override
  bool get copyAllowed => _copyAllowed;

  @override
  Future<String?> selectedText() async {
    final s = _selection;
    if (s == null || !s.hasSelectedText) return null;
    return s.getSelectedText();
  }
}
