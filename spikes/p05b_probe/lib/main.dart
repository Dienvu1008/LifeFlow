// P05b spikes S-08 (PDF), S-09 (DOCX), S-12 (voices). Throwaway: not for main.
// One app with three tabs so the owner installs one thing on each device.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

void main() {
  pdfrxFlutterInitialize();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Probe()));
}

class Probe extends StatelessWidget {
  const Probe({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('P05b probe · S-08 · S-09 · S-12'),
            bottom: const TabBar(tabs: [Tab(text: 'PDF'), Tab(text: 'DOCX'), Tab(text: 'Voices')]),
          ),
          body: const TabBarView(physics: NeverScrollableScrollPhysics(), children: [PdfTab(), DocxTab(), VoiceTab()]),
        ),
      );
}

Future<(String, Uint8List)?> pick(List<String> ext) async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ext);
  if (f == null) return null;
  return (f.name, await f.readAsBytes());
}

// --- S-08: PDF ------------------------------------------------------------------

class PdfTab extends StatefulWidget {
  const PdfTab({super.key});
  @override
  State<PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<PdfTab> with AutomaticKeepAliveClientMixin {
  final _controller = PdfViewerController();
  late final _searcher = PdfTextSearcher(_controller)..addListener(_update);
  (String, Uint8List)? _file;
  String _status = 'Open a PDF (from memory, never a path: as LifeFlow will).';
  String _selected = '';
  final _query = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  void _update() {
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    final f = await pick(['pdf']);
    if (f == null) return;
    setState(() {
      _file = f;
      _status = 'Opening ${f.$1} (${(f.$2.length / 1024).round()} KB)…';
    });
  }

  Future<void> _extract() async {
    final doc = _controller.document;
    final sw = Stopwatch()..start();
    final b = StringBuffer();
    var pages = 0;
    for (final p in doc.pages) {
      final t = await p.loadText();
      b.writeln(t?.fullText ?? '');
      pages++;
    }
    sw.stop();
    final text = b.toString();
    if (!mounted) return;
    setState(() => _status = 'Text of $pages pages: ${text.length} characters in ${sw.elapsedMilliseconds} ms');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extracted text (check the Vietnamese marks)'),
        content: SizedBox(
            width: 640,
            child: SingleChildScrollView(child: SelectableText(text.length > 6000 ? '${text.substring(0, 6000)}…' : text))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final f = _file;
    return Column(children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
        FilledButton(onPressed: _open, child: const Text('Open PDF')),
        if (f != null) ...[
          SizedBox(
            width: 220,
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(hintText: 'Find (e.g. ghi chú)', isDense: true),
              onSubmitted: (v) => _searcher.startTextSearch(v, caseInsensitive: true),
            ),
          ),
          IconButton(tooltip: 'Previous', icon: const Icon(Icons.keyboard_arrow_up), onPressed: _searcher.goToPrevMatch),
          IconButton(tooltip: 'Next', icon: const Icon(Icons.keyboard_arrow_down), onPressed: _searcher.goToNextMatch),
          Text(_searcher.isSearching ? 'searching…' : '${_searcher.matches.length} found'),
          OutlinedButton(onPressed: _extract, child: const Text('Extract all text')),
          OutlinedButton(onPressed: () => _controller.zoomUp(), child: const Text('Zoom +')),
          OutlinedButton(onPressed: () => _controller.zoomDown(), child: const Text('Zoom −')),
        ],
      ]),
      Padding(padding: const EdgeInsets.all(4), child: Text(_status, style: Theme.of(context).textTheme.bodySmall)),
      if (_selected.isNotEmpty)
        Padding(
            padding: const EdgeInsets.all(4),
            child: Text('Selected: ${_selected.length > 120 ? '${_selected.substring(0, 120)}…' : _selected}')),
      const Divider(height: 1),
      Expanded(
        child: f == null
            ? const SizedBox.shrink()
            : PdfViewer.data(
                f.$2,
                key: ValueKey(f.$1 + f.$2.length.toString()),
                sourceName: f.$1,
                controller: _controller,
                params: PdfViewerParams(
                  pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
                  onViewerReady: (doc, c) => setState(() => _status = '${f.$1}: ${doc.pages.length} pages, ready'),
                  textSelectionParams: PdfTextSelectionParams(
                    onTextSelectionChange: (s) async {
                      final t = await s.getSelectedText();
                      if (mounted) setState(() => _selected = t);
                    },
                  ),
                ),
              ),
      ),
    ]);
  }
}

// --- S-09: DOCX -> blocks (throwaway reader) ----------------------------------------

class Para {
  Para(this.kind, this.text, {this.level = 0});
  final String kind; // heading1..3, bullet, numbered, table, paragraph, picture
  final String text;
  final int level;
}

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

({List<Para> blocks, Map<String, int> lost}) readDocx(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  final doc = zip.files.firstWhere((f) => f.name == 'word/document.xml');
  final styles = zip.files.where((f) => f.name == 'word/styles.xml').firstOrNull;
  // Heading styles by id ("Heading1", or a localized name "Tiêu đề 1" with outline level).
  final headingOf = <String, int>{};
  if (styles != null) {
    final s = XmlDocument.parse(utf8.decode(styles.readBytes()!));
    for (final st in s.findAllElements('style', namespaceUri: _w)) {
      final id = st.getAttribute('styleId', namespaceUri: _w) ?? '';
      final outline = st.findAllElements('outlineLvl', namespaceUri: _w).firstOrNull?.getAttribute('val', namespaceUri: _w);
      final m = RegExp(r'^[Hh]eading(\d)$').firstMatch(id);
      if (m != null) headingOf[id] = int.parse(m.group(1)!);
      if (outline != null) headingOf[id] = int.parse(outline) + 1;
    }
  }
  final x = XmlDocument.parse(utf8.decode(doc.readBytes()!));
  final out = <Para>[];
  final lost = <String, int>{};
  void count(String k) => lost[k] = (lost[k] ?? 0) + 1;
  String textOf(XmlElement e) {
    final b = StringBuffer();
    for (final n in e.descendants.whereType<XmlElement>()) {
      if (n.name.local == 't' && n.name.namespaceUri == _w) b.write(n.innerText);
      if (n.name.local == 'tab') b.write('\t');
      if (n.name.local == 'br') b.write('\n');
    }
    return b.toString();
  }

  final body = x.findAllElements('body', namespaceUri: _w).first;
  for (final e in body.childElements) {
    if (e.name.local == 'tbl') {
      for (final row in e.findAllElements('tr', namespaceUri: _w)) {
        out.add(Para('table', [for (final c in row.findElements('tc', namespaceUri: _w)) textOf(c).trim()].join(' | ')));
      }
      continue;
    }
    if (e.name.local != 'p') continue;
    if (e.findAllElements('drawing', namespaceUri: _w).isNotEmpty) {
      out.add(Para('picture', '[picture]'));
    }
    if (e.findAllElements('del', namespaceUri: _w).isNotEmpty || e.findAllElements('ins', namespaceUri: _w).isNotEmpty) {
      count('tracked changes');
    }
    if (e.findAllElements('commentReference', namespaceUri: _w).isNotEmpty) count('comments');
    if (e.findAllElements('color', namespaceUri: _w).isNotEmpty) count('text colour');
    final ppr = e.findElements('pPr', namespaceUri: _w).firstOrNull;
    final style = ppr?.findElements('pStyle', namespaceUri: _w).firstOrNull?.getAttribute('val', namespaceUri: _w) ?? '';
    final numPr = ppr?.findElements('numPr', namespaceUri: _w).firstOrNull;
    final text = textOf(e);
    if (text.trim().isEmpty && out.isNotEmpty && out.last.kind == 'picture') continue;
    if (headingOf[style] case final h? when h <= 3) {
      out.add(Para('heading$h', text));
    } else if (numPr != null) {
      final lvl = int.tryParse(numPr.findElements('ilvl', namespaceUri: _w).firstOrNull?.getAttribute('val', namespaceUri: _w) ?? '0') ?? 0;
      out.add(Para('list', text, level: lvl)); // bullet or numbered: needs numbering.xml (T3)
    } else {
      out.add(Para('paragraph', text));
    }
  }
  return (blocks: out, lost: lost);
}

class DocxTab extends StatefulWidget {
  const DocxTab({super.key});
  @override
  State<DocxTab> createState() => _DocxTabState();
}

class _DocxTabState extends State<DocxTab> with AutomaticKeepAliveClientMixin {
  List<Para> _blocks = const [];
  String _status = 'Open a DOCX from Word or Google Docs.';
  @override
  bool get wantKeepAlive => true;

  Future<void> _open() async {
    final f = await pick(['docx']);
    if (f == null) return;
    final sw = Stopwatch()..start();
    try {
      final r = readDocx(f.$2);
      sw.stop();
      setState(() {
        _blocks = r.blocks;
        _status = '${f.$1}: ${r.blocks.length} blocks in ${sw.elapsedMilliseconds} ms. '
            'Not kept: ${r.lost.isEmpty ? 'nothing seen' : r.lost.entries.map((e) => '${e.key} ×${e.value}').join(', ')}';
      });
    } catch (e) {
      setState(() => _status = 'Could not read ${f.$1}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Row(children: [Padding(padding: const EdgeInsets.all(8), child: FilledButton(onPressed: _open, child: const Text('Open DOCX')))]),
      Padding(padding: const EdgeInsets.all(4), child: Text(_status, style: t.bodySmall)),
      const Divider(height: 1),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final b in _blocks)
            Padding(
              padding: EdgeInsets.only(left: 20.0 * b.level, bottom: 6),
              child: switch (b.kind) {
                'heading1' => Text(b.text, style: t.headlineSmall),
                'heading2' => Text(b.text, style: t.titleLarge),
                'heading3' => Text(b.text, style: t.titleMedium),
                'list' => Text('•  ${b.text}'),
                'table' => Text(b.text, style: const TextStyle(fontFamily: 'monospace')),
                'picture' => const Text('[picture]', style: TextStyle(color: Colors.grey)),
                _ => Text(b.text),
              },
            ),
        ]),
      ),
    ]);
  }
}

// --- S-12: voices ---------------------------------------------------------------------

const _sample = 'Hôm nay là thứ Hai. Cuộc họp bắt đầu lúc chín giờ sáng ở Đà Nẵng. '
    'Nhớ mang theo ghi chú họp và kế hoạch tuần! Sau đó, chúng ta ăn trưa cùng nhau.';

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});
  @override
  State<VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<VoiceTab> with AutomaticKeepAliveClientMixin {
  final _tts = FlutterTts();
  final _text = TextEditingController(text: _sample);
  List<Map<String, String>> _voices = const [];
  Map<String, String>? _voice;
  double _rate = 0.5;
  int _sentence = -1;
  List<String> _sentences = const [];
  bool _playing = false;
  final _log = <String>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tts.setStartHandler(() => _note('start'));
    _tts.setCompletionHandler(() {
      _note('complete');
      // One sentence at a time: the next one starts when this one ends.
      // This is how the highlight follows on both platforms, even where
      // there are no word progress events (Windows).
      if (_playing) _speakFrom(_sentence + 1);
    });
    _tts.setCancelHandler(() => _note('cancel'));
    _tts.setPauseHandler(() => _note('pause'));
    _tts.setContinueHandler(() => _note('continue'));
    _tts.setErrorHandler((m) => _note('error $m'));
    _tts.setProgressHandler((t, s, e, w) => _note('progress "$w"'));
    _load();
  }

  void _note(String s) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)} $s');
      if (_log.length > 30) _log.removeLast();
    });
  }

  Future<void> _load() async {
    final raw = await _tts.getVoices;
    final list = <Map<String, String>>[
      for (final v in (raw as List? ?? const []))
        if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'}
    ];
    list.sort((a, b) => (a['locale'] ?? '').compareTo(b['locale'] ?? ''));
    setState(() {
      _voices = list;
      _voice = list.where((v) => (v['locale'] ?? '').toLowerCase().startsWith('vi')).firstOrNull;
    });
    _note('${list.length} voices; Vietnamese: ${list.where((v) => (v['locale'] ?? '').toLowerCase().startsWith('vi')).length}');
  }

  List<String> _split(String s) =>
      [for (final m in RegExp(r'[^.!?…]+[.!?…]*').allMatches(s)) m.group(0)!.trim()].where((x) => x.isNotEmpty).toList();

  Future<void> _speakFrom(int i) async {
    if (i >= _sentences.length) {
      setState(() {
        _playing = false;
        _sentence = -1;
      });
      return;
    }
    setState(() => _sentence = i);
    await _tts.speak(_sentences[i]);
  }

  Future<void> _play() async {
    final v = _voice;
    if (v != null) await _tts.setVoice({'name': v['name'] ?? '', 'locale': v['locale'] ?? ''});
    await _tts.setSpeechRate(_rate);
    setState(() {
      _sentences = _split(_text.text);
      _playing = true;
    });
    await _speakFrom(0);
  }

  Future<void> _stop() async {
    setState(() => _playing = false);
    await _tts.stop();
    setState(() => _sentence = -1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(padding: const EdgeInsets.all(12), children: [
      DropdownButton<Map<String, String>>(
        isExpanded: true,
        value: _voice,
        hint: const Text('No Vietnamese voice found: pick another, or install one'),
        items: [for (final v in _voices) DropdownMenuItem(value: v, child: Text('${v['locale']} · ${v['name']}'))],
        onChanged: (v) => setState(() => _voice = v),
      ),
      Row(children: [
        const Text('Speed'),
        Expanded(
          child: Slider(value: _rate, min: 0.1, max: 1.0, divisions: 18, label: _rate.toStringAsFixed(2), onChanged: (v) => setState(() => _rate = v)),
        ),
        Text(_rate.toStringAsFixed(2)),
      ]),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: _playing ? null : _play, child: const Text('Read')),
        OutlinedButton(onPressed: _tts.pause, child: const Text('Pause')),
        OutlinedButton(onPressed: _stop, child: const Text('Stop')),
      ]),
      const SizedBox(height: 8),
      TextField(controller: _text, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Wrap(children: [
        for (final (i, s) in _sentences.indexed)
          Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(4),
            color: i == _sentence ? Colors.yellow.shade200 : null,
            child: Text(s),
          ),
      ]),
      const Divider(),
      for (final l in _log) Text(l, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
