// S-07 (throwaway): super_editor probe. Not for main.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:s07_common/s07_common.dart';
import 'package:super_editor/super_editor.dart';

import 'adapter.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Probe()));

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  Timer? _idle;
  int _saves = 0;
  String _status = '';
  String _lastSaved = '';
  bool _picking = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(sampleDocument(), 'sample');
  }

  void _load(List<Block> blocks, String what) {
    final sw = Stopwatch()..start();
    _doc = documentOf(blocks);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer, isHistoryEnabled: true);
    _doc.addListener(_changed);
    _generation++;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sw.stop();
      setState(() => _status = 'Loaded $what: ${blocks.length} blocks, first frame after ${sw.elapsedMilliseconds} ms');
    });
  }

  void _changed(DocumentChangeLog _) {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 10), () => _save('10 s idle'));
    _checkLinkTrigger();
  }

  void _save(String why) {
    final sw = Stopwatch()..start();
    final body = encodeBlocks(toBlocks(_doc));
    sw.stop();
    setState(() {
      _saves++;
      _lastSaved = body;
      _status = 'Saved ($why) #$_saves: ${body.length} chars in ${sw.elapsedMilliseconds} ms';
    });
  }

  // --- [[ links ---------------------------------------------------------

  void _checkLinkTrigger() {
    if (_picking) return;
    final sel = _composer.selection;
    if (sel == null || !sel.isCollapsed) return;
    final node = _doc.getNodeById(sel.extent.nodeId);
    final pos = sel.extent.nodePosition;
    if (node is! TextNode || pos is! TextNodePosition) return;
    final text = node.text.text;
    final off = pos.offset;
    if (off < 2 || text.substring(off - 2, off) != '[[') return;
    _picking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick(node.id, off));
  }

  Future<void> _pick(String nodeId, int off) async {
    final picked = await showDialog<MapEntry<String, String>>(context: context, builder: (_) => const _Picker());
    _picking = false;
    if (picked == null) return;
    final node = _doc.getNodeById(nodeId);
    if (node is! TextNode) return;
    final b = toBlocks(MutableDocument(nodes: [node])).single;
    final before = spansOf(node.text.copyText(0, off - 2));
    final after = spansOf(node.text.copyText(off));
    final spans = [...before, Span(picked.value, link: picked.key), ...after];
    _editor.execute([
      ReplaceNodeRequest(
          existingNodeId: nodeId, newNode: nodeOf(Block(b.id, b.type, spans: spans, checked: b.checked, image: b.image))),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: off - 2 + picked.value.length))),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  // --- toolbar --------------------------------------------------------------

  void _setType(BlockType t) {
    final sel = _composer.selection;
    if (sel == null) return;
    final node = _doc.getNodeById(sel.extent.nodeId);
    if (node is! TextNode) return;
    final b = toBlocks(MutableDocument(nodes: [node])).single;
    _editor.execute([
      ReplaceNodeRequest(existingNodeId: node.id, newNode: nodeOf(Block(node.id, t, spans: b.spans, checked: false))),
      ChangeSelectionRequest(sel, SelectionChangeType.placeCaret, SelectionReason.userInteraction),
    ]);
  }

  void _toggle(Attribution a) {
    final sel = _composer.selection;
    if (sel == null || sel.isCollapsed) return;
    _editor.execute([ToggleTextAttributionsRequest(documentRange: sel, attributions: {a})]);
  }

  void _insertImage() {
    final sel = _composer.selection;
    final after = sel?.extent.nodeId ?? _doc.last.id;
    _editor.execute([InsertNodeAfterNodeRequest(existingNodeId: after, newNode: ImageNode(id: newBlockId(), imageUrl: 'sha256-photo-${_saves + 1}'))]);
  }

  void _roundTrip() {
    final a = encodeBlocks(toBlocks(_doc));
    final b = encodeBlocks(toBlocks(documentOf(decodeBlocks(a))));
    setState(() => _status = a == b ? 'Round trip OK (${a.length} chars, ${_doc.length} blocks)' : 'Round trip DIFFERS');
  }

  void _showBody() {
    final body = _lastSaved.isEmpty ? encodeBlocks(toBlocks(_doc)) : _lastSaved;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stored body (LifeFlow format)'),
        content: SizedBox(width: 600, child: SingleChildScrollView(child: SelectableText(body.length > 4000 ? '${body.substring(0, 4000)}…' : body))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget b(String label, VoidCallback f) => Padding(
          padding: const EdgeInsets.all(2),
          child: OutlinedButton(onPressed: f, style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(label)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('S-07 · super_editor 0.3.0-dev.52 · round 2')),
      body: Column(children: [
        Wrap(children: [
          b('P', () => _setType(BlockType.paragraph)),
          b('H1', () => _setType(BlockType.heading1)),
          b('H2', () => _setType(BlockType.heading2)),
          b('•', () => _setType(BlockType.bullet)),
          b('1.', () => _setType(BlockType.numbered)),
          b('☐', () => _setType(BlockType.todo)),
          b('B', () => _toggle(boldAttribution)),
          b('I', () => _toggle(italicsAttribution)),
          b('Undo', () => _editor.undo()),
          b('Redo', () => _editor.redo()),
          b('Image', _insertImage),
          b('Save now', () => _save('button')),
          b('Round trip', _roundTrip),
          b('Body', _showBody),
          b('Sample', () => _load(sampleDocument(), 'sample')),
          b('50 pages', () => _load(bigDocument(), '50 pages')),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(_status.isEmpty ? 'Type "[[" for a link. Saves after 10 s without typing.' : _status,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const Divider(height: 1),
        Expanded(
          child: SuperEditor(
            key: ValueKey(_generation),
            editor: _editor,
            stylesheet: defaultStylesheet.copyWith(
              documentPadding: const EdgeInsets.all(24),
              addRulesAfter: [
                // S-07 round 2: the default spacing (24 px above each
                // paragraph, 18 px text) is too loose.
                StyleRule(BlockSelector.all, (doc, node) => {
                      Styles.textStyle: const TextStyle(fontSize: 16, height: 1.45),
                    }),
                for (final b in ['paragraph', 'listItem', 'task'])
                  StyleRule(BlockSelector(b), (doc, node) => {Styles.padding: const CascadingPadding.only(top: 8)}),
                StyleRule(const BlockSelector('header1'), (doc, node) => {
                      Styles.padding: const CascadingPadding.only(top: 24),
                      Styles.textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    }),
                StyleRule(const BlockSelector('header2'), (doc, node) => {
                      Styles.padding: const CascadingPadding.only(top: 20),
                      Styles.textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    }),
              ],
            ),
            componentBuilders: [
              _AttachmentBuilder(),
              // S-07 round 2: not in defaultComponentBuilders (it needs the
              // editor to tick); its absence was the "not a DocumentComponent" error.
              TaskComponentBuilder(_editor),
              ...defaultComponentBuilders,
            ],
          ),
        ),
      ]),
    );
  }
}

/// A custom block: an attachment kept on another device shows its name.
class _AttachmentBuilder implements ComponentBuilder {
  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) => node is ImageNode
      ? ImageComponentViewModel(nodeId: node.id, imageUrl: node.imageUrl, selectionColor: const Color(0x00000000))
      : null;

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext context, SingleColumnLayoutComponentViewModel vm) {
    if (vm is! ImageComponentViewModel) return null;
    return ImageComponent(
      componentKey: context.componentKey,
      imageUrl: vm.imageUrl,
      selection: vm.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: vm.selectionColor,
      imageBuilder: (ctx, url) => Container(
        height: 80,
        alignment: Alignment.center,
        color: const Color(0xFFEDEDED),
        child: Text('🖼  Attachment on another device ($url)'),
      ),
    );
  }
}

class _Picker extends StatefulWidget {
  const _Picker();
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final items = fakeDocuments.entries.where((e) => e.value.toLowerCase().contains(_q.toLowerCase())).toList();
    return AlertDialog(
      title: const Text('Link to a document'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(autofocus: true, decoration: const InputDecoration(hintText: 'Tìm…'), onChanged: (v) => setState(() => _q = v)),
          for (final e in items) ListTile(title: Text(e.value), onTap: () => Navigator.pop(context, e)),
        ]),
      ),
    );
  }
}
