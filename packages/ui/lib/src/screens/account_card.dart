import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages.dart';
import '../providers.dart';

/// Sign-in state of the ACTIVE profile, with sign-in / sign-out (ADR-0008,
/// OQ-S7). Signing in is optional: the app is fully usable as a guest.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key, required this.profile});
  final ProfileView profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountServiceProvider);
    final theme = Theme.of(context);
    final provider = switch (profile.provider) {
      'github' => 'GitHub',
      'email' => 'email',
      _ => 'an account',
    };

    return Card(
      key: const Key('account-card'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              profile.isBound
                  ? 'Signed in with $provider.'
                  : 'Using LifeFlow as a guest. Your data stays on this device.',
            ),
            const SizedBox(height: 12),
            if (profile.isBound)
              OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              )
            else if (accounts.signInAvailable)
              FilledButton.icon(
                onPressed: () => startSignIn(context, ref),
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              )
            else
              Text('Sign-in is not configured in this build.',
                  style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your data stays on this device, locked until you sign in again '
            'with this account. LifeFlow switches to a guest profile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await ref.read(accountServiceProvider).signOut();
    if (!context.mounted) return;
    if (r is CommandFailure) {
      _snack(context, describeFailure(r));
      return;
    }
    // In the app the scope is replaced by the guest's (so this point is not
    // reached); kept for hosts that update in place.
    _refresh(ref);
    _snack(context, 'Signed out. Sign in again to open your data.');
  }
}

/// The whole sign-in flow: credentials -> provider -> (if needed) the
/// move-or-new choice -> refresh. Exposed for tests.
Future<void> startSignIn(BuildContext context, WidgetRef ref) async {
  final request = await showDialog<SignInRequest>(
    context: context,
    builder: (_) => const SignInDialog(),
  );
  if (request == null || !context.mounted) return;

  final accounts = ref.read(accountServiceProvider);
  var outcome = await _withProgress(context, accounts.signIn(request),
      waitingForBrowser: request is OAuthSignIn);
  if (!context.mounted) return;

  if (outcome is NeedsBindChoice) {
    final move = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Move your data to this account?'),
        content: const Text(
          'Move the data you are using now to this account?\n\n'
          'Move: this profile and everything in it now belongs to the account.\n'
          'New space: the account starts empty. Your current data stays on this '
          'device as a separate guest profile.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('New space')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Move my data')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (move == null) {
      await accounts.cancelPendingBind();
      return;
    }
    outcome = await accounts.completeBind(moveData: move);
    if (!context.mounted) return;
  }

  switch (outcome) {
    case SignedIn(:final switchedProfile):
      _refresh(ref);
      _snack(
          context,
          switchedProfile
              ? 'Signed in. Switched to this account\'s profile.'
              : 'Signed in.');
    case SignInFailed(:final message):
      _snack(context, message);
    case NeedsBindChoice():
      break; // handled above
  }
}

Future<T> _withProgress<T>(BuildContext context, Future<T> work,
    {required bool waitingForBrowser}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(semanticsLabel: 'Signing in'),
          const SizedBox(width: 16),
          Expanded(
            child: Text(waitingForBrowser
                ? 'Finish signing in in your browser.'
                : 'Signing in...'),
          ),
        ]),
      ),
    ),
  );
  try {
    return await work;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

void _refresh(WidgetRef ref) {
  ref.invalidate(activeProfileProvider);
  ref.invalidate(profilesProvider);
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Email + password, or GitHub. Returns the request; never stores anything.
class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});
  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submitEmail() {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    Navigator.pop(context, EmailPasswordSignIn(email, _password.text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sign in'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.pop(context, const OAuthSignIn('github')),
                icon: const Icon(Icons.code),
                label: const Text('Continue with GitHub'),
              ),
              const SizedBox(height: 16),
              const Text('or use email'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(labelText: 'Password', errorText: _error),
                onSubmitted: (_) => _submitEmail(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submitEmail, child: const Text('Sign in')),
        ],
      );
}
