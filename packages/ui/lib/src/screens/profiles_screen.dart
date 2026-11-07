import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages.dart';
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
      appBar: AppBar(title: const Text('Profiles')),
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
      trailing: p.isActive
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
                ),
    );
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
