// P05b T1 (ADR-0076; p05b-plan.md D8, D9): a PDF kept in a document, on its
// own page, opened from the file in the document.
//   file       decrypted in memory by AttachmentService.open and given to the
//              view as bytes; nothing is written to disk (ADR-0072)
//   pages      scrolling, zoom in and out, previous and next page, "Page 3
//              of 12"; it opens at the page last shown on this device (D9),
//              saved a moment after the page changes and on leaving
//   find       the find bar (the search button or Ctrl+F): matches counted,
//              previous and next; Escape closes it
//   copy       the selected text, unless the PDF forbids copying
//   password   asked for in a dialog, again after a wrong one
//   search     a hit (P05b T2, ADR-0077) opens at its page, the words typed
//              highlighted in the find bar ("3 matches")
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../providers.dart';
import '../task_actions.dart' show showMessage;
import 'document_page.dart' show formatBytes;
import 'pdf_view.dart';

/// How long the page must stay before it is remembered (D9).
const pdfPageSaveDelay = Duration(seconds: 1);

/// Opens [file]; from a search hit (ADR-0077) at [page], with [find]'s
/// matches highlighted.
Future<void> openPdfPage(BuildContext context, AttachmentRef file, AttachmentService files, {int? page, String? find}) =>
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute<void>(builder: (_) => PdfPage(file: file, files: files, page: page, find: find)));

class PdfPage extends ConsumerStatefulWidget {
  const PdfPage({super.key, required this.file, required this.files, this.page, this.find});
  final AttachmentRef file;
  final AttachmentService files;

  /// The page to open at, instead of the last one shown (a search hit).
  final int? page;

  /// Words to highlight on opening, in the find bar (a search hit).
  final String? find;

  @override
  ConsumerState<PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends ConsumerState<PdfPage> {
  // Read once at the start: the page saves in dispose, when ref is gone.
  late final SettingsService _settings;
  late final Future<(AttachmentContent, int)> _opened;
  final _findText = TextEditingController();
  final _findFocus = FocusNode();
  PdfViewControls? _controls;
  PdfOpenFailure? _failure;
  var _attempt = 0;
  var _finding = false;
  Timer? _saveTimer;
  int? _savedPage;

  String get _hash => widget.file.hash;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(settingsServiceProvider);
    _opened = _open();
  }

  Future<(AttachmentContent, int)> _open() async {
    final content = await widget.files.open(_hash);
    int? page;
    try {
      page = await _settings.lastPdfPage(_hash);
    } on Object {
      page = null; // an unreadable setting only loses the page
    }
    _savedPage = page;
    return (content, widget.page ?? page ?? 1);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final c = _controls;
    c?.removeListener(_changed);
    // Leaving remembers the page (D9); the service is kept, the page is gone.
    if (c != null && c.pageNumber != _savedPage) unawaited(_settings.setLastPdfPage(_hash, c.pageNumber));
    _findText.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  void _ready(PdfViewControls c) {
    _controls?.removeListener(_changed);
    c.addListener(_changed);
    setState(() => _controls = c);
    final words = widget.find?.trim() ?? '';
    if (words.isNotEmpty && _findText.text.isEmpty) {
      _findText.text = words;
      c.find(words, go: false); // stay on the page of the hit
      setState(() => _finding = true);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final c = _controls;
    if (c == null || c.pageNumber == _savedPage) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(pdfPageSaveDelay, () {
      final page = c.pageNumber;
      _savedPage = page;
      unawaited(_settings.setLastPdfPage(_hash, page));
    });
  }

  Future<String?> _askPassword({required bool wrong}) async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordDialog(name: widget.file.name, wrong: wrong),
    );
  }

  void _openFind() {
    setState(() => _finding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocus.requestFocus();
    });
  }

  void _closeFind() {
    _findText.clear();
    _controls?.find('');
    setState(() => _finding = false);
  }

  Future<void> _copy() async {
    final l = context.l10n;
    final c = _controls;
    if (c == null) return;
    if (!c.copyAllowed) return showMessage(context, l.pdfCopyNotAllowed);
    final text = await c.selectedText();
    if (text == null || text.isEmpty || !mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showMessage(context, l.pdfCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _controls;
    final ready = c != null && _failure == null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (ready) _openFind();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.file.name, overflow: TextOverflow.ellipsis),
            actions: [
              if (ready) ...[
                IconButton(key: const Key('pdf-find'), tooltip: l.pdfFind, icon: const Icon(Icons.search), onPressed: _openFind),
                if (c.hasSelection)
                  IconButton(key: const Key('pdf-copy'), tooltip: l.pdfCopy, icon: const Icon(Icons.copy), onPressed: _copy),
                IconButton(key: const Key('pdf-zoom-out'), tooltip: l.pdfZoomOut, icon: const Icon(Icons.zoom_out), onPressed: c.zoomOut),
                IconButton(key: const Key('pdf-zoom-in'), tooltip: l.pdfZoomIn, icon: const Icon(Icons.zoom_in), onPressed: c.zoomIn),
              ],
            ],
          ),
          body: FutureBuilder<(AttachmentContent, int)>(
            future: _opened,
            builder: (context, snap) {
              final opened = snap.data;
              if (opened == null) {
                return snap.hasError
                    ? _Message(key: const Key('pdf-failed'), text: l.pdfCannotOpen)
                    : Center(child: CircularProgressIndicator(semanticsLabel: l.loading));
              }
              final (content, page) = opened;
              final bytes = content.bytes;
              if (bytes == null) {
                final f = widget.file;
                return _Message(
                  key: const Key('pdf-not-here'),
                  text: content.availability == AttachmentAvailability.elsewhere
                      ? l.docFileElsewhere(f.name, formatBytes(f.size))
                      : l.docFileUnreadable(f.name),
                );
              }
              if (_failure case final failure?) {
                return _Message(
                  key: const Key('pdf-failed'),
                  text: failure == PdfOpenFailure.passwordNeeded ? l.pdfNeedsPassword : l.pdfCannotOpen,
                  action: failure == PdfOpenFailure.passwordNeeded
                      ? TextButton(
                          key: const Key('pdf-try-again'),
                          onPressed: () => setState(() {
                            _failure = null;
                            _controls = null;
                            _attempt++;
                          }),
                          child: Text(l.pdfTryAgain),
                        )
                      : null,
                );
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_finding && ready) _FindBar(controls: c, text: _findText, focus: _findFocus, onClose: _closeFind),
                // Keyed: the bars around it come and go without a new view.
                Expanded(
                  key: ValueKey('pdf-view-$_attempt'),
                  child: ref.watch(pdfViewBuilderProvider)(
                    context,
                    PdfViewSetup(
                      bytes: bytes,
                      sourceName: 'lifeflow:$_hash#$_attempt',
                      initialPage: page,
                      password: _askPassword,
                      onReady: _ready,
                      onFailed: (f) => setState(() => _failure = f),
                    ),
                  ),
                ),
                if (ready) _PageBar(controls: c),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ]),
        ),
      );
}

class _FindBar extends StatelessWidget {
  const _FindBar({required this.controls, required this.text, required this.focus, required this.onClose});
  final PdfViewControls controls;
  final TextEditingController text;
  final FocusNode focus;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = controls;
    final typed = text.text.isNotEmpty;
    final status = !typed
        ? ''
        : c.matchCount > 0
            ? (c.matchIndex == null ? l.pdfMatchCount(c.matchCount) : l.pdfMatchOf(c.matchIndex! + 1, c.matchCount))
            : c.isFinding
                ? l.pdfFinding
                : l.pdfNoMatches;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const Key('pdf-find-field'),
                controller: text,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(hintText: l.pdfFindHint, prefixIcon: const Icon(Icons.search), border: InputBorder.none),
                onChanged: c.find,
                onSubmitted: (_) {
                  unawaited(c.nextMatch());
                  focus.requestFocus();
                },
              ),
            ),
            Text(status, key: const Key('pdf-find-status')),
            IconButton(
                key: const Key('pdf-find-previous'),
                tooltip: l.pdfPreviousMatch,
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: c.matchCount > 0 ? c.previousMatch : null),
            IconButton(
                key: const Key('pdf-find-next'),
                tooltip: l.pdfNextMatch,
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: c.matchCount > 0 ? c.nextMatch : null),
            IconButton(key: const Key('pdf-find-close'), tooltip: l.pdfCloseFind, icon: const Icon(Icons.close), onPressed: onClose),
          ]),
        ),
      ),
    );
  }
}

class _PageBar extends StatelessWidget {
  const _PageBar({required this.controls});
  final PdfViewControls controls;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = controls;
    final n = c.pageNumber;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              key: const Key('pdf-page-previous'),
              tooltip: l.pdfPreviousPage,
              icon: const Icon(Icons.chevron_left),
              onPressed: n > 1 ? () => c.goToPage(n - 1) : null),
          Text(l.pdfPageOf(n, c.pageCount), key: const Key('pdf-page-of')),
          IconButton(
              key: const Key('pdf-page-next'),
              tooltip: l.pdfNextPage,
              icon: const Icon(Icons.chevron_right),
              onPressed: n < c.pageCount ? () => c.goToPage(n + 1) : null),
        ]),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.name, required this.wrong});
  final String name;
  final bool wrong;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const Key('pdf-password'),
      title: Text(l.pdfPasswordTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.pdfPasswordPrompt(widget.name)),
        if (widget.wrong) ...[
          const SizedBox(height: 8),
          Text(l.pdfPasswordWrong, key: const Key('pdf-password-wrong'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        TextField(
          key: const Key('pdf-password-field'),
          controller: _text,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: l.pdfPasswordTitle),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ]),
      actions: [
        TextButton(key: const Key('pdf-password-cancel'), onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const Key('pdf-password-open'), onPressed: () => Navigator.pop(context, _text.text), child: Text(l.pdfPasswordOpen)),
      ],
    );
  }
}
