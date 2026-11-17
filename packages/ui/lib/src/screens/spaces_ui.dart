// P04b T13 (ADR-0065; p04b-plan.md B1–B14): shared spaces in the app.
//   switcher   the spaces in the drawer (or under the profile in the rail):
//              Personal, each shared space, "New space…", "Join with a code…"
//   bar        above the content while a shared space is shown: its name,
//              your role, how many people; "View only" for a viewer
//   details    the space's page: name, your name there, members (approve,
//              roles, remove, hand over), invitations (code, QR, link),
//              rules (and the notice when they change), export, leave,
//              delete
//   move       "Move to a space…" / "Move to Personal…": what becomes
//              visible is shown first (PRIV-002)
// Every action goes through the SharingService and SpaceService ports.
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n.dart';
import '../providers.dart';
import '../task_actions.dart' show showMessage;
import 'tasks_screen.dart' show showTextDialog;

String spaceNameOf(BuildContext context, SpaceView s) =>
    s.shared ? ((s.name ?? '').trim().isEmpty ? context.l10n.spUnnamed : s.name!) : context.l10n.spPersonal;

String roleName(BuildContext context, SpaceRole r) => context.l10n.spRole(r.name);

String sharingProblemText(BuildContext context, SharingProblem p) => context.l10n.spProblem(p.name);

/// Re-reads everything after the shown space or the spaces changed.
void refreshSpaces(WidgetRef ref) {
  ref.invalidate(spacesProvider);
  ref.invalidate(activeProfileProvider);
}

/// Shows [s]; every view follows, and a shared space syncs at once (B12).
Future<void> showSpace(BuildContext context, WidgetRef ref, SpaceView s) async {
  final spaces = ref.read(spaceServiceProvider);
  if (spaces == null || s.isShown) return;
  final r = await spaces.show(s.id);
  if (r is CommandFailure) {
    if (context.mounted) showMessage(context, context.l10n.spProblem('notAllowed'));
    return;
  }
  refreshSpaces(ref);
  final sync = ref.read(spaceSyncProvider);
  if (s.shared && sync != null) {
    unawaited(sync.syncNow().then((_) => refreshSpaces(ref), onError: (Object _) {}));
  }
}

/// Reports a sharing result: a problem as a message; true when it worked.
bool reportSharing(BuildContext context, SharingResult r) {
  if (r.ok) return true;
  if (context.mounted) showMessage(context, sharingProblemText(context, r.problem!));
  return false;
}

// --- New space, join ---------------------------------------------------------

Future<void> createSpaceFlow(BuildContext context, WidgetRef ref) async {
  final sharing = ref.read(sharingServiceProvider);
  final l = context.l10n;
  if (sharing == null) return showMessage(context, l.spNoSpaces);
  final name = await showTextDialog(context, title: l.spNewSpace, initial: '', confirmLabel: l.spCreate);
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  final r = await sharing.createSpace(name.trim());
  if (!context.mounted) return;
  if (reportSharing(context, r)) {
    refreshSpaces(ref);
    showMessage(context, l.spCreated);
  }
}

Future<void> joinSpaceFlow(BuildContext context, WidgetRef ref) async {
  final sharing = ref.read(sharingServiceProvider);
  if (sharing == null) return showMessage(context, context.l10n.spNoSpaces);
  final joined = await showDialog<SharingResult>(context: context, builder: (_) => _JoinDialog(sharing: sharing));
  if (joined == null || !context.mounted) return;
  refreshSpaces(ref);
  showMessage(context, joined.preview?.kind == InviteKind.joinAtOnce ? context.l10n.spJoined : context.l10n.spAskedToJoin);
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog({required this.sharing});
  final SharingService sharing;
  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _code = TextEditingController();
  InvitationPreview? _preview;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _look() async {
    setState(() => _busy = true);
    final r = await widget.sharing.peek(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = r.preview;
      _problem = r.ok ? null : sharingProblemText(context, r.problem!);
    });
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    final r = await widget.sharing.join(_code.text);
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, r);
    } else {
      setState(() {
        _busy = false;
        _problem = sharingProblemText(context, r.problem!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _preview;
    return AlertDialog(
      title: Text(l.spJoinTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const Key('join-space-code'),
            controller: _code,
            autofocus: true,
            decoration: InputDecoration(labelText: l.spInviteCode, hintText: l.spJoinHint),
            onChanged: (_) => setState(() => _preview = null),
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_problem!, key: const Key('join-space-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (p != null) ...[
            const SizedBox(height: 16),
            Text(l.spInvitedAs(roleName(context, p.role)), key: const Key('join-space-role')),
            const SizedBox(height: 4),
            Text(p.kind == InviteKind.joinAtOnce ? l.spJoinAtOnceNote : l.spJoinApproveNote),
            const SizedBox(height: 12),
            Text(l.spRulesTitle, style: Theme.of(context).textTheme.titleSmall),
            Text(l.spLeaveRuleText(p.leave.name), key: const Key('join-space-leave-rule')),
            Text(l.spExportRuleText(p.export.name)),
            const SizedBox(height: 8),
            Text(l.spCannotEnforce, style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        if (p == null)
          FilledButton(key: const Key('join-space-look'), onPressed: _busy ? null : _look, child: Text(l.spLook))
        else
          FilledButton(key: const Key('join-space-join'), onPressed: _busy ? null : _join, child: Text(l.spJoin)),
      ],
    );
  }
}

// --- The switcher -------------------------------------------------------------

/// The spaces in the drawer: one entry each, then New and Join.
class DrawerSpaces extends ConsumerWidget {
  const DrawerSpaces({super.key, required this.onDone});

  /// Closes the drawer.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(spaceServiceProvider) == null) return const SizedBox.shrink();
    final l = context.l10n;
    final spaces = ref.watch(spacesProvider).valueOrNull ?? const <SpaceView>[];
    final canShare = ref.watch(sharingServiceProvider) != null;
    final scheme = Theme.of(context).colorScheme;
    return Column(key: const Key('drawer-spaces'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 16, 4),
        child: Semantics(header: true, child: Text(l.spSpaces, style: Theme.of(context).textTheme.titleSmall)),
      ),
      for (final s in spaces)
        ListTile(
          key: ValueKey('space-${s.shared ? s.id : 'personal'}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: Icon(s.shared ? Icons.group_outlined : Icons.person_outline, color: s.isShown ? scheme.primary : null),
          title: Text(spaceNameOf(context, s), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: s.shared ? Text(roleName(context, s.role ?? SpaceRole.viewer)) : null,
          selected: s.isShown,
          trailing: s.rulesChanged ? Icon(Icons.info_outline, color: scheme.tertiary, size: 18) : null,
          onTap: () async {
            await showSpace(context, ref, s);
            onDone();
          },
        ),
      if (canShare) ...[
        ListTile(
          key: const Key('space-new'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.add),
          title: Text(l.spNewSpace),
          onTap: () async {
            await createSpaceFlow(context, ref);
            onDone();
          },
        ),
        ListTile(
          key: const Key('space-join'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.login),
          title: Text(l.spJoinSpace),
          onTap: () async {
            await joinSpaceFlow(context, ref);
            onDone();
          },
        ),
      ],
      const Divider(indent: 28, endIndent: 28),
    ]);
  }
}

/// The spaces under the profile in the rail: a button with a menu.
class RailSpaces extends ConsumerWidget {
  const RailSpaces({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(spaceServiceProvider) == null) return const SizedBox.shrink();
    final l = context.l10n;
    final spaces = ref.watch(spacesProvider).valueOrNull ?? const <SpaceView>[];
    final shown = spaces.where((s) => s.isShown).firstOrNull;
    final canShare = ref.watch(sharingServiceProvider) != null;
    return PopupMenuButton<String>(
      key: const Key('rail-spaces'),
      tooltip: l.spChooseSpace(shown == null ? l.spPersonal : spaceNameOf(context, shown)),
      icon: Icon(shown?.shared == true ? Icons.group : Icons.group_outlined),
      onSelected: (v) {
        if (v == '#new') {
          createSpaceFlow(context, ref);
        } else if (v == '#join') {
          joinSpaceFlow(context, ref);
        } else {
          final s = spaces.where((x) => x.id == v).firstOrNull;
          if (s != null) showSpace(context, ref, s);
        }
      },
      itemBuilder: (_) => [
        for (final s in spaces)
          CheckedPopupMenuItem<String>(
            key: ValueKey('rail-space-${s.shared ? s.id : 'personal'}'),
            value: s.id,
            checked: s.isShown,
            child: Text(spaceNameOf(context, s)),
          ),
        if (canShare) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(key: const Key('rail-space-new'), value: '#new', child: Text(l.spNewSpace)),
          PopupMenuItem<String>(key: const Key('rail-space-join'), value: '#join', child: Text(l.spJoinSpace)),
        ],
      ],
    );
  }
}

/// Above the content while a shared space is shown.
class SpaceBar extends ConsumerWidget {
  const SpaceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(shownSharedSpaceProvider);
    if (s == null) return const SizedBox.shrink();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final details = switch (s.left) {
      SpaceLeft.readOnly => l.spLeftCopy,
      SpaceLeft.exportFirst => l.spLeftExport,
      SpaceLeft.no => [
          roleName(context, s.role ?? SpaceRole.viewer),
          l.spPeople(s.members),
          if (s.role == SpaceRole.viewer) l.spViewOnly,
        ].join(' · '),
    };
    final name = spaceNameOf(context, s);
    return Material(
      key: const Key('space-bar'),
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          button: true,
          label: l.spBarLabel(name, details),
          excludeSemantics: true,
          child: InkWell(
            onTap: () => openSpacePage(context, s.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(Icons.group, size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: '  $details'),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
                if (s.rulesChanged) Icon(Icons.info_outline, size: 18, color: scheme.onSecondaryContainer),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Move to a space (B3) ---------------------------------------------------

/// "Move to a space…" (from the personal workspace) or "Move to Personal…"
/// (from a shared space): what becomes visible is shown, then it moves.
Future<void> moveItemFlow(BuildContext context, WidgetRef ref, {required String kind, required String id}) async {
  final sharing = ref.read(sharingServiceProvider);
  final l = context.l10n;
  if (sharing == null) return showMessage(context, l.spNoSpaces);
  final List<SpaceView> spaces = ref.read(spacesProvider).valueOrNull ?? await ref.read(spacesProvider.future);
  final shown = spaces.where((s) => s.isShown).firstOrNull;
  if (shown == null || !context.mounted) return;
  SpaceView? target;
  if (shown.shared) {
    target = spaces.where((s) => !s.shared).firstOrNull;
  } else {
    final choices = [for (final s in spaces) if (s.shared && s.left == SpaceLeft.no && s.role != SpaceRole.viewer) s];
    if (choices.isEmpty) return createSpaceFlow(context, ref);
    target = choices.length == 1
        ? choices.single
        : await showDialog<SpaceView>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: Text(l.spPickSpace),
              children: [
                for (final s in choices)
                  SimpleDialogOption(
                    key: ValueKey('move-pick-${s.id}'),
                    onPressed: () => Navigator.pop(ctx, s),
                    child: Text(spaceNameOf(context, s)),
                  ),
              ],
            ),
          );
  }
  if (target == null || !context.mounted) return;
  final preview = await sharing.previewMove(kind, id, target.id);
  if (!context.mounted) return;
  if (preview.blocker != null) return showMessage(context, l.spCannotMove(preview.blocker!));
  final name = spaceNameOf(context, target);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('move-confirm'),
      title: Text(target!.shared ? l.spMoveTitle(name) : l.spMoveOut),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(target.shared ? l.spMoveBody(name) : l.spMoveOutBody),
          const SizedBox(height: 8),
          for (final t in preview.titles.take(8)) _bullet(t),
          if (preview.titles.length > 8) Text(l.spMoveMore(preview.titles.length - 8)),
          if (preview.hasNotes) _bullet(l.spMoveNotes, key: const Key('move-has-notes')),
          if (preview.hasDates) _bullet(l.spMoveDates),
          const SizedBox(height: 8),
          Text(l.spMoveStays, style: Theme.of(ctx).textTheme.bodySmall),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(key: const Key('move-confirm-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.spMove)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await sharing.move(preview);
  if (!context.mounted) return;
  if (reportSharing(context, r)) {
    refreshSpaces(ref);
    showMessage(context, l.spMoved);
  }
}

Widget _bullet(String text, {Key? key}) => Row(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(4, 6, 8, 0), child: Icon(Icons.circle, size: 6)),
      Expanded(child: Text(text)),
    ]);

/// "Assigned to me" (B9): the tasks assigned to [me], with their subtasks,
/// and the tasks above them so they show in place.
List<TaskView> assignedTo(List<TaskView> all, String me) {
  final byId = {for (final t in all) t.id: t};
  final keep = <String>{};
  for (final t in all.where((t) => t.assigneeId == me)) {
    for (String? up = t.id; up != null && keep.add(up); up = byId[up]?.parentId) {}
  }
  var grew = true;
  while (grew) {
    grew = false;
    for (final t in all) {
      if (!keep.contains(t.id) && t.parentId != null && keep.contains(t.parentId) &&
          all.any((x) => x.assigneeId == me && _under(byId, t.id, x.id))) {
        grew = keep.add(t.id) || grew;
      }
    }
  }
  return [for (final t in all) if (keep.contains(t.id)) t];
}

bool _under(Map<String, TaskView> byId, String id, String ancestor) {
  for (String? up = byId[id]?.parentId; up != null; up = byId[up]?.parentId) {
    if (up == ancestor) return true;
  }
  return false;
}

/// The menu entry for [moveItemFlow], or null where moving makes no sense
/// (no sharing, a viewer, a left copy).
String? moveLabel(BuildContext context, WidgetRef ref) {
  if (ref.read(sharingServiceProvider) == null) return null;
  final spaces = ref.read(spacesProvider).valueOrNull ?? const <SpaceView>[];
  final shown = spaces.where((s) => s.isShown).firstOrNull;
  if (shown == null) return null;
  if (shown.shared) {
    return shown.left == SpaceLeft.no && shown.role != SpaceRole.viewer ? context.l10n.spMoveOut : null;
  }
  return spaces.any((s) => s.shared && s.left == SpaceLeft.no && s.role != SpaceRole.viewer) ? context.l10n.spMoveTo : null;
}

// --- The space's page --------------------------------------------------------

Future<void> openSpacePage(BuildContext context, String spaceId) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => SpacePage(spaceId: spaceId),
    ));

class SpacePage extends ConsumerWidget {
  const SpacePage({super.key, required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final spaces = ref.watch(spacesProvider).valueOrNull;
    final s = spaces?.where((x) => x.id == spaceId).firstOrNull;
    final sharing = ref.watch(sharingServiceProvider);
    if (spaces == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (s == null || sharing == null) {
      return Scaffold(appBar: AppBar(title: Text(l.spDetails)), body: Center(child: Text(l.tpGone)));
    }
    final name = spaceNameOf(context, s);
    final owner = s.role == SpaceRole.owner && s.left == SpaceLeft.no;
    final theme = Theme.of(context);
    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Semantics(header: true, child: Text(text, style: theme.textTheme.titleSmall)),
        );

    Future<void> act(Future<SharingResult> Function() run) async {
      final r = await run();
      if (!context.mounted) return;
      if (reportSharing(context, r)) refreshSpaces(ref);
    }

    return Scaffold(
      key: const Key('space-page'),
      appBar: AppBar(title: Text(name)),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        if (s.rulesChanged)
          MaterialBanner(
            key: const Key('space-rules-changed'),
            content: Text(l.spRulesChanged(name)),
            actions: [
              TextButton(
                key: const Key('space-rules-seen'),
                onPressed: () async {
                  await sharing.rulesSeen(spaceId);
                  refreshSpaces(ref);
                },
                child: Text(l.spGotIt),
              ),
            ],
          ),
        if (s.left != SpaceLeft.no)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(s.left == SpaceLeft.readOnly ? l.spLeftCopy : l.spLeftExport),
          ),
        if (owner)
          ListTile(
            key: const Key('space-rename'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.spRename),
            subtitle: Text(name),
            onTap: () async {
              final to = await showTextDialog(context, title: l.spRename, initial: s.name ?? '', confirmLabel: l.save);
              if (to == null || !context.mounted) return;
              await act(() => sharing.renameSpace(spaceId, to));
            },
          ),
        if (s.left == SpaceLeft.no && s.role != SpaceRole.viewer)
          ListTile(
            key: const Key('space-my-name'),
            leading: const Icon(Icons.badge_outlined),
            title: Text(l.spYourName),
            subtitle: Text(l.spYourNameHint),
            onTap: () async {
              final me = await sharing.myAccountId();
              final names = await sharing.memberNames(spaceId);
              if (!context.mounted) return;
              final to = await showTextDialog(context, title: l.spYourName, initial: names[me] ?? '', confirmLabel: l.save);
              if (to == null || !context.mounted) return;
              await act(() => sharing.setMyName(spaceId, to));
              ref.invalidate(memberNamesProvider(spaceId));
              ref.invalidate(spaceMembersProvider(spaceId));
            },
          ),
        if (s.left == SpaceLeft.no) ...[
          section(l.spMembers),
          _Members(space: s),
        ],
        if (owner) ...[
          section(l.spInvite),
          _Invitations(space: s),
        ],
        section(l.spRules),
        _Rules(space: s),
        section(l.spSpaceDetails),
        if (s.left == SpaceLeft.no && ref.watch(spaceSyncProvider) != null)
          ListTile(
            key: const Key('space-sync-now'),
            leading: const Icon(Icons.sync),
            title: Text(l.spSyncNow),
            onTap: () async {
              await ref.read(spaceSyncProvider)!.syncNow();
              refreshSpaces(ref);
              ref.invalidate(spaceMembersProvider(spaceId));
            },
          ),
        ListTile(
          key: const Key('space-export'),
          leading: const Icon(Icons.download_outlined),
          title: Text(l.spExport),
          onTap: () async {
            final (file, problem) = await sharing.exportSpace(spaceId);
            if (!context.mounted) return;
            if (problem != null) return showMessage(context, sharingProblemText(context, problem));
            final saved = await ref.read(fileGatewayProvider).saveText(file!.suggestedName, file.contents);
            if (saved && context.mounted) showMessage(context, l.spExported);
          },
        ),
        if (s.left != SpaceLeft.no)
          ListTile(
            key: const Key('space-forget'),
            leading: const Icon(Icons.delete_outline),
            title: Text(l.spForget),
            onTap: () async {
              final navigator = Navigator.of(context);
              await act(() => sharing.forgetSpace(spaceId));
              navigator.pop();
            },
          )
        else ...[
          ListTile(
            key: const Key('space-leave'),
            leading: const Icon(Icons.logout),
            title: Text(l.spLeave),
            subtitle: Text(l.spLeaveRuleText(_leaveRuleOf(ref, s))),
            onTap: () async {
              if (!await _confirm(context, l.spLeaveConfirm(name), l.spLeave) || !context.mounted) return;
              final navigator = Navigator.of(context);
              final r = await sharing.leave(spaceId);
              if (!context.mounted) return;
              if (reportSharing(context, r)) {
                refreshSpaces(ref);
                navigator.pop();
              }
            },
          ),
          if (owner)
            ListTile(
              key: const Key('space-delete'),
              leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
              title: Text(l.spDelete, style: TextStyle(color: theme.colorScheme.error)),
              onTap: () async {
                if (!await _confirm(context, l.spDeleteConfirm(name), l.spDelete) || !context.mounted) return;
                final navigator = Navigator.of(context);
                final r = await sharing.deleteSpace(spaceId);
                if (!context.mounted) return;
                if (reportSharing(context, r)) {
                  refreshSpaces(ref);
                  navigator.pop();
                }
              },
            ),
        ],
      ]),
    );
  }
}

String _leaveRuleOf(WidgetRef ref, SpaceView s) =>
    ref.watch(_rulesProvider(s.id)).valueOrNull?.leave.name ?? LeaveRule.disappear.name;

/// The rules as last cached here (from the notices or the defaults).
final _rulesProvider = FutureProvider.autoDispose.family<SpaceRules, String>((ref, spaceId) async {
  final sharing = ref.watch(sharingServiceProvider);
  ref.watch(spacesProvider);
  if (sharing == null) return const SpaceRules();
  return await sharing.rulesOf(spaceId);
});

Future<bool> _confirm(BuildContext context, String question, String yes) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          FilledButton(key: const Key('space-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
        ],
      ),
    ) ==
    true;

class _Members extends ConsumerWidget {
  const _Members({required this.space});
  final SpaceView space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final members = ref.watch(spaceMembersProvider(space.id)).valueOrNull;
    final sharing = ref.watch(sharingServiceProvider)!;
    if (members == null) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
    final owner = space.role == SpaceRole.owner;
    Future<void> act(Future<SharingResult> Function() run) async {
      final r = await run();
      if (!context.mounted) return;
      if (reportSharing(context, r)) {
        refreshSpaces(ref);
        ref.invalidate(spaceMembersProvider(space.id));
      }
    }

    return Column(children: [
      for (final m in members)
        () {
          final name = m.name ?? l.spSomeone;
          final shown = m.isMe ? l.spYou(name) : name;
          final waiting = m.status == MemberStatus.pending;
          return ListTile(
            key: ValueKey('member-${m.accountId}'),
            leading: CircleAvatar(child: Text(name.characters.first.toUpperCase())),
            title: Text(shown),
            subtitle: Text(waiting ? '${l.spWaiting} · ${roleName(context, m.role)}' : roleName(context, m.role)),
            trailing: !owner || m.isMe
                ? null
                : waiting
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(
                          key: ValueKey('member-decline-${m.accountId}'),
                          onPressed: () => act(() => sharing.removeMember(space.id, m.accountId)),
                          child: Text(l.spTurnDown),
                        ),
                        FilledButton(
                          key: ValueKey('member-approve-${m.accountId}'),
                          onPressed: () => act(() => sharing.approve(space.id, m.accountId)),
                          child: Text(l.spApprove),
                        ),
                      ])
                    : PopupMenuButton<String>(
                        key: ValueKey('member-menu-${m.accountId}'),
                        tooltip: l.spMemberActions(name),
                        onSelected: (a) async {
                          switch (a) {
                            case 'editor':
                            case 'viewer':
                              await act(() => sharing.setRole(space.id, m.accountId, SpaceRole.values.byName(a)));
                            case 'owner':
                              if (await _confirm(context, l.spHandOverConfirm(name), l.spHandOver)) {
                                await act(() => sharing.handOver(space.id, m.accountId));
                              }
                            case 'remove':
                              if (await _confirm(context, l.spRemoveConfirm(name), l.spRemove)) {
                                await act(() => sharing.removeMember(space.id, m.accountId));
                              }
                          }
                        },
                        itemBuilder: (_) => [
                          if (m.role != SpaceRole.editor)
                            PopupMenuItem(value: 'editor', child: Text(l.spMakeRole(roleName(context, SpaceRole.editor)))),
                          if (m.role != SpaceRole.viewer)
                            PopupMenuItem(value: 'viewer', child: Text(l.spMakeRole(roleName(context, SpaceRole.viewer)))),
                          PopupMenuItem(value: 'owner', child: Text(l.spHandOver)),
                          PopupMenuItem(value: 'remove', child: Text(l.spRemove)),
                        ],
                      ),
          );
        }(),
    ]);
  }
}

class _Invitations extends ConsumerStatefulWidget {
  const _Invitations({required this.space});
  final SpaceView space;
  @override
  ConsumerState<_Invitations> createState() => _InvitationsState();
}

class _InvitationsState extends ConsumerState<_Invitations> {
  SpaceRole _role = SpaceRole.editor;
  InviteKind? _kind;
  InvitationToGive? _made;
  List<RemoteInvitation>? _open;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await ref.read(sharingServiceProvider)!.invitations(widget.space.id);
    if (mounted) setState(() => _open = list);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sharing = ref.watch(sharingServiceProvider)!;
    final rules = ref.watch(_rulesProvider(widget.space.id)).valueOrNull ?? const SpaceRules();
    final kind = _kind ?? rules.inviteDefault;
    final made = _made;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.spInviteRole),
        SegmentedButton<SpaceRole>(
          key: const Key('invite-role'),
          segments: [
            for (final r in [SpaceRole.editor, SpaceRole.viewer])
              ButtonSegment(value: r, label: Text(roleName(context, r))),
          ],
          selected: {_role},
          onSelectionChanged: (v) => setState(() => _role = v.single),
        ),
        const SizedBox(height: 12),
        Text(l.spInviteKind),
        SegmentedButton<InviteKind>(
          key: const Key('invite-kind'),
          segments: [
            ButtonSegment(value: InviteKind.approve, label: Text(l.spInviteApprove)),
            ButtonSegment(value: InviteKind.joinAtOnce, label: Text(l.spInviteAtOnce)),
          ],
          selected: {kind},
          onSelectionChanged: (v) => setState(() => _kind = v.single),
        ),
        if (kind == InviteKind.joinAtOnce)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.spInviteAtOnceWarning, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('invite-make'),
          icon: const Icon(Icons.person_add_alt),
          label: Text(l.spInviteMake),
          onPressed: () async {
            final r = await sharing.invite(widget.space.id, _role, kind);
            if (!context.mounted || !reportSharing(context, r)) return;
            setState(() => _made = r.invitation);
            await _reload();
          },
        ),
        if (made != null) ...[
          const SizedBox(height: 16),
          Text(l.spInviteReady, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Center(
            child: QrImageView(
              key: const Key('invite-qr'),
              data: made.link,
              size: 180,
              backgroundColor: Colors.white,
              semanticsLabel: l.spInviteQr,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.spInviteCode),
            subtitle: SelectableText(made.grouped, key: const Key('invite-code')),
            trailing: IconButton(
              key: const Key('invite-copy-code'),
              tooltip: l.spCopy,
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(context, made.grouped),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.spInviteLink),
            subtitle: SelectableText(made.link, key: const Key('invite-link')),
            trailing: IconButton(
              key: const Key('invite-copy-link'),
              tooltip: l.spCopy,
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(context, made.link),
            ),
          ),
          Text(l.spInviteOnce, style: Theme.of(context).textTheme.bodySmall),
        ],
        if ((_open ?? const []).isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l.spOpenInvitations, style: Theme.of(context).textTheme.titleSmall),
          for (final i in _open!)
            ListTile(
              key: ValueKey('invitation-${i.codeHash}'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.spInvitationLine(roleName(context, i.role),
                  i.kind == InviteKind.joinAtOnce ? l.spInviteAtOnce : l.spInviteApprove, _date(i.expiresAt))),
              trailing: IconButton(
                tooltip: l.spCancelInvitation,
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final r = await sharing.cancelInvitation(widget.space.id, i.codeHash);
                  if (!context.mounted || !reportSharing(context, r)) return;
                  await _reload();
                },
              ),
            ),
        ],
      ]),
    );
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showMessage(context, context.l10n.spCopied);
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

class _Rules extends ConsumerWidget {
  const _Rules({required this.space});
  final SpaceView space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rules = ref.watch(_rulesProvider(space.id)).valueOrNull ?? const SpaceRules();
    final sharing = ref.watch(sharingServiceProvider)!;
    final owner = space.role == SpaceRole.owner && space.left == SpaceLeft.no;
    Future<void> set(SpaceRules to) async {
      final r = await sharing.setRules(space.id, to);
      if (!context.mounted) return;
      if (reportSharing(context, r)) {
        refreshSpaces(ref);
        ref.invalidate(_rulesProvider(space.id));
      }
    }

    Widget pick<T extends Enum>(Key key, String title, T value, List<T> all, String Function(T) label, void Function(T) onPick) =>
        ListTile(
          key: key,
          title: Text(title),
          subtitle: Text(label(value)),
          trailing: owner
              ? PopupMenuButton<T>(
                  tooltip: title,
                  onSelected: onPick,
                  itemBuilder: (_) => [for (final v in all) CheckedPopupMenuItem(value: v, checked: v == value, child: Text(label(v)))],
                )
              : null,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      pick(const Key('rule-leave'), l.spRuleLeave, rules.leave, LeaveRule.values, (v) => l.spRuleLeaveOption(v.name),
          (v) => set(SpaceRules(leave: v, export: rules.export, inviteDefault: rules.inviteDefault))),
      pick(const Key('rule-export'), l.spRuleExport, rules.export, ExportRule.values, (v) => l.spRuleExportOption(v.name),
          (v) => set(SpaceRules(leave: rules.leave, export: v, inviteDefault: rules.inviteDefault))),
      pick(const Key('rule-invite'), l.spRuleInvite, rules.inviteDefault, InviteKind.values,
          (v) => v == InviteKind.joinAtOnce ? l.spInviteAtOnce : l.spInviteApprove,
          (v) => set(SpaceRules(leave: rules.leave, export: rules.export, inviteDefault: v))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(l.spCannotEnforce, style: Theme.of(context).textTheme.bodySmall),
      ),
    ]);
  }
}
