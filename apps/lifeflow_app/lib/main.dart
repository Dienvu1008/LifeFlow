import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:path_provider/path_provider.dart';

import 'auth/supabase_auth_gateway.dart';
import 'bootstrap.dart';
import 'root.dart';
import 'secure_key_store.dart';

/// ADR-0022 controlled fallback: build with
/// `--dart-define=LIFEFLOW_WINDOWS_PLAIN_DB=true` to keep plain databases on
/// Windows. Only for a fresh install: an already-encrypted database is never
/// downgraded (the app reports it instead).
const windowsPlainFallback = bool.fromEnvironment('LIFEFLOW_WINDOWS_PLAIN_DB');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final platform = storagePlatformFor(defaultTargetPlatform);
  // App-private support directory, not the user's Documents (privacy-model §2).
  final baseDir = Directory((await getApplicationSupportDirectory()).path);

  final ProfileDirectory directory;
  try {
    // SR-03 / ADR-0023: one encrypted file + key per profile, plus a small
    // encrypted registry. The pre-SR-03 shared database (if any) is split by
    // profile once and kept as an encrypted backup.
    directory = await ProfileDirectory.open(
      baseDir: baseDir,
      policy: atRestPolicyFor(platform, windowsPlainFallback: windowsPlainFallback),
      keysFor: secureKeyStoreFor,
    );
  } on StoreUnavailable catch (e) {
    // Never delete or overwrite the user's data to "recover".
    debugPrint('[storage] $e');
    runApp(StoreErrorApp(reason: e.reason));
    return;
  }
  final migration = directory.lastMigration;
  if (migration != null) {
    debugPrint('[storage] split the shared database into '
        '${migration.profiles} profile store(s); '
        '${migration.unmappedGovernanceRows} unattributed governance row(s) '
        'remain in the kept backup');
  }

  // Sign-in is optional (ADR-0008). A build without Supabase defines still
  // runs fully as a guest. Initializing makes no network call.
  final auth = await SupabaseAuthGateway.initialize();

  // Never a locked (signed-out) profile: ProfileDirectory.open falls back to
  // a guest (ADR-0024).
  final active = (await directory.active())!;
  runApp(LifeFlowRoot(
    initialProfileId: active.id,
    sessionRevoked: auth.sessionRevoked,
    openSession: (profileId, host, initialRoute) => openSession(
      directory: directory,
      profileId: profileId,
      platform: platform,
      auth: auth,
      host: host,
      initialRoute: initialRoute,
      windowsPlainFallback: windowsPlainFallback,
      // Local log only; never uploaded (no telemetry, SR-15).
      onWarning: (m) => debugPrint('[storage] $m'),
    ),
  ));
}
