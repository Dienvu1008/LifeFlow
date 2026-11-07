// P01 T6b: the real AuthGateway over Supabase Auth (ADR-0003), following
// spike S-03a: the SDK owns PKCE (S256) and state; Windows uses a fixed
// loopback redirect, Android a deep link. Tokens, the session and the PKCE
// verifier live only in secure storage (LF-INV-SEC-001); nothing here is
// called on the data read path (LF-INV-SEC-002).
import 'dart:async';
import 'dart:io';

import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foundation/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';
import 'desktop_loopback.dart';

const _secure = FlutterSecureStorage();

/// The Supabase session, persisted in platform secure storage (SR-02/SR-07).
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();
  static const _key = 'lifeflow.auth.session.v1';

  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() => _secure.read(key: _key);
  @override
  Future<bool> hasAccessToken() => _secure.containsKey(key: _key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _secure.write(key: _key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _secure.delete(key: _key);
}

/// The PKCE code verifier, also in secure storage instead of the SDK's
/// shared_preferences default (it is a secret for the duration of the flow).
class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage();
  static const _prefix = 'lifeflow.auth.pkce.';

  @override
  Future<String?> getItem({required String key}) =>
      _secure.read(key: '$_prefix$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      _secure.write(key: '$_prefix$key', value: value);
  @override
  Future<void> removeItem({required String key}) =>
      _secure.delete(key: '$_prefix$key');
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway._(this.isConfigured) {
    if (isConfigured) {
      // gotrue emits signedOut when it gives up on the session itself (an
      // invalid/revoked refresh token, seen only online). Network failures
      // during refresh are retried and do NOT emit it, so being offline never
      // locks a profile (LF-INV-SEC-002, ADR-0024).
      _auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.signedOut && !_signingOut) {
          _revoked.add(null);
        }
      }, onError: (Object _) {});
    }
  }

  @override
  final bool isConfigured;

  final _revoked = StreamController<void>.broadcast();
  bool _signingOut = false;

  @override
  Stream<void> get sessionRevoked => _revoked.stream;

  /// Initializes the SDK when the build has a Supabase URL + anon key
  /// (`--dart-define`). Without them sign-in is unavailable but the app works
  /// fully as a guest (ADR-0008).
  static Future<SupabaseAuthGateway> initialize() async {
    if (!AuthConfig.isConfigured) return SupabaseAuthGateway._(false);
    await Supabase.initialize(
      url: AuthConfig.supabaseUrl,
      // The anon key is the "publishable" client key in the current SDK.
      publishableKey: AuthConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureSessionStorage(),
        pkceAsyncStorage: SecurePkceStorage(),
      ),
      debug: false, // never log auth traffic (SR-08)
    );
    return SupabaseAuthGateway._(true);
  }

  GoTrueClient get _auth => Supabase.instance.client.auth;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    if (!isConfigured) {
      throw const AuthFailure(
          AuthFailureKind.notConfigured, 'Sign-in is not configured in this build.');
    }
    try {
      switch (request) {
        case EmailPasswordSignIn(:final email, :final password):
          await _auth.signInWithPassword(email: email.trim(), password: password);
        case OAuthSignIn(:final provider):
          if (provider != 'github') {
            throw AuthFailure(AuthFailureKind.other, 'Unsupported provider: $provider');
          }
          await (_isDesktop ? _desktopGitHub() : _mobileGitHub());
      }
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw _fromAuthException(e);
    } on SocketException {
      throw const AuthFailure(AuthFailureKind.network,
          'Could not reach the sign-in service. Check your connection.');
    } on TimeoutException {
      throw const AuthFailure(
          AuthFailureKind.cancelled, 'Sign-in was not completed in time.');
    }
    final session = _toSession(_auth.currentSession);
    if (session == null) {
      throw const AuthFailure(AuthFailureKind.other, 'Sign-in did not return a session.');
    }
    return session;
  }

  /// Windows: SDK-generated authorize URL (it stores the verifier), capture
  /// the code on the loopback, then let the SDK exchange it (S-03a).
  Future<void> _desktopGitHub() async {
    final res = await _auth.getOAuthSignInUrl(
      provider: OAuthProvider.github,
      redirectTo: AuthConfig.desktopRedirect,
    );
    final code = await DesktopLoopback.capture(authorizeUrl: Uri.parse(res.url));
    await _auth.exchangeCodeForSession(code);
  }

  /// Android: the deep link returns to the app; supabase_flutter exchanges the
  /// code and emits signedIn.
  Future<void> _mobileGitHub() async {
    final signedIn = _auth.onAuthStateChange
        .firstWhere((s) => s.event == AuthChangeEvent.signedIn)
        .timeout(AuthConfig.oauthTimeout);
    final launched = await _auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: AuthConfig.mobileRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const AuthFailure(AuthFailureKind.other, 'Could not open the browser.');
    }
    await signedIn;
  }

  @override
  Future<AuthSession?> currentSession() async {
    if (!isConfigured) return null;
    // In-memory/secure-storage cache only; no network (LF-INV-SEC-002).
    return _toSession(_auth.currentSession);
  }

  @override
  Future<void> signOut() async {
    if (!isConfigured) return;
    _signingOut = true; // our own sign-out is not a revocation
    try {
      await _auth.signOut();
    } catch (_) {
      // Offline: the server could not be told, but the device must forget the
      // session anyway so a restart is signed out.
      await const SecureSessionStorage().removePersistedSession();
    } finally {
      // Let the signedOut event of this call pass before re-arming.
      await Future<void>.delayed(Duration.zero);
      _signingOut = false;
    }
  }

  AuthSession? _toSession(Session? s) {
    if (s == null) return null;
    final provider = s.user.appMetadata['provider'] as String? ?? 'email';
    return AuthSession(
      accountId: s.user.id,
      provider: provider == 'github' ? 'github' : 'email',
      issuedAt: Instant.now(),
    );
  }

  AuthFailure _fromAuthException(AuthException e) {
    final code = e.code ?? '';
    if (code == 'invalid_credentials' || e.statusCode == '400') {
      return const AuthFailure(
          AuthFailureKind.invalidCredentials, 'The email or password is incorrect.');
    }
    if (code == 'email_not_confirmed') {
      return const AuthFailure(AuthFailureKind.invalidCredentials,
          'Please confirm your email address first.');
    }
    // e.message comes from the provider and never contains a token.
    return AuthFailure(AuthFailureKind.other, e.message);
  }
}
