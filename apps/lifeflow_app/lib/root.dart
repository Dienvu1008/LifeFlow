import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:ui/ui.dart';

import 'bootstrap.dart';

/// Opens a profile's session. Injected so tests can wire it differently.
/// [initialRoute] is '/profiles' after a sign-out (OQ-S7).
typedef SessionOpener = Future<AppWiring> Function(
    String profileId, ProfileHost host, String initialRoute);

/// App root and profile host (SR-03): owns the ACTIVE profile's session and
/// swaps it when the user switches profile, signs in to another profile, or
/// signs out (ADR-0024). The provider scope is keyed by profile id, so every
/// provider (task stream, services, router) is rebuilt for the new store; the
/// previous store is closed after the new one is on screen.
class LifeFlowRoot extends StatefulWidget {
  const LifeFlowRoot({
    super.key,
    required this.initialProfileId,
    required this.openSession,
    this.sessionRevoked = const Stream.empty(),
  });

  final String initialProfileId;
  final SessionOpener openSession;

  /// The identity provider ended the session while online (ADR-0024).
  final Stream<void> sessionRevoked;

  @override
  State<LifeFlowRoot> createState() => LifeFlowRootState();
}

class LifeFlowRootState extends State<LifeFlowRoot> {
  AppWiring? _session;
  Object? _error;
  late final ProfileHost _host = _RootHost(this);
  StreamSubscription<void>? _revokedSub;

  String? get activeProfileId => _session?.profileId;

  @override
  void initState() {
    super.initState();
    _revokedSub = widget.sessionRevoked.listen((_) {
      _session?.onSessionRevoked();
    });
    _open(widget.initialProfileId);
  }

  Future<void> _open(String profileId) async {
    try {
      final s = await widget.openSession(profileId, _host, '/overview');
      if (!mounted) {
        await s.close();
        return;
      }
      setState(() => _session = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _switchTo(String profileId, {required bool showProfiles}) async {
    if (_session?.profileId == profileId) return;
    final previous = _session;
    // P02 T7: the old profile must not re-schedule its reminders once the
    // next profile has replaced them (ADR-0034).
    await previous?.stopReminders();
    final AppWiring next;
    try {
      next = await widget.openSession(
          profileId, _host, showProfiles ? '/profiles' : '/overview');
    } catch (_) {
      await previous?.reminders?.start(); // still on the old profile
      rethrow;
    }
    if (!mounted) {
      await next.close();
      return;
    }
    setState(() => _session = next);
    // Close the old store once the old scope has been torn down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous?.close();
    });
  }

  @override
  void dispose() {
    _revokedSub?.cancel();
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return StoreErrorApp(
          reason: error is StoreUnavailable ? error.reason : '$error');
    }
    final s = _session;
    if (s == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
              child: CircularProgressIndicator(semanticsLabel: 'Opening LifeFlow')),
        ),
      );
    }
    return ProviderScope(
      key: ValueKey(s.profileId),
      overrides: s.overrides,
      child: const LifeFlowApp(),
    );
  }
}

/// The [ProfileHost] handed to services; delegates to the root state.
/// (A State cannot implement it directly: `State.activate` already exists.)
class _RootHost implements ProfileHost {
  _RootHost(this._root);
  final LifeFlowRootState _root;
  @override
  Future<void> activate(String profileId, {bool showProfiles = false}) =>
      _root._switchTo(profileId, showProfiles: showProfiles);
}

/// Shown when the local store cannot be opened safely (for example the key
/// is missing from secure storage, OQ-DATA-1). Explains, does not destroy.
class StoreErrorApp extends StatelessWidget {
  const StoreErrorApp({super.key, required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LifeFlow',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LifeFlow cannot open your data',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(
                      'Your data has not been changed or deleted. '
                      'If you have a LifeFlow export, it can be restored later.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    SelectableText('Details: $reason',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
