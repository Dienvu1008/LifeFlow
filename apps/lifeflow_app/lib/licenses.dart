// ADR-0035: licenses of shipped code that Flutter does not list by itself.
// Dart packages register their own LICENSE files; Android libraries pulled in
// by Gradle do not, so their notices are bundled as assets and added here.
// They appear in Settings > Open-source licenses (showLicensePage).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shown as the package name on the license page.
const desugarPackageName = 'desugar_jdk_libs (Android)';

const _dir = 'assets/licenses/desugar_jdk_libs';

/// Adds the desugar_jdk_libs notices (GPL-2.0 with the Classpath Exception)
/// to the app's license list. Call once at startup.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final source = await rootBundle.loadString('$_dir/SOURCE');
    final parts = [
      for (final f in ['LICENSE', 'ASSEMBLY_EXCEPTION', 'ADDITIONAL_LICENSE_INFO'])
        await rootBundle.loadString('$_dir/$f'),
    ];
    yield LicenseEntryWithLineBreaks(
      const [desugarPackageName],
      'Android core library desugaring, used unmodified by the Android build.\n'
      '${source.trim()}\n\n${parts.join('\n\n')}',
    );
  });
}
