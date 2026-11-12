// P03 UX U1 (ADR-0045, U-D11): the UI's strings. Every user-facing text in
// a migrated file comes from lib/l10n/app_en.arb through `context.l10n`.
// Only English exists yet; adding a language is adding an ARB file.
import 'package:flutter/widgets.dart';

import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

extension L10nOf on BuildContext {
  /// The strings for this context's locale. Falls back to English when no
  /// localizations are installed above (isolated widget tests).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? lookupAppLocalizations(const Locale('en'));
}
