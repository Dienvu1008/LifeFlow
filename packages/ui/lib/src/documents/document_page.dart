// P05a T8 (ADR-0073; p05-plan.md §4, C5–C9): a document on its own page.
//   editor     flutter_quill behind the adapter (quill_adapter.dart); the
//              stored body is LifeFlow's format
//   saving     by itself (C7): 10 s after the last change, on leaving the
//              page, on opening another document, when the app goes to the
//              background; each save is a revision (C5); nothing is written
//              when nothing changed
//   [[         typing it (or the link button) offers the documents of the
//              shown space by title, or "Create …"; a link shows its target's
//              current title; a broken one says so when tapped (DOC-003)
//   files      "Attach a file": kept on this device, encrypted (ADR-0072);
//              shown as a picture or a file, or "on another device"; a PDF
//              opens in the PDF page (pdf_page.dart, ADR-0076)
//   under it   backlinks with their sentences, and the linked tasks, events
//              and goals; the history in the menu, with restore
//   view only  a viewer, a document in the trash, a body this app cannot
//              read: nothing is edited
//   read aloud P05b T4 (ADR-0078): the reader bar; the sentence read is
//              selected in the editor, which reads only meanwhile; leaving
//              the page stops it, the app going to the background pauses it
import '../assistant/assistant_page.dart';
import 'dart:async';
import 'dart:convert';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../messages.dart';
import '../providers.dart';
import '../screens/goals_screen.dart' show openGoalPage;
import '../screens/spaces_ui.dart' show moveItemFlow, moveLabel;
import '../screens/task_page.dart' show openTaskPage;
import '../task_actions.dart' show reportResult, showMessage;
import 'documents_screen.dart' show moveUnderFlow, trashDocumentFlow;
import 'pdf_page.dart' show openPdfPage;
import 'quill_adapter.dart';
import 'read_aloud.dart';
import 'reader_bar.dart';

Future<void> openDocumentPage(BuildContext context, String id) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute<void>(builder: (_) => DocumentPage(documentId: id)));

/// "1.2 MB", "340 KB", "12 B".
String formatBytes(int n) {
  if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (n >= 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
  return '$n B';
}

enum SaveState { saved, saving, unsaved }

enum _PageAction { history, link, moveUnder, space, trash }

class DocumentPage extends ConsumerStatefulWidget {
  const DocumentPage({super.key, required this.documentId});
  final String documentId;

  @override
  ConsumerState<DocumentPage> createState() => DocumentPageState();
}

class DocumentPageState extends ConsumerState<DocumentPage> {
  // Read once at the start: the page saves in dispose, when ref is gone.
  late final DocumentService _service;
  late final DocumentQueries _queries;
  late final AttachmentService _files;
  final _title = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final AppLifecycleListener _life;

  DocumentView? _doc;
  bool _loaded = false;
  q.QuillController? _c;
  StreamSubscription<q.DocChange>? _changes;
  List<String> _ids = const [];
  String _baseline = '';
  String _savedTitle = '';
  int _version = 0;
  Timer? _idle;
  SaveState _state = SaveState.saved;
  Future<void>? _inFlight;
  bool _picking = false;

  /// P05b T4: the reader, while it is open; where each block starts in the
  /// editor (for the sentence shown).
  ReadAloud? _reader;
  Map<String, int> _offsets = const {};

  /// Whether the shown space may be changed (B4), as last built.
  late bool _canEdit = ref.read(canEditShownProvider);
  int _generation = 0;
  int _linksGeneration = 0;

  @override
  void initState() {
    super.initState();
    _service = ref.read(documentServiceProvider);
    _queries = ref.read(documentQueriesProvider);
    _files = ref.read(attachmentServiceProvider);
    _life = AppLifecycleListener(onInactive: _saveSoon, onHide: _hidden, onPause: _hidden);
    _title.addListener(_edited);
    _load();
  }

  /// The editor's controller (tests type through it).
  @visibleForTesting
  q.QuillController? get controller => _c;

  /// The document cannot be changed here (a viewer, the trash, unreadable).
  bool get _viewOnly {
    final d = _doc;
    return d == null || d.isTrashed || d.isUnreadable || !_canEdit;
  }

  /// Nothing is typed: view only, or while reading aloud.
  bool get _readOnly => _viewOnly || _reader != null;

  Future<void> _load() async {
    final d = await _queries.document(widget.documentId);
    if (!mounted) return;
    _changes?.cancel();
    _c?.removeListener(_checkLinkTrigger);
    _c?.dispose();
    _c = null;
    var body = d?.body ?? DocumentBody([]);
    if (d != null && !d.isUnreadable) {
      // Each link shows its target's current title (ADR-0071).
      final targets = await _queries.linkTargets(_docLinksOf(body));
      if (!mounted) return;
      body = withLinkTitles(body, (id) => targets[id]?.state == LinkState.ok ? targets[id]!.title : null);
    }
    setState(() {
      _doc = d;
      _loaded = true;
      if (d == null) return;
      _version = d.version;
      _savedTitle = d.title;
      _title.removeListener(_edited);
      _title.text = d.title;
      _title.addListener(_edited);
      _ids = blockIdsOf(body);
      _baseline = body.encode();
      _state = SaveState.saved;
      if (!d.isUnreadable) {
        final c = q.QuillController(
          document: quillDocumentOf(body),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: _readOnly,
        );
        _changes = c.changes.listen((_) => _edited());
        c.addListener(_checkLinkTrigger);
        _c = c;
      }
      _generation++;
    });
  }

  static Set<String> _docLinksOf(DocumentBody body) => {
        for (final b in body.blocks)
          for (final r in b.runs)
            if (r.doc != null) r.doc!,
      };

  void _edited() {
    if (_readOnly || !_loaded) return;
    _idle?.cancel();
    _idle = Timer(documentIdleSave, _save);
    if (_state == SaveState.saved && _dirty && mounted) setState(() => _state = SaveState.unsaved);
  }

  void _saveSoon() => unawaited(_save());

  /// The app went to the background: saved, and reading paused (D6).
  void _hidden() {
    _saveSoon();
    unawaited(_reader?.pause());
  }

  // --- read aloud (P05b T4) ------------------------------------------------------

  Future<void> _openReader() async {
    await _save();
    final c = _c;
    if (c == null || !mounted) return;
    final body = bodyOf(c.document.toDelta(), ids: _ids);
    final r = ReadAloud(ref.read(ttsPortProvider), ref.read(settingsServiceProvider));
    r.addListener(_readerChanged);
    setState(() {
      _reader = r;
      _offsets = blockOffsetsOf(body);
    });
    await r.load(body);
  }

  /// Shows the sentence being read: selected in the editor, scrolled to.
  void _readerChanged() {
    final r = _reader, c = _c;
    if (r == null || c == null || !mounted) return;
    setState(() {});
    final s = r.current;
    final at = s == null ? null : _offsets[s.blockId];
    if (r.state == ReadState.stopped || at == null) return;
    c.updateSelection(TextSelection(baseOffset: at + s!.start, extentOffset: at + s.end), q.ChangeSource.local);
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  /// The sentence shown while reading (tests read it).
  @visibleForTesting
  ReadAloud? get reader => _reader;

  void _closeReader() {
    final r = _reader;
    if (r == null) return;
    r.removeListener(_readerChanged);
    unawaited(r.stop());
    r.dispose();
    setState(() => _reader = null);
    final c = _c;
    if (c != null) c.updateSelection(TextSelection.collapsed(offset: c.selection.baseOffset), q.ChangeSource.local);
  }

  bool get _dirty {
    final c = _c;
    if (c == null) return false;
    return _titleNow != _savedTitle || bodyOf(c.document.toDelta(), ids: _ids).encode() != _baseline;
  }

  String get _titleNow {
    final t = _title.text.trim();
    return t.isEmpty ? _savedTitle : t;
  }

  /// Saves what is shown if it changed (C7). One save at a time.
  Future<void> _save() async {
    _idle?.cancel();
    while (_inFlight != null) {
      await _inFlight;
    }
    final c = _c;
    if (c == null || _readOnly) return;
    final body = bodyOf(c.document.toDelta(), ids: _ids);
    final title = _titleNow;
    if (title == _savedTitle && body.encode() == _baseline) {
      if (mounted && _state != SaveState.saved) setState(() => _state = SaveState.saved);
      return;
    }
    final done = Completer<void>();
    _inFlight = done.future;
    if (mounted) setState(() => _state = SaveState.saving);
    try {
      // Changed elsewhere meanwhile (a sync): both saves stay in the history.
      final stored = await _queries.document(widget.documentId);
      final elsewhere = stored != null && stored.version != _version;
      final r = await _service.save(widget.documentId, title: title, body: body);
      if (r is CommandOk) {
        _baseline = body.encode();
        _savedTitle = title;
        _ids = blockIdsOf(body);
        _version = r.newVersion.value;
        if (mounted) {
          setState(() => _state = _dirty ? SaveState.unsaved : SaveState.saved);
          if (elsewhere) {
            showMessage(context, context.l10n.docChangedElsewhere,
                action: SnackBarAction(label: context.l10n.docOpenAgain, onPressed: _load));
          }
        }
      } else if (r is CommandFailure && mounted) {
        setState(() => _state = SaveState.unsaved);
        showMessage(context, describeFailure(r));
      }
    } finally {
      _inFlight = null;
      done.complete();
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    _life.dispose();
    // Leaving the page stops the reading (D6).
    _reader?.removeListener(_readerChanged);
    _reader?.dispose();
    // Leaving the page saves it (C7); the service is kept, the page is gone.
    final c = _c;
    if (c != null && !_readOnly && _loaded) {
      final body = bodyOf(c.document.toDelta(), ids: _ids);
      final title = _titleNow;
      if (title != _savedTitle || body.encode() != _baseline) {
        final previous = _inFlight;
        unawaited(() async {
          if (previous != null) await previous;
          await _service.save(widget.documentId, title: title, body: body);
        }());
      }
    }
    _changes?.cancel();
    c?.removeListener(_checkLinkTrigger);
    c?.dispose();
    _title.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // --- [[ links ---------------------------------------------------------------

  void _checkLinkTrigger() {
    final c = _c;
    if (_picking || c == null || _readOnly) return;
    final sel = c.selection;
    if (!sel.isCollapsed) return;
    final off = sel.baseOffset;
    final text = c.document.toPlainText();
    if (off < 2 || off > text.length || text.substring(off - 2, off) != '[[') return;
    _picking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickLink(off - 2, 2));
  }

  /// Offers a document to link at [at], replacing [replace] characters.
  Future<void> _pickLink(int at, int replace) async {
    _picking = true;
    final picked = await showDialog<({String id, String title})>(
      context: context,
      builder: (_) => DocumentLinkPicker(excludeId: widget.documentId),
    );
    _picking = false;
    final c = _c;
    if (picked == null || c == null || !mounted) return;
    final title = picked.title;
    c.replaceText(at, replace, title, TextSelection.collapsed(offset: at + title.length));
    c.formatText(at, title.length, q.LinkAttribute('$docLinkScheme${picked.id}'));
    setState(() => _linksGeneration++);
  }

  /// What a tap on a link does (tests call it; Quill calls [_openLink]).
  @visibleForTesting
  Future<void> openLinkForTest(String url) => _openLink(url);

  Future<void> _openLink(String url) async {
    final l = context.l10n;
    if (!url.startsWith(docLinkScheme)) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) showMessage(context, l.docLinkCopied(url));
      return;
    }
    final id = url.substring(docLinkScheme.length);
    final t = (await _queries.linkTargets([id]))[id];
    if (!mounted) return;
    switch (t?.state) {
      case LinkState.ok:
        await _save(); // switching documents saves this one (C7)
        if (mounted) await openDocumentPage(context, id);
      case LinkState.inTrash:
        showMessage(context, l.docLinkInTrash(t!.title ?? ''));
      case LinkState.missing || null:
        showMessage(context, l.docLinkMissing);
    }
  }

  // --- files --------------------------------------------------------------------

  Future<void> _attach() async {
    final l = context.l10n;
    final c = _c;
    if (c == null) return;
    PickedFile? f;
    try {
      f = await ref.read(fileGatewayProvider).pickFile(maxBytes: maxAttachmentBytes);
    } on FileTooLarge {
      if (mounted) showMessage(context, l.docFileTooLarge(formatBytes(maxAttachmentBytes)));
      return;
    }
    if (f == null || !mounted) return;
    final added = await _files.add(f.bytes, name: f.name, mime: f.mime);
    if (!mounted) return;
    final ref0 = added.ref;
    if (ref0 == null) {
      return showMessage(
          context, added.problem == AttachmentProblem.tooLarge ? l.docFileTooLarge(formatBytes(maxAttachmentBytes)) : l.docFileNotKept);
    }
    var i = c.selection.baseOffset < 0 ? c.document.length - 1 : c.selection.baseOffset;
    // A file is a block of its own: on a new line after any text before it.
    final text = c.document.toPlainText();
    if (i > 0 && i <= text.length && text[i - 1] != '\n') {
      c.replaceText(i, 0, '\n', null);
      i++;
    }
    c.replaceText(i, 0, q.BlockEmbed(attachmentEmbedType, jsonEncode(ref0.toJson())), null);
    c.replaceText(i + 1, 0, '\n', TextSelection.collapsed(offset: i + 2));
  }

  // --- the page -----------------------------------------------------------------

  Future<void> _act(_PageAction a) async {
    final d = _doc;
    if (d == null) return;
    await _save();
    if (!mounted) return;
    switch (a) {
      case _PageAction.history:
        final restored = await Navigator.of(context)
            .push<bool>(MaterialPageRoute(builder: (_) => DocumentHistoryPage(documentId: d.id, canRestore: !_readOnly)));
        if (restored == true) await _load();
      case _PageAction.link:
        final item = await showDialog<({DocumentItemType type, String id})>(context: context, builder: (_) => const ItemLinkPicker());
        if (item == null || !mounted) return;
        await reportResult(context, _service.link(d.id, item.type, item.id));
        if (mounted) setState(() => _linksGeneration++);
      case _PageAction.moveUnder:
        await moveUnderFlow(context, ref,
            DocumentNodeView(id: d.id, title: d.title, parentId: d.parentId, orderKey: ''));
      case _PageAction.space:
        await moveItemFlow(context, ref, kind: 'document', id: d.id);
        if (mounted) await _load();
      case _PageAction.trash:
        if (await trashDocumentFlow(context, ref, d.id, d.title) && mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _doc;
    final canEdit = _canEdit = ref.watch(canEditShownProvider);
    final c = _c;
    if (c != null && c.readOnly != _readOnly) c.readOnly = _readOnly;
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.title ?? l.navDocuments, overflow: TextOverflow.ellipsis),
        actions: [
          if (d != null && !d.isUnreadable && c != null)
            IconButton(
              key: const Key('doc-read-aloud'),
              tooltip: l.docReadAloud,
              isSelected: _reader != null,
              icon: const Icon(Icons.record_voice_over_outlined),
              onPressed: _reader == null ? _openReader : _closeReader,
            ),
          // P06 T7: ask the assistant about this document.
          if (d != null && ref.watch(aiAssistantProvider) != null)
            IconButton(
              key: const Key('doc-ask-assistant'),
              tooltip: l.aiAskAssistant,
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => showAskAssistant(context, RecordRef('document', widget.documentId)),
            ),
          if (d != null)
            PopupMenuButton<_PageAction>(
              key: const Key('doc-page-menu'),
              tooltip: l.actionsForTitle(d.title),
              onSelected: _act,
              itemBuilder: (_) => [
                PopupMenuItem(value: _PageAction.history, child: Text(l.docHistory)),
                if (canEdit && !d.isTrashed) ...[
                  PopupMenuItem(value: _PageAction.link, child: Text(l.docLinkItem)),
                  PopupMenuItem(value: _PageAction.moveUnder, child: Text(l.docMoveUnder)),
                  if (moveLabel(context, ref) case final m?) PopupMenuItem(value: _PageAction.space, child: Text(m)),
                  PopupMenuItem(value: _PageAction.trash, child: Text(l.moveToTrash)),
                ],
              ],
            ),
        ],
      ),
      body: !_loaded
          ? Center(child: CircularProgressIndicator(semanticsLabel: l.loading))
          : d == null
              ? Center(child: Text(l.docGone, key: const Key('doc-gone')))
              : PopScope(
                  onPopInvokedWithResult: (_, __) => _saveSoon(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (d.isTrashed) _Banner(key: const Key('doc-in-trash'), text: l.docInTrash, action: canEdit ? _restoreAction() : null),
                    if (d.isUnreadable) _Banner(key: const Key('doc-unreadable'), text: l.docUnreadable),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        key: const Key('doc-title'),
                        controller: _title,
                        readOnly: _readOnly,
                        maxLength: maxDocumentTitleLength,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: InputDecoration(hintText: l.docTitleLabel, border: InputBorder.none, counterText: ''),
                        onSubmitted: (_) => _saveSoon(),
                      ),
                    ),
                    _StatusLine(doc: d, state: _state, readOnly: _viewOnly),
                    if (!_readOnly && c != null) _Toolbar(controller: c, onLink: () => _pickLink(c.selection.baseOffset, 0), onAttach: _attach),
                    const Divider(height: 1),
                    Expanded(
                      child: c == null
                          ? const SizedBox.shrink()
                          : q.QuillEditor(
                              key: ValueKey('doc-editor-$_generation'),
                              controller: c,
                              focusNode: _focus,
                              scrollController: _scroll,
                              config: q.QuillEditorConfig(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                maxContentWidth: 760,
                                placeholder: l.docPlaceholder,
                                onLaunchUrl: _openLink,
                                embedBuilders: [AttachmentEmbedBuilder(_files)],
                                customStyles: q.DefaultStyles(
                                  link: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none),
                                ),
                              ),
                            ),
                    ),
                    if (_reader case final r?) ReaderBar(reader: r, onClose: _closeReader),
                    _LinksPanel(key: ValueKey('links-$_linksGeneration'), doc: d, canEdit: canEdit && !d.isTrashed, onChanged: () {
                      setState(() => _linksGeneration++);
                    }),
                  ]),
                ),
    );
  }

  Widget _restoreAction() => TextButton(
        key: const Key('doc-restore'),
        onPressed: () async {
          await reportResult(context, _service.restore(widget.documentId));
          ref.invalidate(trashedDocumentsProvider);
          await _load();
        },
        child: Text(context.l10n.restore),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => MaterialBanner(
        content: Text(text),
        actions: [action ?? const SizedBox.shrink()],
      );
}

class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.doc, required this.state, required this.readOnly});
  final DocumentView doc;
  final SaveState state;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final space = ref.watch(shownSharedSpaceProvider);
    final parts = <String>[
      if (readOnly && !doc.isTrashed && !doc.isUnreadable) l.docViewOnly,
      if (!readOnly)
        switch (state) {
          SaveState.saved => l.docSaved,
          SaveState.saving => l.docSaving,
          SaveState.unsaved => l.docUnsaved,
        },
    ];
    if (space != null && doc.changedBy != null) {
      final names = ref.watch(memberNamesProvider(space.id)).valueOrNull ?? const <String, String>{};
      final at = doc.updatedAt.utc.toLocal();
      final ml = MaterialLocalizations.of(context);
      parts.add(l.spChangedBy(names[doc.changedBy] ?? l.spSomeone,
          '${ml.formatShortDate(at)} ${ml.formatTimeOfDay(TimeOfDay.fromDateTime(at))}'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(parts.join(' · '), key: const Key('doc-status'), style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.onLink, required this.onAttach});
  final q.QuillController controller;
  final VoidCallback onLink;
  final VoidCallback onAttach;

  void _block(q.Attribute a) {
    for (final off in <q.Attribute>[q.Attribute.header, q.Attribute.list, q.Attribute.blockQuote, q.Attribute.codeBlock]) {
      if (off.key != a.key) controller.formatSelection(q.Attribute.clone(off, null));
    }
    controller.formatSelection(a);
  }

  void _paragraph() {
    for (final off in <q.Attribute>[q.Attribute.header, q.Attribute.list, q.Attribute.blockQuote, q.Attribute.codeBlock, q.Attribute.indent]) {
      controller.formatSelection(q.Attribute.clone(off, null));
    }
  }

  void _toggle(q.Attribute a) {
    final on = controller.getSelectionStyle().attributes.containsKey(a.key);
    controller.formatSelection(on ? q.Attribute.clone(a, null) : a);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget b(String key, String tip, IconData icon, VoidCallback f) =>
        IconButton(key: Key('doc-tool-$key'), tooltip: tip, icon: Icon(icon), onPressed: f, visualDensity: VisualDensity.compact);
    return SingleChildScrollView(
      key: const Key('doc-toolbar'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        b('paragraph', l.docToolParagraph, Icons.notes, _paragraph),
        b('h1', l.docToolHeading1, Icons.looks_one_outlined, () => _block(q.Attribute.h1)),
        b('h2', l.docToolHeading2, Icons.looks_two_outlined, () => _block(q.Attribute.h2)),
        b('h3', l.docToolHeading3, Icons.looks_3_outlined, () => _block(q.Attribute.h3)),
        b('bullet', l.docToolBullet, Icons.format_list_bulleted, () => _block(q.Attribute.ul)),
        b('numbered', l.docToolNumbered, Icons.format_list_numbered, () => _block(q.Attribute.ol)),
        b('todo', l.docToolTodo, Icons.check_box_outlined, () => _block(q.Attribute.unchecked)),
        b('quote', l.docToolQuote, Icons.format_quote, () => _block(q.Attribute.blockQuote)),
        b('code', l.docToolCode, Icons.code, () => _block(q.Attribute.codeBlock)),
        b('indent', l.docToolIndent, Icons.format_indent_increase, () => controller.indentSelection(true)),
        b('outdent', l.docToolOutdent, Icons.format_indent_decrease, () => controller.indentSelection(false)),
        const SizedBox(width: 8),
        b('bold', l.docToolBold, Icons.format_bold, () => _toggle(q.Attribute.bold)),
        b('italic', l.docToolItalic, Icons.format_italic, () => _toggle(q.Attribute.italic)),
        b('underline', l.docToolUnderline, Icons.format_underlined, () => _toggle(q.Attribute.underline)),
        b('strike', l.docToolStrike, Icons.format_strikethrough, () => _toggle(q.Attribute.strikeThrough)),
        b('inline-code', l.docToolInlineCode, Icons.data_object, () => _toggle(q.Attribute.inlineCode)),
        const SizedBox(width: 8),
        b('link', l.docToolLink, Icons.link, onLink),
        b('attach', l.docAttach, Icons.attach_file, onAttach),
        b('undo', l.docToolUndo, Icons.undo, controller.undo),
        b('redo', l.docToolRedo, Icons.redo, controller.redo),
      ]),
    );
  }
}

// --- under the text: backlinks and linked items ------------------------------

class _LinksPanel extends ConsumerStatefulWidget {
  const _LinksPanel({super.key, required this.doc, required this.canEdit, required this.onChanged});
  final DocumentView doc;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  ConsumerState<_LinksPanel> createState() => _LinksPanelState();
}

class _LinksPanelState extends ConsumerState<_LinksPanel> {
  late final Future<(List<BacklinkView>, List<DocumentItemLinkView>)> _links = () async {
    final queries = ref.read(documentQueriesProvider);
    return (await queries.backlinks(widget.doc.id), await queries.linksOf(widget.doc.id));
  }();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return FutureBuilder(
      future: _links,
      builder: (context, snap) {
        final (back, linked) = snap.data ?? (const <BacklinkView>[], const <DocumentItemLinkView>[]);
        Widget header(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Semantics(header: true, child: Text(t, style: theme.textTheme.titleSmall)),
            );
        return Material(
          color: theme.colorScheme.surfaceContainerLow,
          child: ExpansionTile(
            key: const Key('doc-links'),
            title: Text(l.docLinksSummary(back.length, linked.length), style: theme.textTheme.bodyMedium),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                child: ListView(shrinkWrap: true, children: [
                  header(l.docBacklinks),
                  if (back.isEmpty) ListTile(dense: true, title: Text(l.docNoBacklinks)),
                  for (final b in back)
                    ListTile(
                      key: ValueKey('backlink-${b.id}'),
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(b.title),
                      subtitle: b.snippets.isEmpty ? null : Text(b.snippets.join('\n'), maxLines: 4, overflow: TextOverflow.ellipsis),
                      onTap: () => openDocumentPage(context, b.id),
                    ),
                  header(l.docLinked),
                  if (linked.isEmpty) ListTile(dense: true, title: Text(l.docNoLinked)),
                  for (final i in linked)
                    ListTile(
                      key: ValueKey('linked-${i.itemType.name}-${i.itemId}'),
                      dense: true,
                      leading: Icon(switch (i.itemType) {
                        DocumentItemType.task => Icons.check_circle_outline,
                        DocumentItemType.event => Icons.event_outlined,
                        DocumentItemType.goal => Icons.flag_outlined,
                      }),
                      title: Text(i.title ?? l.docItemMissing,
                          style: i.state == LinkedItemState.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
                      subtitle: Text([
                        l.docItemType(i.itemType.name),
                        if (_stateText(context, i.state) case final s?) s,
                      ].join(' · ')),
                      onTap: i.state == LinkedItemState.missing
                          ? null
                          : switch (i.itemType) {
                              DocumentItemType.task => () => openTaskPage(context, i.itemId),
                              DocumentItemType.goal => () => openGoalPage(context, i.itemId),
                              DocumentItemType.event => null,
                            },
                      trailing: widget.canEdit
                          ? IconButton(
                              key: ValueKey('unlink-${i.itemType.name}-${i.itemId}'),
                              tooltip: l.docUnlink,
                              icon: const Icon(Icons.link_off),
                              onPressed: () async {
                                await reportResult(
                                    context, ref.read(documentServiceProvider).unlink(widget.doc.id, i.itemType, i.itemId));
                                widget.onChanged();
                              },
                            )
                          : null,
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _stateText(BuildContext context, LinkedItemState s) => switch (s) {
      LinkedItemState.open => null,
      LinkedItemState.done => context.l10n.docItemDone,
      LinkedItemState.cancelled => context.l10n.docItemCancelled,
      LinkedItemState.trashed => context.l10n.docItemTrashed,
      LinkedItemState.missing => context.l10n.docItemMissing,
    };

// --- pickers -----------------------------------------------------------------

/// What `[[` offers: documents of the shown space by title, or "Create …".
class DocumentLinkPicker extends ConsumerStatefulWidget {
  const DocumentLinkPicker({super.key, this.excludeId});
  final String? excludeId;

  @override
  ConsumerState<DocumentLinkPicker> createState() => _DocumentLinkPickerState();
}

class _DocumentLinkPickerState extends ConsumerState<DocumentLinkPicker> {
  String _typed = '';
  late Future<List<DocumentNodeView>> _found = _find('');

  Future<List<DocumentNodeView>> _find(String v) =>
      ref.read(documentQueriesProvider).linkCandidates(v, excludeId: widget.excludeId);

  Future<void> _create() async {
    final title = _typed.trim();
    final r = await ref.read(documentServiceProvider).create(title);
    if (!mounted) return;
    if (r is CommandFailure) return showMessage(context, describeFailure(r));
    Navigator.pop(context, (id: (r as CommandOk).entityId, title: title));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const Key('doc-link-picker'),
      title: Text(l.docLinkPickerTitle),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('doc-link-search'),
            autofocus: true,
            decoration: InputDecoration(hintText: l.docLinkPickerHint, prefixIcon: const Icon(Icons.search)),
            onChanged: (v) => setState(() {
              _typed = v;
              _found = _find(v);
            }),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FutureBuilder<List<DocumentNodeView>>(
              future: _found,
              builder: (context, snap) => ListView(shrinkWrap: true, children: [
                for (final d in snap.data ?? const <DocumentNodeView>[])
                  ListTile(
                    key: ValueKey('doc-link-pick-${d.id}'),
                    leading: const Icon(Icons.description_outlined),
                    title: Text(d.title),
                    onTap: () => Navigator.pop(context, (id: d.id, title: d.title)),
                  ),
                if (_typed.trim().isNotEmpty && documentTitleError(_typed) == null && ref.read(canEditShownProvider))
                  ListTile(
                    key: const Key('doc-link-create'),
                    leading: const Icon(Icons.add),
                    title: Text(l.docCreateNamed(_typed.trim())),
                    onTap: _create,
                  ),
              ]),
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))],
    );
  }
}

/// "Link to a task or goal…": tasks found by title, and the goals.
class ItemLinkPicker extends ConsumerStatefulWidget {
  const ItemLinkPicker({super.key});

  @override
  ConsumerState<ItemLinkPicker> createState() => _ItemLinkPickerState();
}

class _ItemLinkPickerState extends ConsumerState<ItemLinkPicker> {
  Future<SearchResults> _found = Future.value(SearchResults.empty);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final goals = ref.watch(goalsProvider(false)).valueOrNull ?? const <GoalView>[];
    return AlertDialog(
      key: const Key('doc-item-picker'),
      title: Text(l.docPickItemTitle),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('doc-item-search'),
            autofocus: true,
            decoration: InputDecoration(hintText: l.docPickItemHint, prefixIcon: const Icon(Icons.search)),
            onChanged: (v) {
              final found = ref.read(searchQueriesProvider).search(v, limit: 20);
              setState(() {
                _found = found;
              });
            },
          ),
          Flexible(
            child: FutureBuilder<SearchResults>(
              future: _found,
              builder: (context, snap) => ListView(shrinkWrap: true, children: [
                for (final t in snap.data?.tasks ?? const <TaskHitView>[])
                  ListTile(
                    key: ValueKey('doc-item-task-${t.id}'),
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(t.title),
                    onTap: () => Navigator.pop(context, (type: DocumentItemType.task, id: t.id)),
                  ),
                if (goals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(l.docGoalsHeader, style: Theme.of(context).textTheme.titleSmall),
                  ),
                for (final g in goals)
                  ListTile(
                    key: ValueKey('doc-item-goal-${g.id}'),
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(g.title),
                    onTap: () => Navigator.pop(context, (type: DocumentItemType.goal, id: g.id)),
                  ),
              ]),
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))],
    );
  }
}

// --- files in the editor -----------------------------------------------------

class AttachmentEmbedBuilder extends q.EmbedBuilder {
  const AttachmentEmbedBuilder(this.files);
  final AttachmentService files;

  @override
  String get key => attachmentEmbedType;

  @override
  Widget build(BuildContext context, q.EmbedContext embedContext) {
    final a = attachmentOfEmbed(embedContext.node.value.data);
    if (a == null) return const SizedBox.shrink();
    // Keyed by the file: Quill may reuse a line's widget for another file.
    return AttachmentTile(key: ValueKey(a.hash), file: a, files: files);
  }
}

/// A file of a document: the picture itself, or the file with "Save a
/// copy" (a PDF also opens, ADR-0076); "On another device" or "Cannot be
/// read" otherwise (ADR-0072).
class AttachmentTile extends ConsumerStatefulWidget {
  const AttachmentTile({super.key, required this.file, required this.files});
  final AttachmentRef file;
  final AttachmentService files;

  @override
  ConsumerState<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends ConsumerState<AttachmentTile> {
  late final Future<AttachmentContent> _content = widget.file.isImage
      ? widget.files.open(widget.file.hash)
      : widget.files.availability(widget.file.hash).then((a) => AttachmentContent(a));

  Future<void> _saveCopy() async {
    final l = context.l10n;
    final c = await widget.files.open(widget.file.hash);
    final bytes = c.bytes;
    if (!mounted) return;
    if (bytes == null) return showMessage(context, l.docFileUnreadable(widget.file.name));
    final ok = await ref.read(fileGatewayProvider).saveBytes(widget.file.name, Uint8List.fromList(bytes), mime: widget.file.mime);
    if (ok && mounted) showMessage(context, l.docFileSaved(widget.file.name));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = widget.file;
    return FutureBuilder<AttachmentContent>(
      future: _content,
      builder: (context, snap) {
        final c = snap.data;
        final theme = Theme.of(context);
        Widget card(Widget child) => Card(
              key: ValueKey('doc-file-${f.hash}'),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: child,
            );
        if (c == null) return card(const SizedBox(height: 56));
        switch (c.availability) {
          case AttachmentAvailability.here when c.bytes != null && f.isImage:
            return card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: Image.memory(c.bytes!, fit: BoxFit.contain, semanticLabel: f.name,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
              ),
              ListTile(
                dense: true,
                title: Text(l.docFileHere(f.name, formatBytes(f.size))),
                trailing: IconButton(tooltip: l.docFileSaveCopy, icon: const Icon(Icons.download_outlined), onPressed: _saveCopy),
              ),
            ]));
          case AttachmentAvailability.here:
            // P05b D8: a PDF opens in the app from here (ADR-0076).
            final pdf = fileViewOf(f) == FileView.pdf;
            return card(ListTile(
              key: pdf ? ValueKey('doc-file-open-${f.hash}') : null,
              leading: Icon(pdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined),
              title: Text(l.docFileHere(f.name, formatBytes(f.size))),
              onTap: pdf ? () => openPdfPage(context, f, widget.files) : null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (pdf)
                  IconButton(
                      tooltip: l.pdfOpen(f.name),
                      icon: const Icon(Icons.chrome_reader_mode_outlined),
                      onPressed: () => openPdfPage(context, f, widget.files)),
                IconButton(
                    key: ValueKey('doc-file-save-${f.hash}'),
                    tooltip: l.docFileSaveCopy,
                    icon: const Icon(Icons.download_outlined),
                    onPressed: _saveCopy),
              ]),
            ));
          case AttachmentAvailability.elsewhere:
            return card(ListTile(
              key: ValueKey('doc-file-elsewhere-${f.hash}'),
              leading: Icon(Icons.devices_other, color: theme.colorScheme.outline),
              title: Text(l.docFileElsewhere(f.name, formatBytes(f.size))),
            ));
          case AttachmentAvailability.unreadable:
            return card(ListTile(
              leading: Icon(Icons.broken_image_outlined, color: theme.colorScheme.error),
              title: Text(l.docFileUnreadable(f.name)),
            ));
        }
      },
    );
  }
}

// --- history -------------------------------------------------------------------

/// The history, newest first (C5, C9); a version opens to be read and can
/// be restored as a new one.
class DocumentHistoryPage extends ConsumerWidget {
  const DocumentHistoryPage({super.key, required this.documentId, required this.canRestore});
  final String documentId;
  final bool canRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final space = ref.watch(shownSharedSpaceProvider);
    final names =
        space == null ? const <String, String>{} : ref.watch(memberNamesProvider(space.id)).valueOrNull ?? const <String, String>{};
    return Scaffold(
      appBar: AppBar(title: Text(l.docHistory)),
      body: FutureBuilder<List<DocumentRevisionView>>(
        future: ref.read(documentQueriesProvider).revisions(documentId),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return Center(child: CircularProgressIndicator(semanticsLabel: l.loading));
          final ml = MaterialLocalizations.of(context);
          return ListView(key: const Key('doc-history'), children: [
            for (final r in list)
              ListTile(
                key: ValueKey('revision-${r.id}'),
                leading: Icon(switch (r.reason) {
                  RevisionReason.save => Icons.save_outlined,
                  RevisionReason.conflict => Icons.call_split,
                  RevisionReason.restore => Icons.restore,
                }),
                title: Text(l.docRevision(r.documentVersion)),
                subtitle: Text(l.docRevisionMeta(
                  switch (r.reason) {
                    RevisionReason.save => l.docReasonSave,
                    RevisionReason.conflict => l.docReasonConflict,
                    RevisionReason.restore => l.docReasonRestore,
                  },
                  '${ml.formatShortDate(r.savedAt.utc.toLocal())} ${ml.formatTimeOfDay(TimeOfDay.fromDateTime(r.savedAt.utc.toLocal()))}',
                  [
                    r.author == null ? l.docByYou : (names[r.author] ?? l.spSomeone),
                    if (r.deviceId case final d?) d,
                  ].join(', '),
                )),
                onTap: () async {
                  final restored = await Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => RevisionPage(documentId: documentId, revision: r, canRestore: canRestore)));
                  if (restored == true && context.mounted) Navigator.of(context).pop(true);
                },
              ),
          ]);
        },
      ),
    );
  }
}

class RevisionPage extends ConsumerStatefulWidget {
  const RevisionPage({super.key, required this.documentId, required this.revision, required this.canRestore});
  final String documentId;
  final DocumentRevisionView revision;
  final bool canRestore;

  @override
  ConsumerState<RevisionPage> createState() => _RevisionPageState();
}

class _RevisionPageState extends ConsumerState<RevisionPage> {
  late final AttachmentService _files = ref.read(attachmentServiceProvider);
  q.QuillController? _c;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ref.read(documentQueriesProvider).revisionContent(widget.revision.id).then((content) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        if (content != null) {
          _c = q.QuillController(
            document: quillDocumentOf(content.$2),
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: true,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _c;
    return Scaffold(
      appBar: AppBar(
        title: Text([widget.revision.title, l.docRevision(widget.revision.documentVersion)].join(' · '),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.canRestore && c != null)
            TextButton(
              key: const Key('revision-restore'),
              onPressed: () async {
                final r = await reportResult(
                    context, ref.read(documentServiceProvider).restoreRevision(widget.documentId, widget.revision.id));
                if (r is CommandOk && context.mounted) {
                  showMessage(context, l.docRestored);
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(l.docRestoreVersion),
            ),
        ],
      ),
      body: !_loaded
          ? Center(child: CircularProgressIndicator(semanticsLabel: l.loading))
          : c == null
              ? Center(child: Text(l.docVersionUnreadable, key: const Key('revision-unreadable')))
              : q.QuillEditor.basic(
                  controller: c,
                  config: q.QuillEditorConfig(
                    padding: const EdgeInsets.all(16),
                    maxContentWidth: 760,
                    embedBuilders: [AttachmentEmbedBuilder(_files)],
                  ),
                ),
    );
  }
}

// --- an item's documents (its page) ------------------------------------------

/// The documents linked to a task, an event or a goal, on the item's page.
class ItemDocumentsSection extends ConsumerWidget {
  const ItemDocumentsSection({super.key, required this.type, required this.itemId});
  final DocumentItemType type;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(itemDocumentsProvider((type: type, id: itemId))).valueOrNull ?? const <DocumentNodeView>[];
    if (docs.isEmpty) return const SizedBox.shrink();
    return Column(key: const Key('item-documents'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Semantics(header: true, child: Text(context.l10n.docItemDocuments, style: Theme.of(context).textTheme.titleSmall)),
      ),
      for (final d in docs)
        ListTile(
          key: ValueKey('item-doc-${d.id}'),
          leading: const Icon(Icons.description_outlined),
          title: Text(d.title),
          onTap: () => openDocumentPage(context, d.id),
        ),
    ]);
  }
}
