import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ui/ui.dart';

import 'auth/supabase_auth_gateway.dart';
import 'bootstrap.dart';
import 'secure_key_store.dart';

/// ADR-0022 controlled fallback: build with
/// `--dart-define=LIFEFLOW_WINDOWS_PLAIN_DB=true` to keep a plain database on
/// Windows. Only for a fresh install: an already-encrypted database is never
/// downgraded (the app reports it instead).
const windowsPlainFallback = bool.fromEnvironment('LIFEFLOW_WINDOWS_PLAIN_DB');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final platform = storagePlatformFor(defaultTargetPlatform);
  // App-private support directory, not the user's Documents (privacy-model §2).
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}lifeflow.sqlite');

  final OpenedStore store;
  try {
    // ADR-0022: encrypted on every platform with a key from secure storage.
    // An existing plain DB from an earlier build is encrypted in place.
    // The ADR-0021 plain Windows posture survives only as an explicit build
    // flag (controlled fallback), and is then shown as a tracked exception.
    store = await openLocalStore(
      file: file,
      policy: atRestPolicyFor(platform, windowsPlainFallback: windowsPlainFallback),
      keys: const SecureDatabaseKeyStore(),
    );
  } on StoreUnavailable catch (e) {
    // Never delete or overwrite the user's data to "recover".
    debugPrint('[storage] $e');
    runApp(StoreErrorApp(reason: e.reason));
    return;
  }
  if (store.migratedToEncrypted) {
    debugPrint('[storage] existing database encrypted at rest');
  }

  // Sign-in is optional (ADR-0008). A build without Supabase defines still
  // runs fully as a guest. Initializing makes no network call.
  final auth = await SupabaseAuthGateway.initialize();

  final wiring = await bootstrap(
    store.db,
    platform: platform,
    cipherProbe: fileCipherProbe(file),
    auth: auth,
    windowsPlainFallback: windowsPlainFallback,
    // Local log only; never uploaded (no telemetry, SR-15).
    onWarning: (m) => debugPrint('[storage] $m'),
  );

  runApp(ProviderScope(overrides: wiring.overrides, child: const LifeFlowApp()));
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
        home: Scaffold(
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
      );
}
