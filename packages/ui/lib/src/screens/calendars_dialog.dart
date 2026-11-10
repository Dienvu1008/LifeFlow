// P02 T6b: manage the calendars of the active profile. Trashing a calendar
// keeps its events; they lose the calendar (ADR-0031).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../task_actions.dart';

/// Colours offered for a calendar (ARGB), with names for assistive tech.
const calendarPalette = <(int, String)>[
  (0xFF00897B, 'Teal'),
  (0xFF1E88E5, 'Blue'),
  (0xFF8E24AA, 'Purple'),
  (0xFFE53935, 'Red'),
  (0xFFFB8C00, 'Orange'),
  (0xFFFDD835, 'Yellow'),
  (0xFF43A047, 'Green'),
  (0xFF6D4C41, 'Brown'),
];

class CalendarsDialog extends ConsumerWidget {
  const CalendarsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendars = ref.watch(calendarsProvider);
    final service = ref.read(calendarServiceProvider);
    return AlertDialog(
      title: const Text('Calendars'),
      content: SizedBox(
        width: 420,
        child: calendars.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Could not load the calendars.'),
          data: (list) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No calendars yet. Events can also be without a calendar.'),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in list)
                      ListTile(
                        key: ValueKey('calendar-${c.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.circle, color: Color(c.color)),
                        title: Text(c.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit ${c.name}',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                final r = await showDialog<(String, int)>(
                                    context: context,
                                    builder: (_) => _CalendarForm(title: 'Edit calendar', name: c.name, color: c.color));
                                if (r == null || !context.mounted) return;
                                await reportResult(context, service.update(c.id, name: r.$1, color: r.$2));
                              },
                            ),
                            IconButton(
                              tooltip: 'Move ${c.name} to the trash',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Move "${c.name}" to the trash?'),
                                    content: const Text('Its events stay, without a calendar.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Move to trash')),
                                    ],
                                  ),
                                );
                                if (yes != true || !context.mounted) return;
                                await reportResult(context, service.trash(c.id));
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('calendar-add'),
          icon: const Icon(Icons.add),
          label: const Text('New calendar'),
          onPressed: () async {
            final r = await showDialog<(String, int)>(
                context: context,
                builder: (_) => _CalendarForm(title: 'New calendar', name: '', color: calendarPalette.first.$1));
            if (r == null || !context.mounted) return;
            await reportResult(context, service.create(r.$1, color: r.$2));
          },
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

/// Name and colour. Pops (name, color), or null when cancelled.
class _CalendarForm extends StatefulWidget {
  const _CalendarForm({required this.title, required this.name, required this.color});
  final String title;
  final String name;
  final int color;
  @override
  State<_CalendarForm> createState() => _CalendarFormState();
}

class _CalendarFormState extends State<_CalendarForm> {
  late final _c = TextEditingController(text: widget.name);
  late int _color = widget.color;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _c.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    Navigator.pop(context, (name, _color));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('calendar-name'),
              controller: _c,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Name', errorText: _error),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (argb, name) in calendarPalette)
                  Semantics(
                    label: name,
                    selected: argb == _color,
                    button: true,
                    excludeSemantics: true,
                    child: InkResponse(
                      key: ValueKey('color-$name'),
                      onTap: () => setState(() => _color = argb),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(argb),
                        child: argb == _color ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      );
}
