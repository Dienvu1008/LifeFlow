import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ui/ui.dart';

import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // P01: a plain local database on every platform for now. The encrypted
  // executor is wired when the per-platform path is verified (ADR-0021);
  // until then the startup self-check reports the real state to the user.
  // Stored in the app-private support directory, not the user's Documents
  // folder (drift_flutter's default), per privacy-model §2.
  final db = AppDatabase(driftDatabase(
    name: 'lifeflow',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  ));

  final wiring = await bootstrap(
    db,
    platform: storagePlatformFor(defaultTargetPlatform),
    // Local log only; never uploaded (no telemetry, SR-15).
    onWarning: (m) => debugPrint('[storage] $m'),
  );

  runApp(ProviderScope(overrides: wiring.overrides, child: const LifeFlowApp()));
}
