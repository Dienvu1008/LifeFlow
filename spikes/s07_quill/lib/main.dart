// S-07 (throwaway): flutter_quill probe. Not for main.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:s07_common/s07_common.dart';

import 'adapter.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: Probe(),
    ));

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  late QuillController _c;
  StreamSubscription<DocChange>? _sub;
  List<String> _ids = [];
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
    _sub?.cancel();
    _ids = [for (final b in blocks) b.id];
    _c = QuillController(document: documentOf(blocks), selection: const TextSelection.collapsed(offset: 0));
    _sub = _c.changes.listen((_) => _changed());
    _c.addListener(_checkLinkTrigger);
    _generation++;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sw.stop();
      setState(() => _status = 'Loaded $what: ${blocks.length} blocks, first frame after ${sw.elapsedMilliseconds} ms');
    });
  }

  void _changed() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 10), () => _save('10 s idle'));
  }

  void _save(String why) {
    final sw = Stopwatch()..start();
    final blocks = toBlocks(_c.document.toDelta(), ids: _ids);
    _ids = [for (final b in blocks) b.id];
    final body = encodeBlocks(blocks);
    sw.stop();
    setState(() {
      _saves++;
      _lastSaved = body;
      _status = 'Saved ($why) #$_saves: ${body.length} chars in ${sw.elapsedMilliseconds} ms';
    });
  }

  void _checkLinkTrigger() {
    if (_picking) return;
    final sel = _c.selection;
    if (!sel.isCollapsed) return;
    final off = sel.baseOffset;
    final text = _c.document.toPlainText();
    if (off < 2 || off > text.length || text.substring(off - 2, off) != '[[') return;
    _picking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick(off));
  }

  Future<void> _pick(int off) async {
    final picked = await showDialog<MapEntry<String, String>>(context: context, builder: (_) => const _Picker());
    _picking = false;
    if (picked == null) return;
    final title = picked.value;
    _c.replaceText(off - 2, 2, title, TextSelection.collapsed(offset: off - 2 + title.length));
    _c.formatText(off - 2, title.length, LinkAttribute('$docScheme${picked.key}'));
  }

  void _block(Attribute a) => _c.formatSelection(a);

  /// S-07 round 2: B and I switch off when they are on (the probe set them always).
  void _toggle(Attribute a) {
    final on = _c.getSelectionStyle().attributes.containsKey(a.key);
    _c.formatSelection(on ? Attribute.clone(a, null) : a);
  }

  void _paragraph() {
    _c.formatSelection(Attribute.clone(Attribute.header, null));
    _c.formatSelection(Attribute.clone(Attribute.list, null));
  }

  void _insertImage() {
    final i = _c.selection.baseOffset;
    // S-07 round 2: a text line after the image, so the cursor has a place
    // to go below it.
    _c.replaceText(i, 0, BlockEmbed.image('sha256-photo-${_saves + 1}'), null);
    _c.replaceText(i + 1, 0, '\n', TextSelection.collapsed(offset: i + 2));
  }

  void _roundTrip() {
    final blocks = toBlocks(_c.document.toDelta(), ids: _ids);
    final a = encodeBlocks(blocks);
    final b = encodeBlocks(toBlocks(documentOf(decodeBlocks(a)).toDelta(), ids: [for (final x in blocks) x.id]));
    setState(() => _status = a == b ? 'Round trip OK (${a.length} chars, ${blocks.length} blocks)' : 'Round trip DIFFERS');
  }

  void _showBody() {
    final body = _lastSaved.isEmpty ? encodeBlocks(toBlocks(_c.document.toDelta(), ids: _ids)) : _lastSaved;
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
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget b(String label, VoidCallback f) => Padding(
          padding: const EdgeInsets.all(2),
          child: OutlinedButton(onPressed: f, style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(label)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('S-07 · flutter_quill 11.6.0 · round 2')),
      body: Column(children: [
        Wrap(children: [
          b('P', _paragraph),
          b('H1', () => _block(Attribute.h1)),
          b('H2', () => _block(Attribute.h2)),
          b('•', () => _block(Attribute.ul)),
          b('1.', () => _block(Attribute.ol)),
          b('☐', () => _block(Attribute.unchecked)),
          b('B', () => _toggle(Attribute.bold)),
          b('I', () => _toggle(Attribute.italic)),
          b('Undo', _c.undo),
          b('Redo', _c.redo),
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
          child: QuillEditor.basic(
            key: ValueKey(_generation),
            controller: _c,
            config: QuillEditorConfig(
              padding: const EdgeInsets.all(24),
              maxContentWidth: 680, // S-07 round 2: a page width, as super_editor
              embedBuilders: const [_AttachmentEmbed()],
              customStyles: DefaultStyles(
                link: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A custom block: an attachment kept on another device shows its name.
class _AttachmentEmbed extends EmbedBuilder {
  const _AttachmentEmbed();
  @override
  String get key => BlockEmbed.imageType;
  @override
  Widget build(BuildContext context, EmbedContext embedContext) => Container(
        height: 80,
        alignment: Alignment.center,
        color: const Color(0xFFEDEDED),
        child: Text('🖼  Attachment on another device (${embedContext.node.value.data})'),
      );
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
