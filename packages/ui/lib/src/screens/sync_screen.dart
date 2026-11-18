// P04 T5 (ADR-0058; p04-plan.md D4, D5, D8–D11, D15): Settings → Sync.
//   the switch        turning sync on goes through the setup page: a new
//                     account gets a recovery key (shown, saved, confirmed
//                     by two words) or a passphrase; an account that already
//                     syncs is joined with its key, merging this device's
//                     data (the default) or using only the account's (saved
//                     to a file first). Off keeps the data.
//   status            live: syncing, up to date with the time, offline, an
//                     update needed, a new key, the server copy deleted
//   when to sync      Automatic or only "Sync now" (a device setting)
//   to review         keep this one, or take the other
//   undo joining, and deleting the server copy
// The UI only talks to SyncService (FF-ARCH-04); keys never reach it except
// the words the user types or is shown once.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n.dart';
import '../providers.dart';

/// The sync line under the profile (D9), or null when sync is off or not in
/// this build.
String? syncLineOf(BuildContext context, SyncStatus? s) {
  if (s == null || !s.on) return null;
  final l = context.l10n;
  final String main;
  if (s.syncing) {
    main = l.sySyncing;
  } else {
    main = switch (s.lastResult) {
      null || SyncOutcome.notOn => s.pending > 0 ? l.syWaiting(s.pending) : l.syNotSyncedYet,
      SyncOutcome.upToDate => s.pending > 0
          ? l.syWaiting(s.pending)
          : (s.lastSyncAt == null ? l.syUpToDate : l.syUpToDateAt(_when(context, s.lastSyncAt!))),
      SyncOutcome.offline => l.syOffline,
      SyncOutcome.signedOut => l.sySignedOut,
      SyncOutcome.notYours => l.syNotYours,
      SyncOutcome.updateNeeded => l.syUpdateNeeded,
      SyncOutcome.keyChanged => l.syKeyChanged,
      SyncOutcome.workspaceGone => l.syWorkspaceGone,
      SyncOutcome.failed => l.syFailed,
    };
  }
  return s.reviews > 0 ? l.syStatusAndReviews(main, l.syReviewsWaiting(s.reviews)) : main;
}

/// A time today, or a date and time.
String _when(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final m = MaterialLocalizations.of(context);
  final now = DateTime.now();
  final time = m.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  final today = local.year == now.year && local.month == now.month && local.day == now.day;
  return today ? time : '${m.formatShortDate(local)} $time';
}

String syncProblemText(BuildContext context, SyncSetupProblem? p, [String detail = '']) {
  final text = context.l10n.syProblem(p?.name ?? 'failed');
  // Which recovery-key word is wrong (safe to show, ADR-0054).
  return p == SyncSetupProblem.recoveryKeyInvalid && detail.isNotEmpty ? '$text $detail' : text;
}

void _snack(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          FilledButton(key: const Key('confirm-action'), onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// The Sync row of Settings: its status; a tap opens Settings → Sync.
class SyncSettingsTile extends ConsumerWidget {
  const SyncSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final available = ref.watch(syncServiceProvider) != null;
    return ListTile(
      key: const Key('sync-settings'),
      leading: const Icon(Icons.sync),
      title: Text(l.sySync),
      subtitle: Text(!available ? l.syNotAvailable : (syncLineOf(context, status) ?? l.sySyncOff)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/settings/sync'),
    );
  }
}

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sync = ref.watch(syncServiceProvider);
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final children = <Widget>[];

    if (sync == null) {
      children.add(ListTile(leading: const Icon(Icons.cloud_off), title: Text(l.syNotAvailable)));
    } else if (profile != null && (!profile.isBound || profile.isLocked) && !(status?.on ?? false)) {
      children.add(ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(profile.isLocked ? l.syLockedProfile : l.sySignInFirst),
      ));
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
              key: const Key('sync-open-profiles'), onPressed: () => context.go('/profiles'), child: Text(l.syOpenProfiles)),
        ),
      ));
    } else if (status != null) {
      children.addAll(_syncOn(context, ref, sync, status));
    } else {
      children.add(const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.sySync)),
      body: ListView(children: [...children, const SizedBox(height: 24)]),
    );
  }

  List<Widget> _syncOn(BuildContext context, WidgetRef ref, SyncService sync, SyncStatus s) {
    final l = context.l10n;
    Future<void> turnOn() async {
      final message = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const SyncSetupPage()));
      if (message != null && context.mounted) _snack(context, message);
    }

    Future<void> turnOff() async {
      if (!await _confirm(context, l.syTurnOffTitle, l.syTurnOffBody, l.syTurnOff)) return;
      final r = await sync.turnOff();
      if (context.mounted) _snack(context, r.ok ? l.syTurnedOff : syncProblemText(context, r.problem, r.message));
    }

    final out = <Widget>[
      SwitchListTile(
        key: const Key('sync-switch'),
        secondary: const Icon(Icons.sync),
        title: Text(l.sySyncThisProfile),
        subtitle: Text(l.sySyncThisProfileHint),
        value: s.on,
        onChanged: (v) => v ? turnOn() : turnOff(),
      ),
    ];
    if (!s.on) return out;

    out.add(ListTile(
      key: const Key('sync-status'),
      title: Text(syncLineOf(context, s) ?? ''),
      trailing: FilledButton(
        key: const Key('sync-now'),
        onPressed: s.syncing
            ? null
            : () async {
                final r = await sync.syncNow();
                if (!context.mounted) return;
                final line = syncLineOf(context, SyncStatus(on: true, lastResult: r.outcome, lastSyncAt: DateTime.now()));
                if (line != null) _snack(context, line);
              },
        child: Text(l.sySyncNow),
      ),
    ));

    final notice = switch (s.lastResult) {
      SyncOutcome.updateNeeded => (Icons.system_update, l.syUpdateTitle, l.syUpdateBody),
      SyncOutcome.keyChanged => (Icons.key_off, l.syKeyChangedTitle, l.syKeyChangedBody),
      SyncOutcome.workspaceGone => (Icons.cloud_off, l.syWorkspaceGoneTitle, l.syWorkspaceGoneBody),
      _ => null,
    };
    if (notice != null) {
      final scheme = Theme.of(context).colorScheme;
      out.add(Card(
        key: const Key('sync-notice'),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        color: scheme.tertiaryContainer,
        child: ListTile(
          leading: Icon(notice.$1, color: scheme.onTertiaryContainer),
          title: Text(notice.$2, style: TextStyle(color: scheme.onTertiaryContainer)),
          subtitle: Text(notice.$3, style: TextStyle(color: scheme.onTertiaryContainer)),
        ),
      ));
    }

    out
      ..add(const Divider(height: 32))
      ..add(_header(context, l.syWhenToSync))
      ..add(const _WhenToSync())
      ..add(const Divider(height: 32))
      ..add(_header(context, l.syReviewsTitle))
      ..add(const _Reviews())
      ..add(const Divider(height: 32));

    if (s.canUndoJoin) {
      out.add(ListTile(
        key: const Key('sync-undo-join'),
        leading: const Icon(Icons.undo),
        title: Text(l.syUndoJoin),
        subtitle: Text(l.syUndoJoinHint),
        onTap: () async {
          if (!await _confirm(context, l.syUndoJoinTitle, l.syUndoJoinBody, l.syUndo)) return;
          final r = await sync.undoJoin();
          // Back in the earlier workspace: the views subscribe again.
          ref.invalidate(activeProfileProvider);
          if (context.mounted) _snack(context, r.ok ? l.syUndone : syncProblemText(context, r.problem, r.message));
        },
      ));
    }
    out.add(ListTile(
      key: const Key('sync-delete-server'),
      leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
      title: Text(l.syDeleteServer),
      subtitle: Text(l.syDeleteServerHint),
      onTap: () async {
        if (!await _confirm(context, l.syDeleteServerTitle, l.syDeleteServerBody, l.syDelete)) return;
        final r = await sync.deleteServerData();
        if (context.mounted) _snack(context, r.ok ? l.syDeleted : syncProblemText(context, r.problem, r.message));
      },
    ));
    return out;
  }
}

Widget _header(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );

class _WhenToSync extends ConsumerWidget {
  const _WhenToSync();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final when = ref.watch(syncWhenProvider);
    return when.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      error: (_, __) => ListTile(title: Text(l.thisSettingCouldNotBeLoaded)),
      data: (current) => RadioGroup<SyncWhen>(
        groupValue: current,
        onChanged: (w) async {
          if (w == null) return;
          await ref.read(settingsServiceProvider).setSyncWhen(w);
          ref.invalidate(syncWhenProvider);
        },
        child: Column(children: [
          RadioListTile<SyncWhen>(
              key: const Key('sync-when-automatic'),
              value: SyncWhen.automatic,
              title: Text(l.syAutomatic),
              subtitle: Text(l.syAutomaticHint)),
          RadioListTile<SyncWhen>(
              key: const Key('sync-when-manual'),
              value: SyncWhen.onlySyncNow,
              title: Text(l.syOnlySyncNow),
              subtitle: Text(l.syOnlySyncNowHint)),
        ]),
      ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(syncReviewsProvider).valueOrNull ?? const <SyncReviewView>[];
    if (items.isEmpty) return ListTile(key: const Key('sync-no-reviews'), title: Text(l.syNoReviews));
    return Column(children: [
      for (final r in items)
        ReviewCard(
          item: r,
          close: (takeOther) async {
            final sync = ref.read(syncServiceProvider);
            if (sync == null) return null;
            final res = await sync.resolveReview(r.id, takeOther: takeOther);
            ref.invalidate(syncReviewsProvider);
            return res;
          },
        ),
    ]);
  }
}

/// One "Changes to review" item: the personal sync's, or a shared space's
/// (P04b T14 finding 2).
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.item, required this.close});
  final SyncReviewView item;

  /// Closes it: keeps what was kept, or takes the other value back.
  final Future<SyncSetupResult?> Function(bool takeOther) close;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final r = item;
    final kind = l.syRecordKind(r.recordKind);
    final title = r.title == null ? kind : l.syRecordOf(kind, r.title!);
    Future<void> resolve(bool takeOther) async {
      final res = await close(takeOther);
      if (res != null && !res.ok && context.mounted) _snack(context, syncProblemText(context, res.problem, res.message));
    }

    Widget value(String label, String v) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: text.labelMedium),
            Text(v.isEmpty ? l.syEmptyValue : v, maxLines: 6, overflow: TextOverflow.ellipsis),
          ]),
        );

    return Card(
      key: Key('review-${r.id}'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: text.titleSmall),
          Text(switch (r.reason) {
            SyncReviewKind.changedOnBoth => l.syReviewChanged,
            SyncReviewKind.deletedAndEdited => l.syReviewDeleted,
            SyncReviewKind.unreadable => l.syReviewUnreadable,
          }),
          if (r.reason == SyncReviewKind.changedOnBoth) ...[
            value(l.syKeptValue, r.kept),
            value(l.syOtherValue, r.other),
          ],
          OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: [
            if (r.reason == SyncReviewKind.changedOnBoth && r.canTakeOther)
              TextButton(key: Key('review-other-${r.id}'), onPressed: () => resolve(true), child: Text(l.syTakeOther)),
            FilledButton.tonal(
              key: Key('review-keep-${r.id}'),
              onPressed: () => resolve(false),
              child: Text(r.reason == SyncReviewKind.changedOnBoth ? l.syKeepThis : l.syDismiss),
            ),
          ]),
        ]),
      ),
    );
  }
}

enum _Step { checking, problem, choose, showKey, confirmKey, passphrase, join }

/// Turning sync on (D5, D15). Pops with the message to show, or null.
class SyncSetupPage extends ConsumerStatefulWidget {
  const SyncSetupPage({super.key});

  @override
  ConsumerState<SyncSetupPage> createState() => _SyncSetupPageState();
}

class _SyncSetupPageState extends ConsumerState<SyncSetupPage> {
  var _step = _Step.checking;
  var _busy = false;
  String? _error;
  SyncUnlock _unlock = SyncUnlock.recoveryKey;
  RecoveryKeyOffer? _offer;
  var _choice = JoinChoice.mergeThisDevice;
  final _word1 = TextEditingController();
  final _word2 = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  final _key = TextEditingController();

  SyncService get _sync => ref.read(syncServiceProvider)!;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    for (final c in [_word1, _word2, _pass1, _pass2, _key]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _step = _Step.checking;
      _error = null;
    });
    try {
      final start = await _sync.prepare();
      if (!mounted) return;
      switch (start) {
        case SyncStartFresh():
          setState(() => _step = _Step.choose);
        case SyncStartJoin(:final unlock):
          setState(() {
            _unlock = unlock;
            _step = _Step.join;
          });
        case SyncStartAlreadyOn():
          Navigator.pop(context);
      }
    } on SyncSetupException catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.problem;
        _error = syncProblemText(context, e.problem);
      });
    }
  }

  /// Runs [action] with the buttons off; a problem stays on the page.
  Future<void> _run(Future<SyncSetupResult> Function() action, String Function(SyncSetupResult) done) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await action();
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _error = syncProblemText(context, r.problem, r.message);
      });
      return;
    }
    // A join moves the profile to the account's workspace: every view of the
    // profile subscribes again.
    ref.invalidate(activeProfileProvider);
    var message = done(r);
    final export = r.export;
    if (export != null) {
      final saved = await ref.read(fileGatewayProvider).saveText(export.suggestedName, export.contents);
      if (!mounted) return;
      message = '$message ${saved ? context.l10n.syExportSaved : context.l10n.syExportNotSaved}';
    }
    Navigator.pop(context, message);
  }

  Future<void> _showKey() async {
    setState(() => _busy = true);
    final offer = await _sync.offerRecoveryKey();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _offer = offer;
      _step = _Step.showKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = switch (_step) {
      _Step.checking => [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(l.syChecking),
        ],
      _Step.problem => [
          Text(_error ?? '', key: const Key('setup-error')),
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(key: const Key('setup-retry'), onPressed: _prepare, child: Text(l.syTryAgain))),
        ],
      _Step.choose => _choose(context),
      _Step.showKey => _keyShown(context),
      _Step.confirmKey => _confirmKey(context),
      _Step.passphrase => _passphrase(context),
      _Step.join => _join(context),
    };
    return Scaffold(
      appBar: AppBar(title: Text(_step == _Step.join ? l.syJoinTitle : l.syTurnOnTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ...body,
        if (_error != null && _step != _Step.problem) ...[
          const SizedBox(height: 12),
          Text(_error!, key: const Key('setup-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
      ]),
    );
  }

  List<Widget> _choose(BuildContext context) {
    final l = context.l10n;
    return [
      Text(l.syProtectTitle, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(l.syProtectBody),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          key: const Key('setup-recovery-key'),
          leading: const Icon(Icons.vpn_key_outlined),
          title: Text(l.syUseRecoveryKey),
          subtitle: Text(l.syUseRecoveryKeyHint),
          onTap: _busy ? null : _showKey,
        ),
      ),
      Card(
        child: ListTile(
          key: const Key('setup-passphrase'),
          leading: const Icon(Icons.password),
          title: Text(l.syUsePassphrase),
          subtitle: Text(l.syUsePassphraseHint),
          onTap: _busy ? null : () => setState(() => _step = _Step.passphrase),
        ),
      ),
    ];
  }

  List<Widget> _keyShown(BuildContext context) {
    final l = context.l10n;
    final offer = _offer!;
    final mono = Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace');
    return [
      Text(l.syYourRecoveryKey, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(l.syRecoveryKeyBody),
      const SizedBox(height: 16),
      Wrap(key: const Key('setup-key-words'), spacing: 8, runSpacing: 8, children: [
        for (final (i, w) in offer.words.indexed)
          SizedBox(
            width: 140,
            child: Text(_numbered(i + 1, w), key: Key('key-word-${i + 1}'), style: mono),
          ),
      ]),
      const SizedBox(height: 16),
      Center(
        child: QrImageView(
          data: offer.qrText,
          size: 200,
          backgroundColor: Colors.white,
          semanticsLabel: l.syRecoveryKeyQr,
        ),
      ),
      const SizedBox(height: 16),
      OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: [
        OutlinedButton.icon(
          key: const Key('setup-save-key'),
          icon: const Icon(Icons.save_alt),
          label: Text(l.sySaveToFile),
          onPressed: () async {
            final text = '${l.syRecoveryKeyFileHeader}\n\n${offer.words.join(' ')}\n';
            final saved = await ref.read(fileGatewayProvider).saveText('lifeflow-recovery-key.txt', text);
            if (saved && context.mounted) _snack(context, l.sySaved);
          },
        ),
        FilledButton(
          key: const Key('setup-next'),
          onPressed: () => setState(() {
            _error = null;
            _step = _Step.confirmKey;
          }),
          child: Text(l.syNext),
        ),
      ]),
    ];
  }

  static String _numbered(int n, String word) => '$n. $word';

  List<Widget> _confirmKey(BuildContext context) {
    final l = context.l10n;
    final (p1, p2) = _offer!.check;
    return [
      Text(l.syConfirmKeyTitle, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(l.syConfirmKeyBody(p1, p2)),
      const SizedBox(height: 16),
      TextField(
          key: const Key('setup-word-1'),
          controller: _word1,
          autocorrect: false,
          decoration: InputDecoration(labelText: l.syWordN(p1))),
      const SizedBox(height: 8),
      TextField(
          key: const Key('setup-word-2'),
          controller: _word2,
          autocorrect: false,
          decoration: InputDecoration(labelText: l.syWordN(p2))),
      const SizedBox(height: 16),
      OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: [
        TextButton(onPressed: () => setState(() => _step = _Step.showKey), child: Text(l.syBack)),
        FilledButton(
          key: const Key('setup-turn-on'),
          onPressed: _busy
              ? null
              : () => _run(() => _sync.startWithRecoveryKey((_word1.text, _word2.text)), (_) => l.syTurnedOn),
          child: Text(l.syTurnOn),
        ),
      ]),
    ];
  }

  List<Widget> _passphrase(BuildContext context) {
    final l = context.l10n;
    return [
      Text(l.syChoosePassphrase, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(l.syPassphraseHint),
      const SizedBox(height: 16),
      TextField(
          key: const Key('setup-pass-1'),
          controller: _pass1,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l.syPassphrase)),
      const SizedBox(height: 8),
      TextField(
          key: const Key('setup-pass-2'),
          controller: _pass2,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l.syRepeatPassphrase)),
      const SizedBox(height: 16),
      OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: [
        TextButton(onPressed: () => setState(() => _step = _Step.choose), child: Text(l.syBack)),
        FilledButton(
          key: const Key('setup-turn-on'),
          onPressed: _busy
              ? null
              : () {
                  if (_pass1.text != _pass2.text) {
                    setState(() => _error = l.syPassphrasesDiffer);
                    return;
                  }
                  _run(() => _sync.startWithPassphrase(_pass1.text), (_) => l.syTurnedOn);
                },
          child: Text(l.syTurnOn),
        ),
      ]),
    ];
  }

  List<Widget> _join(BuildContext context) {
    final l = context.l10n;
    final byKey = _unlock == SyncUnlock.recoveryKey;
    return [
      Text(l.syJoinBody),
      const SizedBox(height: 16),
      if (byKey)
        TextField(
          key: const Key('join-key'),
          controller: _key,
          minLines: 3,
          maxLines: 5,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l.syRecoveryKey, hintText: l.syRecoveryKeyHint),
        )
      else
        TextField(
          key: const Key('join-passphrase'),
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l.syPassphrase),
        ),
      const SizedBox(height: 16),
      Text(l.syJoinWhat, style: Theme.of(context).textTheme.titleSmall),
      RadioGroup<JoinChoice>(
        groupValue: _choice,
        onChanged: (c) => setState(() => _choice = c ?? _choice),
        child: Column(children: [
          RadioListTile<JoinChoice>(
              key: const Key('join-merge'),
              value: JoinChoice.mergeThisDevice,
              title: Text(l.syJoinMerge),
              subtitle: Text(l.syJoinMergeHint)),
          RadioListTile<JoinChoice>(
              key: const Key('join-replace'),
              value: JoinChoice.useAccountOnly,
              title: Text(l.syJoinReplace),
              subtitle: Text(l.syJoinReplaceHint)),
        ]),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          key: const Key('join-submit'),
          onPressed: _busy
              ? null
              : () => _run(
                  () => byKey
                      ? _sync.join(_choice, recoveryKey: _key.text)
                      : _sync.join(_choice, passphrase: _key.text),
                  (_) => l.syJoined),
          child: Text(l.syJoin),
        ),
      ),
    ];
  }
}
