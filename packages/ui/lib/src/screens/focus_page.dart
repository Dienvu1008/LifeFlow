// P03 T6b (ADR-0042): focus sessions in the UI (owner decisions D1–D5).
//   startFocus   pomodoro (default 25 min) or stopwatch, with or without a
//                task; one session at a time (D2)
//   FocusPage    the running time, pause / resume, end (save or not), cancel
//   FocusBar     above the navigation on every screen while a session runs (D4)
//   FocusLaunchPrompt  asks once what to do with the session found at start (D1)
// The time shown is derived from the session's stored instants by the
// domain rules (FocusSessionView); the ticker only redraws (EXEC-002, AP-12).
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../messages.dart';
import '../providers.dart';
import '../task_actions.dart';

/// 5:07, 25:00, 1:02:03.
String formatDuration(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// "12 minutes", "1 hour 5 minutes" (for screen readers).
String spokenDuration(Duration d) {
  final m = d.inMinutes, h = m ~/ 60, rest = m % 60;
  String unit(int n, String w) => '$n $w${n == 1 ? '' : 's'}';
  if (h == 0) return unit(m, 'minute');
  return rest == 0 ? unit(h, 'hour') : '${unit(h, 'hour')} ${unit(rest, 'minute')}';
}

/// What the display shows at [now]: a pomodoro counts down, a stopwatch up.
({Duration shown, bool overdue}) focusDisplay(FocusSessionView s, Instant now) {
  if (s.mode == FocusSessionMode.pomodoro) {
    final left = s.remainingAt(now) ?? Duration.zero;
    return (shown: left, overdue: left == Duration.zero && s.status == FocusSessionStatus.running);
  }
  return (shown: s.focusTimeAt(now), overdue: false);
}

/// Rebuilds on every tick of [focusTickerProvider] with the current time.
class FocusTicking extends ConsumerStatefulWidget {
  const FocusTicking({super.key, required this.builder});
  final Widget Function(BuildContext context, Instant now) builder;
  @override
  ConsumerState<FocusTicking> createState() => _FocusTickingState();
}

class _FocusTickingState extends ConsumerState<FocusTicking> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(focusTickerProvider)().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, ref.read(focusClockProvider)());
}

/// D2: one session at a time. With one running, offers to open it.
Future<void> startFocus(BuildContext context, WidgetRef ref,
    {String? taskId, String? taskTitle, LocalDate? occurrenceDate}) async {
  final active = ref.read(activeFocusProvider).valueOrNull;
  if (active != null) {
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('A focus session is running'),
        content: const Text('End it first: only one session can run at a time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Open it')),
        ],
      ),
    );
    if (open == true && context.mounted) await openFocusPage(context);
    return;
  }
  final choice = await showDialog<(FocusSessionMode, Duration?)>(
      context: context, builder: (_) => _StartDialog(taskTitle: taskTitle));
  if (choice == null || !context.mounted) return;
  final r = await ref
      .read(focusServiceProvider)
      .start(mode: choice.$1, planned: choice.$2, taskId: taskId, occurrenceDate: occurrenceDate);
  if (!context.mounted) return;
  if (r is CommandFailure) {
    showMessage(context, describeFailure(r));
    return;
  }
  await openFocusPage(context);
}

Future<void> openFocusPage(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const FocusPage()));

/// D5: ending asks whether to save the session as done work.
Future<void> endFocus(BuildContext context, WidgetRef ref, FocusSessionView s) async {
  final now = ref.read(focusClockProvider)();
  final count = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('End the session?'),
      content: Text('Focused for ${spokenDuration(s.focusTimeAt(now))}. '
          'Saving it records the time you worked; it does not complete the task.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Keep going')),
        TextButton(key: const Key('focus-end-discard'), onPressed: () => Navigator.pop(c, false), child: const Text("Don't save")),
        FilledButton(key: const Key('focus-end-save'), onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
      ],
    ),
  );
  if (count == null || !context.mounted) return;
  await reportResult(context, ref.read(focusServiceProvider).end(s.id, count: count));
}

class _StartDialog extends StatefulWidget {
  const _StartDialog({this.taskTitle});
  final String? taskTitle;
  @override
  State<_StartDialog> createState() => _StartDialogState();
}

class _StartDialogState extends State<_StartDialog> {
  var _mode = FocusSessionMode.pomodoro;
  final _minutes = TextEditingController(text: '${defaultPomodoroInterval.inMinutes}');
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _start() {
    if (_mode == FocusSessionMode.stopwatch) {
      Navigator.pop(context, (_mode, null));
      return;
    }
    final m = int.tryParse(_minutes.text.trim());
    if (m == null || m < 1 || m > maxPomodoroInterval.inMinutes) {
      setState(() => _error = 'Between 1 and ${maxPomodoroInterval.inMinutes} minutes.');
      return;
    }
    Navigator.pop(context, (_mode, Duration(minutes: m)));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.taskTitle == null ? 'Focus' : 'Focus on ${widget.taskTitle}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<FocusSessionMode>(
            key: const Key('focus-mode'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: FocusSessionMode.pomodoro, label: Text('Pomodoro'), icon: Icon(Icons.timer_outlined)),
              ButtonSegment(value: FocusSessionMode.stopwatch, label: Text('Stopwatch'), icon: Icon(Icons.av_timer)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          if (_mode == FocusSessionMode.pomodoro)
            TextField(
              key: const Key('focus-minutes'),
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Minutes', errorText: _error),
              onSubmitted: (_) => _start(),
            )
          else
            const Text('Counts up until you end it.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const Key('focus-start'), onPressed: _start, child: const Text('Start')),
        ],
      );
}

class FocusPage extends ConsumerWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeFocusProvider);
    final s = active.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Focus'),
      ),
      body: s == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(active.isLoading ? '' : 'No focus session is running.',
                    key: const Key('focus-none'), style: Theme.of(context).textTheme.bodyLarge),
              ),
            )
          : FocusTicking(builder: (context, now) => _FocusBody(session: s, now: now)),
    );
  }
}

class _FocusBody extends ConsumerWidget {
  const _FocusBody({required this.session, required this.now});
  final FocusSessionView session;
  final Instant now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final d = focusDisplay(s, now);
    final paused = s.status == FocusSessionStatus.paused;
    final theme = Theme.of(context);
    final service = ref.read(focusServiceProvider);
    final pomodoro = s.mode == FocusSessionMode.pomodoro;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text(s.taskTitle ?? 'Focus without a task', key: const Key('focus-task'), style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(pomodoro ? 'Pomodoro · ${s.planned!.inMinutes} minutes' : 'Stopwatch', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Semantics(
          container: true,
          liveRegion: d.overdue,
          label: d.overdue
              ? 'Time is up'
              : pomodoro
                  ? '${spokenDuration(d.shown)} left${paused ? ', paused' : ''}'
                  : '${spokenDuration(d.shown)} focused${paused ? ', paused' : ''}',
          excludeSemantics: true,
          child: FittedBox(
            child: Text(formatDuration(d.shown),
                key: const Key('focus-time'),
                style: theme.textTheme.displayLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: paused ? theme.colorScheme.outline : null)),
          ),
        ),
        if (d.overdue) Text('Time is up', key: const Key('focus-overdue'), style: theme.textTheme.titleMedium),
        if (paused) const Text('Paused'),
        if (pomodoro) Text('Focused ${formatDuration(s.focusTimeAt(now))}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 32),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          FilledButton.tonalIcon(
            key: const Key('focus-pause'),
            onPressed: () => reportResult(context, paused ? service.resume(s.id) : service.pause(s.id)),
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            label: Text(paused ? 'Resume' : 'Pause'),
          ),
          FilledButton.icon(
            key: const Key('focus-end'),
            onPressed: () => endFocus(context, ref, s),
            icon: const Icon(Icons.stop),
            label: const Text('End'),
          ),
          TextButton(
            key: const Key('focus-cancel'),
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Cancel the session?'),
                  content: const Text('Nothing is recorded.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
                    FilledButton(key: const Key('focus-cancel-confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Cancel it')),
                  ],
                ),
              );
              if (yes == true && context.mounted) await reportResult(context, service.cancel(s.id));
            },
            child: const Text('Cancel session'),
          ),
        ]),
      ]),
    );
  }
}

/// D4: shown above the navigation on every screen while a session runs.
class FocusBar extends ConsumerWidget {
  const FocusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(activeFocusProvider).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final paused = s.status == FocusSessionStatus.paused;
    final service = ref.read(focusServiceProvider);
    return Material(
      key: const Key('focus-bar'),
      color: scheme.secondaryContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: FocusTicking(builder: (context, now) {
          final d = focusDisplay(s, now);
          final what = s.taskTitle ?? 'Focus';
          return InkWell(
            onTap: () => openFocusPage(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(children: [
                Icon(s.mode == FocusSessionMode.pomodoro ? Icons.timer_outlined : Icons.av_timer,
                    color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Focus: $what, ${d.overdue ? 'time is up' : formatDuration(d.shown)}'
                        '${paused ? ', paused' : ''}. Open',
                    excludeSemantics: true,
                    child: Text(
                      '${d.overdue ? 'Time is up' : formatDuration(d.shown)} · $what${paused ? ' · paused' : ''}',
                      key: const Key('focus-bar-text'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('focus-bar-pause'),
                  tooltip: paused ? 'Resume focus' : 'Pause focus',
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  onPressed: () => reportResult(context, paused ? service.resume(s.id) : service.pause(s.id)),
                ),
                IconButton(
                  key: const Key('focus-bar-end'),
                  tooltip: 'End focus',
                  icon: const Icon(Icons.stop),
                  onPressed: () => endFocus(context, ref, s),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

/// D1: asks once, after the profile opened, about the session it found.
class FocusLaunchPrompt extends ConsumerStatefulWidget {
  const FocusLaunchPrompt({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<FocusLaunchPrompt> createState() => _FocusLaunchPromptState();
}

class _FocusLaunchPromptState extends ConsumerState<FocusLaunchPrompt> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    if (_asked || !mounted) return;
    _asked = true;
    final launch = ref.read(focusLaunchProvider);
    switch (launch) {
      case NoActiveFocus():
        return;
      case FocusResumed(:final session):
        // A pomodoro continues by itself; a stopwatch asks (D1).
        if (session.mode == FocusSessionMode.pomodoro) return;
        final end = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text('Your stopwatch is still running'),
            content: Text(
                '${session.taskTitle ?? 'Focus'}: ${spokenDuration(session.focusTimeAt(ref.read(focusClockProvider)()))} so far.'),
            actions: [
              TextButton(key: const Key('launch-end'), onPressed: () => Navigator.pop(c, true), child: const Text('End now')),
              FilledButton(key: const Key('launch-resume'), onPressed: () => Navigator.pop(c, false), child: const Text('Resume')),
            ],
          ),
        );
        if (end == true && mounted) await endFocus(context, ref, session);
      case FocusOverdue(:final session):
        final choice = await showDialog<OverdueChoice>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text('Your pomodoro ended while LifeFlow was closed'),
            content: Text('${session.taskTitle ?? 'Focus'}: ${session.planned!.inMinutes} minutes. '
                'How should it be saved?'),
            actions: [
              TextButton(
                  key: const Key('launch-discard'),
                  onPressed: () => Navigator.pop(c, OverdueChoice.discard),
                  child: const Text('Discard')),
              TextButton(
                  key: const Key('launch-to-now'),
                  onPressed: () => Navigator.pop(c, OverdueChoice.countToNow),
                  child: const Text('Count until now')),
              FilledButton(
                  key: const Key('launch-to-end'),
                  onPressed: () => Navigator.pop(c, OverdueChoice.countToPlannedEnd),
                  child: const Text('Count until it ended')),
            ],
          ),
        );
        if (choice != null && mounted) {
          await reportResult(context, ref.read(focusServiceProvider).resolveOverdue(session.id, choice));
        }
      case FocusUnrecoverable(:final reason):
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('A focus session could not be recovered'),
            content: Text('It is kept as it was stored, and nothing was recorded for it ($reason). '
                'You can start a new session.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
