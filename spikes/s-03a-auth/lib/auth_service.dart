// THROWAWAY spike S-03a. Thin wrapper over Supabase Auth for the POC.
//
// Key points for the success criteria:
// - Session is persisted by supabase_flutter into secure storage (see main.dart
//   gotrueAsyncStorage wiring), so it survives an offline restart (SR-07).
// - Windows desktop uses a fixed-port loopback + PKCE S256 (SR-06) via
//   DesktopLoopback; Android uses the deep-link redirect.
// - OFFLINE policy: "signed in" is derived from the cached session WITHOUT a
//   network call. If the access token is expired and offline, we treat the
//   user as signed-in but READ-ONLY until a refresh succeeds online (this is a
//   success criterion, surfaced via authStatus).
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'desktop_loopback.dart';

enum AuthStatus { signedOut, signedIn, signedInReadOnlyOffline }

class AuthService {
  SupabaseClient get _c => Supabase.instance.client;

  Session? get session => _c.auth.currentSession;

  /// Derives status from the cached session only — no network call.
  AuthStatus statusOffline({required bool online}) {
    final s = session;
    if (s == null) return AuthStatus.signedOut;
    final expired = s.expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= s.expiresAt!;
    if (expired && !online) return AuthStatus.signedInReadOnlyOffline;
    return AuthStatus.signedIn;
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Email/password sign-in (baseline check; GitHub is the social path).
  Future<void> signInWithEmail(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await _c.auth.signUp(email: email, password: password);
  }

  /// GitHub OAuth. Desktop: manual loopback + PKCE S256 + code exchange.
  /// Mobile/web: supabase_flutter handles the redirect via deep link.
  Future<void> signInWithGitHub() async {
    if (_isDesktop) {
      await _desktopGitHub();
    } else {
      await _c.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: SpikeConfig.mobileRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _desktopGitHub() async {
    // Let the SDK build the authorize URL; it generates and stores the PKCE
    // code_verifier (and its own state) internally. We must NOT supply our own
    // PKCE or state — that caused the earlier "State mismatch".
    final res = await _c.auth.getOAuthSignInUrl(
      provider: OAuthProvider.github,
      redirectTo: SpikeConfig.desktopRedirect,
    );

    // Capture the redirect (?code=...) on the fixed loopback port.
    final result = await DesktopLoopback.capture(
      authorizeUrl: Uri.parse(res.url),
    );

    // The SDK reads the stored verifier and exchanges the code for a session,
    // which it then persists via the configured secure async storage.
    await _c.auth.exchangeCodeForSession(result.code);
  }

  Future<void> signOut() => _c.auth.signOut();
}
