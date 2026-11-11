import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages.dart';
import '../shell.dart' show shellMenuButton;
import '../providers.dart';
import 'account_card.dart';
import 'data_card.dart';

/// Profile chooser (OQ-S7): every profile on the device stays listed and its
/// data stays on the device. Switching re-scopes the whole app to that
/// profile's workspace (LF-INV-ID-002).
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Profiles')),
      body: profiles.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading profiles'),
        ),
        error: (e, _) => const Center(child: Text('Could not load profiles.')),
        data: (list) {
          final active = list.where((p) => p.isActive).firstOrNull;
          return ListView(
            children: [
              if (active != null) AccountCard(profile: active),
              if (active != null) const DataCard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('Profiles on this device',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final p in list) _ProfileTile(profile: p),
            ],
          );
        },
      ),
    );
  }
}

String _title(ProfileView p) {
  if (p.displayName.trim().isNotEmpty) return p.displayName;
  return p.isBound ? 'Account profile' : 'Guest';
}

String _subtitle(ProfileView p) {
  if (!p.isBound) return 'Guest profile, data stays on this device';
  final provider = switch (p.provider) {
    'github' => 'GitHub',
    'email' => 'email',
    final other? => other,
    null => 'an account',
  };
  // ADR-0024: the account signed out; its data is kept but locked.
  if (p.isLocked) return '$provider account · signed out. Sign in to open it.';
  return 'Signed in with $provider';
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile});
  final ProfileView profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final Widget action = p.isActive
        ? const Chip(label: Text('Active'))
        : p.isLocked
            ? FilledButton.tonalIcon(
                // Signing in with this profile's account unlocks and opens
                // it (ADR-0024); another account goes to its own profile.
                onPressed: () => startSignIn(context, ref),
                icon: const Icon(Icons.login),
                label: const Text('Sign in to open'),
              )
            : FilledButton.tonal(
                onPressed: () => _switch(context, ref),
                child: const Text('Switch'),
              );
    return ListTile(
      key: ValueKey('profile-${p.id}'),
      leading: CircleAvatar(
        child: Icon(p.isLocked
            ? Icons.lock_outline
            : p.isBound
                ? Icons.account_circle
                : Icons.person_outline),
      ),
      title: Text(_title(p)),
      subtitle: Text(_subtitle(p)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          action,
          // The open profile cannot be deleted (switch first, ADR-0027).
          if (!p.isActive)
            IconButton(
              tooltip: 'Delete ${_title(p)}',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final p = profile;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('delete-profile'),
        title: Text('Delete "${_title(p)}"?'),
        content: Text(
          'All tasks and history of this profile are deleted from this '
          'device. This cannot be undone.'
          '${p.isBound ? ' Nothing of it is stored online yet, so the '
              'account cannot bring it back.' : ''}'
          '\n\nTo keep a copy, switch to it and export it first.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete profile'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await ref.read(profileServiceProvider).delete(p.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(result is CommandFailure
              ? describeFailure(result)
              : '"${_title(p)}" was deleted.')));
    ref.invalidate(profilesProvider);
  }

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(profileServiceProvider).switchTo(profile.id);
    if (result is CommandFailure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(describeFailure(result))));
      }
      return;
    }
    // In the app the whole provider scope is rebuilt for the new profile's
    // store (SR-03), which unmounts this widget; then there is nothing left
    // to refresh and `ref` must not be used.
    if (!context.mounted) return;
    // Re-scope everything to the newly active profile.
    ref.invalidate(activeProfileProvider);
    ref.invalidate(profilesProvider);
  }
}
