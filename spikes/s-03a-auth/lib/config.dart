// THROWAWAY spike S-03a. Config read from --dart-define (no secrets in code).
//
// Run with:
//   flutter run -d windows \
//     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<anon key>
//
// The anon key is a public client key (safe to pass as a define); it is NOT a
// secret in the SR-02 sense. No service_role key is ever used in the client.
class SpikeConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Fixed desktop loopback redirect (chosen in the spike plan).
  static const desktopPort = 53682;
  static const desktopRedirect = 'http://127.0.0.1:$desktopPort/callback';

  // Android/mobile deep-link redirect (configured in Supabase + AndroidManifest).
  static const mobileRedirect = 'lifeflow://callback';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
