// P06 T7 (ADR-0087; the owner's D2–D5, D10, and S-17): Settings → Assistant.
//   engine   which model to try first
//   local    the pinned models of this device: size, license, memory; the
//            recommended one; on a phone each is marked slow and not
//            recommended, and a warning comes before the download (owner,
//            S-17); download with progress and cancel; use, delete; "Use a
//            model file"
//   cloud    off by default (D2); provider, address, key (kept in secure
//            storage, never shown again), model listed from the provider,
//            the monthly token limit and this month's tokens (D10)
//   plan     the hours of a day plan; the language of plans
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../providers.dart';

/// "1.3 GB", "533 MB".
String formatModelSize(int bytes) =>
    bytes >= 1000 * 1000 * 1000 ? '${(bytes / 1e9).toStringAsFixed(1)} GB' : '${(bytes / 1e6).round()} MB';

/// The entry in Settings; only where the app wires the assistant.
class AssistantSettingsTile extends ConsumerWidget {
  const AssistantSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(aiSetupProvider) == null) return const SizedBox.shrink();
    final l = context.l10n;
    return ListTile(
      key: const Key('assistant-settings'),
      leading: const Icon(Icons.auto_awesome),
      title: Text(l.aiAssistant),
      subtitle: Text(l.aiSettingsHint),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/settings/assistant'),
    );
  }
}

class AssistantSettingsScreen extends ConsumerStatefulWidget {
  const AssistantSettingsScreen({super.key});

  @override
  ConsumerState<AssistantSettingsScreen> createState() => _AssistantSettingsScreenState();
}

class _AssistantSettingsScreenState extends ConsumerState<AssistantSettingsScreen> {
  AiSetupService? _setup;
  AiAssistantSettings? _s;
  List<InstalledModel> _installed = const [];
  InstalledModel? _selected;
  final _progress = <String, double>{};
  final _cancels = <String, AiCancel>{};

  CloudProvider _provider = CloudProvider.openai;
  final _address = TextEditingController();
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _cap = TextEditingController();
  bool _hasKey = false;
  List<String> _models = const [];
  int _used = 0;

  @override
  void initState() {
    super.initState();
    _setup = ref.read(aiSetupProvider);
    _load();
  }

  @override
  void dispose() {
    for (final c in _cancels.values) {
      c.cancel();
    }
    for (final c in [_address, _key, _model, _cap]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final setup = _setup;
    if (setup == null) return;
    final s = await setup.settings();
    final cloud = await setup.cloud();
    final installed = await setup.models.installed();
    final selected = await setup.models.selected();
    final used = await setup.tokensThisMonth();
    if (cloud != null) {
      _provider = cloud.provider;
      _address.text = cloud.baseUrl ?? '';
      _model.text = cloud.model;
      _cap.text = cloud.monthlyTokenCap?.toString() ?? '';
    }
    final hasKey = await setup.hasKey(_provider);
    if (!mounted) return;
    setState(() {
      _s = s;
      _installed = installed;
      _selected = selected;
      _used = used;
      _hasKey = hasKey;
    });
  }

  Future<void> _saveSettings(AiAssistantSettings s) async {
    await _setup!.setSettings(s);
    setState(() => _s = s);
  }

  Future<void> _refreshModels() async {
    final installed = await _setup!.models.installed();
    final selected = await _setup!.models.selected();
    if (mounted) {
      setState(() {
        _installed = installed;
        _selected = selected;
      });
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
            FilledButton(key: const Key('ai-confirm'), onPressed: () => Navigator.pop(context, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Future<void> _download(LocalModelInfo m) async {
    final l = context.l10n;
    final setup = _setup!;
    final slow = m.slowOn.contains(setup.platform);
    final ok = slow
        ? await _confirm(l.aiSlowWarningTitle, '${l.aiSlowWarningBody}\n\n${l.aiDownloadBody(formatModelSize(m.sizeBytes))}', l.aiDownloadAnyway)
        : await _confirm(m.name, l.aiDownloadBody(formatModelSize(m.sizeBytes)), l.aiDownload);
    if (!ok || !mounted) return;
    final cancel = _cancels[m.id] = AiCancel();
    setState(() => _progress[m.id] = 0);
    try {
      final got = await setup.models.download(m.id, cancel: cancel, onProgress: (have, total) {
        if (mounted) setState(() => _progress[m.id] = total == 0 ? 0 : have / total);
      });
      if (await setup.models.selected() == null) await setup.models.select(got.id);
    } on LocalModelFailure catch (e) {
      if (mounted && e.kind != LocalModelFailureKind.cancelled) _snack(l.aiDownloadFailed(e.kind.name));
    } finally {
      _cancels.remove(m.id);
      if (mounted) setState(() => _progress.remove(m.id));
      await _refreshModels();
    }
  }

  Future<void> _useFile() async {
    final l = context.l10n;
    final picker = ref.read(aiModelFilePickerProvider);
    String? path;
    if (picker != null) {
      path = await picker();
    } else {
      path = await showDialog<String>(context: context, builder: (_) => const _PathDialog());

    }
    if (path == null || path.isEmpty || !mounted) return;
    try {
      final m = await _setup!.models.importFile(path);
      await _setup!.models.select(m.id);
    } on LocalModelFailure catch (e) {
      if (mounted) _snack(e.kind == LocalModelFailureKind.notGguf ? l.aiNotGguf : l.aiDownloadFailed(e.kind.name));
    }
    await _refreshModels();
  }

  Future<void> _saveCloud() async {
    final setup = _setup!;
    final model = _model.text.trim();
    final cap = int.tryParse(_cap.text.trim());
    await setup.setCloud(model.isEmpty
        ? null
        : CloudAiConfig(
            provider: _provider,
            model: model,
            baseUrl: _address.text.trim().isEmpty ? null : _address.text.trim(),
            monthlyTokenCap: cap != null && cap > 0 ? cap : null,
          ));
    if (mounted) _snack(context.l10n.aiSaved);
  }

  Future<void> _saveKey(String? key) async {
    await _setup!.setKey(_provider, key);
    _key.clear();
    final has = await _setup!.hasKey(_provider);
    if (mounted) {
      setState(() => _hasKey = has);
      _snack(context.l10n.aiSaved);
    }
  }

  Future<void> _loadModels() async {
    try {
      final list = await _setup!.cloudModels(_provider, baseUrl: _address.text.trim().isEmpty ? null : _address.text.trim());
      if (mounted) setState(() => _models = list);
    } on AiEngineFailure catch (e) {
      if (mounted) _snack(context.l10n.aiModelsFailed(e.kind.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final setup = _setup;
    final s = _s;
    final text = Theme.of(context).textTheme;
    Widget header(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(t, style: text.titleSmall));
    if (setup == null || s == null) {
      return Scaffold(appBar: AppBar(title: Text(l.aiAssistant)), body: const Center(child: CircularProgressIndicator()));
    }
    final catalog = setup.models.catalog();
    final own = [for (final m in _installed) if (!catalog.any((c) => c.id == m.id)) m];

    Widget modelTile(String id, String name, String facts, {LocalModelInfo? info}) {
      final installed = _installed.where((m) => m.id == id).firstOrNull;
      final inUse = _selected?.id == id;
      final progress = _progress[id];
      final slow = info != null && info.slowOn.contains(setup.platform);
      return ListTile(
        key: ValueKey('ai-model-$id'),
        leading: Icon(inUse ? Icons.radio_button_checked : Icons.memory),
        title: Text(name),
        subtitle: Text([
          facts,
          if (info != null && info.recommendedOn.contains(setup.platform)) l.aiRecommended,
          if (slow) l.aiSlowHere,
          if (progress != null) l.aiDownloading((progress * 100).floor()),
        ].join('\n')),
        isThreeLine: true,
        trailing: progress != null
            ? IconButton(
                key: ValueKey('ai-cancel-$id'), tooltip: l.cancel, icon: const Icon(Icons.close), onPressed: () => _cancels[id]?.cancel())
            : installed == null
                ? (info == null
                    ? null
                    : TextButton(key: ValueKey('ai-download-$id'), onPressed: () => _download(info), child: Text(l.aiDownload)))
                : Wrap(spacing: 4, children: [
                    if (inUse)
                      Chip(label: Text(l.aiInUse))
                    else
                      TextButton(
                          key: ValueKey('ai-use-$id'),
                          onPressed: () async {
                            await setup.models.select(id);
                            await _refreshModels();
                          },
                          child: Text(l.aiUse)),
                    IconButton(
                        key: ValueKey('ai-delete-model-$id'),
                        tooltip: l.aiDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await setup.models.delete(id);
                          await _refreshModels();
                        }),
                  ]),
      );
    }

    final hours = [for (var h = 0; h <= 24; h++) h];
    return Scaffold(
      appBar: AppBar(title: Text(l.aiAssistant)),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        header(l.aiPreferred),
        RadioGroup<AiEngineSite>(
          groupValue: s.preferred,
          onChanged: (v) => v == null ? null : _saveSettings(_copy(s, preferred: v)),
          child: Column(children: [
            RadioListTile(key: const Key('ai-prefer-device'), value: AiEngineSite.device, title: Text(l.aiEngineDevice)),
            RadioListTile(key: const Key('ai-prefer-cloud'), value: AiEngineSite.cloud, title: Text(l.aiEngineCloud)),
          ]),
        ),
        header(l.aiLocalModels),
        for (final m in catalog)
          modelTile(m.id, m.name, l.aiModelFacts(formatModelSize(m.sizeBytes), m.license, m.memoryGb.toStringAsFixed(1)), info: m),
        for (final m in own) modelTile(m.id, m.name, '${formatModelSize(m.sizeBytes)} · ${l.aiOwnFile}'),
        ListTile(
            key: const Key('ai-use-file'),
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l.aiUseModelFile),
            onTap: _useFile),
        header(l.aiCloud),
        SwitchListTile(
          key: const Key('ai-cloud-switch'),
          title: Text(l.aiCloudOn),
          subtitle: Text(l.aiCloudOnHint),
          value: s.cloudEnabled,
          onChanged: (v) => _saveSettings(_copy(s, cloudEnabled: v)),
        ),
        if (s.cloudEnabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<CloudProvider>(
              key: const Key('ai-provider'),
              initialValue: _provider,
              decoration: InputDecoration(labelText: l.aiProvider),
              items: [for (final p in CloudProvider.values) DropdownMenuItem(value: p, child: Text(p.label))],
              onChanged: (p) async {
                if (p == null) return;
                final has = await setup.hasKey(p);
                setState(() {
                  _provider = p;
                  _hasKey = has;
                  _models = const [];
                });
              },
            ),
          ),
          if (_provider == CloudProvider.openaiCompatible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(key: const Key('ai-address'), controller: _address, decoration: InputDecoration(labelText: l.aiAddress)),
            ),
          ListTile(
              key: const Key('ai-key-status'),
              leading: Icon(_hasKey ? Icons.key : Icons.key_off),
              title: Text(_hasKey ? l.aiKeySaved : l.aiNoKey)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('ai-key'),
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: l.aiKey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(spacing: 8, children: [
              FilledButton.tonal(key: const Key('ai-save-key'), onPressed: () => _saveKey(_key.text), child: Text(l.aiSaveKey)),
              if (_hasKey) TextButton(key: const Key('ai-forget-key'), onPressed: () => _saveKey(null), child: Text(l.aiForgetKey)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(key: const Key('ai-model'), controller: _model, decoration: InputDecoration(labelText: l.aiModel)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton(key: const Key('ai-load-models'), onPressed: _hasKey ? _loadModels : null, child: Text(l.aiLoadModels)),
              for (final m in _models.take(40))
                ChoiceChip(
                  key: ValueKey('ai-model-choice-$m'),
                  label: Text(m),
                  selected: _model.text == m,
                  onSelected: (_) => setState(() => _model.text = m),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('ai-cap'),
              controller: _cap,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.aiCap, helperText: l.aiUsed(_used)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(key: const Key('ai-save-cloud'), onPressed: _saveCloud, child: Text(l.save)),
            ),
          ),
        ],
        header(l.aiHours),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('ai-day-start'),
                initialValue: s.dayStart ~/ 60,
                decoration: InputDecoration(labelText: l.aiFrom),
                items: [for (final h in hours.where((h) => h < s.dayEnd ~/ 60)) DropdownMenuItem(value: h, child: Text(_hour(h)))],
                onChanged: (h) => h == null ? null : _saveSettings(_copy(s, dayStart: h * 60)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('ai-day-end'),
                initialValue: s.dayEnd ~/ 60,
                decoration: InputDecoration(labelText: l.aiTo),
                items: [for (final h in hours.where((h) => h > s.dayStart ~/ 60)) DropdownMenuItem(value: h, child: Text(_hour(h)))],
                onChanged: (h) => h == null ? null : _saveSettings(_copy(s, dayEnd: h * 60)),
              ),
            ),
          ]),
        ),
        header(l.aiLanguage),
        RadioGroup<String>(
          groupValue: s.language,
          onChanged: (v) => v == null ? null : _saveSettings(_copy(s, language: v)),
          child: Column(children: [
            RadioListTile(key: const Key('ai-lang-vi'), value: 'vi', title: Text(l.aiLangVi)),
            RadioListTile(key: const Key('ai-lang-en'), value: 'en', title: Text(l.aiLangEn)),
          ]),
        ),
      ]),
    );
  }

  static String _hour(int h) => '$h:00';

  static AiAssistantSettings _copy(AiAssistantSettings s,
          {AiEngineSite? preferred, bool? cloudEnabled, int? dayStart, int? dayEnd, String? language}) =>
      AiAssistantSettings(
        preferred: preferred ?? s.preferred,
        cloudEnabled: cloudEnabled ?? s.cloudEnabled,
        dayStart: dayStart ?? s.dayStart,
        dayEnd: dayEnd ?? s.dayEnd,
        language: language ?? s.language,
      );
}

/// "Use a model file" where the app has no file dialog: the path, typed.
class _PathDialog extends StatefulWidget {
  const _PathDialog();

  @override
  State<_PathDialog> createState() => _PathDialogState();
}

class _PathDialogState extends State<_PathDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.aiUseModelFile),
      content: TextField(key: const Key('ai-model-path'), controller: _c, decoration: InputDecoration(labelText: l.aiModelFilePath)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const Key('ai-model-path-use'), onPressed: () => Navigator.pop(context, _c.text.trim()), child: Text(l.aiUse)),
      ],
    );
  }
}
