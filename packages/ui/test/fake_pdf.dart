// P05b T1: a fake PDF view for the UI tests (pdfrx is not loaded). A PDF is
// a list of page texts; it can have a password, be damaged, forbid copying.
// Calls are recorded (`pdf.open:<sourceName>:<initialPage>`, `pdf.page:<n>`,
// `pdf.zoomIn`, `pdf.find:<text>`, …).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ui/src/documents/pdf_view.dart';

class FakePdf {
  FakePdf(this.calls);
  final List<String> calls;

  /// The text of each page of the next PDF shown.
  List<String> pages = ['Trang một', 'Trang hai', 'Trang ba'];

  /// When set, the PDF opens only with this password.
  String? password;
  bool damaged = false;
  bool copyAllowed = true;

  /// The bytes each view was given (a test checks they came from memory).
  final shown = <Uint8List>[];

  FakePdfControls? controls;

  Widget build(BuildContext context, PdfViewSetup setup) => _FakePdfView(key: ValueKey(setup.sourceName), pdf: this, setup: setup);
}

class _FakePdfView extends StatefulWidget {
  const _FakePdfView({super.key, required this.pdf, required this.setup});
  final FakePdf pdf;
  final PdfViewSetup setup;

  @override
  State<_FakePdfView> createState() => _FakePdfViewState();
}

class _FakePdfViewState extends State<_FakePdfView> {
  FakePdfControls? _c;

  @override
  void initState() {
    super.initState();
    final p = widget.pdf;
    final s = widget.setup;
    p.calls.add('pdf.open:${s.sourceName}:${s.initialPage}');
    p.shown.add(s.bytes);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final p = widget.pdf;
    final s = widget.setup;
    if (p.damaged) return s.onFailed(PdfOpenFailure.unreadable);
    if (p.password != null) {
      var wrong = false;
      while (true) {
        final given = await s.password(wrong: wrong);
        if (!mounted) return;
        if (given == null) return s.onFailed(PdfOpenFailure.passwordNeeded);
        if (given == p.password) break;
        wrong = true;
      }
    }
    final c = FakePdfControls(p, initialPage: s.initialPage.clamp(1, p.pages.length));
    p.controls = c;
    setState(() => _c = c);
    s.onReady(c);
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.expand();
    return ListenableBuilder(
      listenable: c,
      builder: (_, __) => Center(child: Text('page ${c.pageNumber}: ${widget.pdf.pages[c.pageNumber - 1]}', key: const Key('fake-pdf-page'))),
    );
  }
}

class FakePdfControls extends ChangeNotifier implements PdfViewControls {
  FakePdfControls(this.pdf, {required int initialPage}) : _page = initialPage;
  final FakePdf pdf;
  int _page;
  List<int> _matchPages = const [];
  int? _match;
  String? _selected;

  /// Test helper: the person selects [text] (null: clears the selection).
  void select(String? text) {
    _selected = text;
    notifyListeners();
  }

  /// Test helper: the person scrolls to [page].
  void scrollTo(int page) {
    _page = page;
    notifyListeners();
  }

  @override
  int get pageCount => pdf.pages.length;

  @override
  int get pageNumber => _page;

  @override
  Future<void> goToPage(int pageNumber) async {
    pdf.calls.add('pdf.page:$pageNumber');
    _page = pageNumber.clamp(1, pageCount);
    notifyListeners();
  }

  @override
  Future<void> zoomIn() async => pdf.calls.add('pdf.zoomIn');

  @override
  Future<void> zoomOut() async => pdf.calls.add('pdf.zoomOut');

  @override
  void find(String text, {bool go = true}) {
    pdf.calls.add('pdf.find:$text${go ? '' : ':stay'}');
    final t = text.toLowerCase();
    _matchPages = t.isEmpty
        ? const []
        : [
            for (var i = 0; i < pdf.pages.length; i++)
              for (var at = pdf.pages[i].toLowerCase().indexOf(t); at >= 0; at = pdf.pages[i].toLowerCase().indexOf(t, at + 1)) i + 1,
          ];
    _match = _matchPages.isEmpty || !go ? null : 0;
    if (_match != null) _page = _matchPages[0];
    notifyListeners();
  }

  Future<void> _go(int delta) async {
    if (_matchPages.isEmpty) return;
    _match = ((_match ?? 0) + delta) % _matchPages.length;
    _page = _matchPages[_match!];
    notifyListeners();
  }

  @override
  Future<void> nextMatch() => _go(1);

  @override
  Future<void> previousMatch() => _go(-1);

  @override
  int get matchCount => _matchPages.length;

  @override
  int? get matchIndex => _match;

  @override
  bool get isFinding => false;

  @override
  bool get hasSelection => _selected != null;

  @override
  bool get copyAllowed => pdf.copyAllowed;

  @override
  Future<String?> selectedText() async => _selected;

  @override
  Future<String> pageText(int pageNumber) async =>
      pageNumber >= 1 && pageNumber <= pdf.pages.length ? pdf.pages[pageNumber - 1] : '';
}
