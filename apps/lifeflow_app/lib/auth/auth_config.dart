/// Sign-in configuration, read from `--dart-define` at build time. The anon
/// (publishable) key is a public client key, safe to ship; no service_role key
/// is ever used in the client. Nothing secret lives in the repository.
///
/// ```text
/// flutter run -d windows \
///   --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
/// ```
class AuthConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Fixed desktop loopback redirect (spike S-03a). Must be listed in the
  /// Supabase project's redirect URLs.
  static const desktopPort = 53682;
  static const desktopRedirect = 'http://127.0.0.1:$desktopPort/callback';

  /// Android deep link (AndroidManifest intent-filter). Must also be listed in
  /// the Supabase project's redirect URLs.
  static const mobileRedirect = 'lifeflow://callback';

  static const oauthTimeout = Duration(minutes: 3);

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
