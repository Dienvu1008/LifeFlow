import 'package:foundation/foundation.dart';

import 'app_services.dart';
import 'command.dart';

/// An authenticated session, cached securely so offline use continues
/// (ADR-0008, LF-INV-SEC-002). Holds identity only — the access/refresh tokens
/// never leave secure storage and are NOT part of this object (LF-INV-SEC-001).
class AuthSession {
  const AuthSession({
    required this.accountId,
    required this.provider, // 'email' | 'github'
    required this.issuedAt,
  });

  final String accountId; // opaque provider user id
  final String provider;
  final Instant issuedAt;
}

/// How the user wants to sign in (ADR-0003 / S-03a: email + GitHub).
sealed class SignInRequest {
  const SignInRequest();
}

class EmailPasswordSignIn extends SignInRequest {
  const EmailPasswordSignIn(this.email, this.password);
  final String email;
  final String password;
  // Never print the password.
  @override
  String toString() => 'EmailPasswordSignIn($email)';
}

class OAuthSignIn extends SignInRequest {
  const OAuthSignIn(this.provider);

  /// Provider name, e.g. 'github'.
  final String provider;
}

enum AuthFailureKind { notConfigured, cancelled, invalidCredentials, network, other }

/// A sign-in that did not produce a session. [message] is safe to show to the
/// user: it never contains a token or password.
class AuthFailure implements Exception {
  const AuthFailure(this.kind, this.message);
  final AuthFailureKind kind;
  final String message;
  @override
  String toString() => 'AuthFailure($kind): $message';
}

/// The only port that talks to the identity provider (Supabase Auth, ADR-0003).
///
/// LF-INV-SEC-002: called ONLY for sign-in, session read and sign-out — never
/// on the data read path. An auth failure or offline state must never block
/// access to the active profile's local data.
abstract interface class AuthGateway {
  /// Whether this build has an identity provider configured at all.
  bool get isConfigured;

  /// Interactive sign-in. Throws [AuthFailure] on failure.
  Future<AuthSession> signIn(SignInRequest request);

  /// The cached session from secure storage. MUST NOT hit the network.
  Future<AuthSession?> currentSession();

  /// Clear the cached session. Local profiles and their data are untouched
  /// (OQ-S7: sign-out returns to the profile chooser, nothing is deleted).
  Future<void> signOut();
}

/// Result of a sign-in as the UI needs it.
sealed class SignInOutcome {
  const SignInOutcome();
}

/// The account is now bound to the active profile (possibly after switching
/// to the profile that already belonged to this account).
class SignedIn extends SignInOutcome {
  const SignedIn(this.profile, {this.switchedProfile = false});
  final ProfileView profile;
  final bool switchedProfile;
}

/// The active profile already holds data: the user must choose between moving
/// it to the account and starting a separate data space (ADR-0008). Call
/// [AccountService.completeBind] or [AccountService.cancelPendingBind].
class NeedsBindChoice extends SignInOutcome {
  const NeedsBindChoice({required this.provider});
  final String provider;
}

class SignInFailed extends SignInOutcome {
  const SignInFailed(this.message, {this.kind = AuthFailureKind.other});
  final String message;
  final AuthFailureKind kind;
}

/// Account operations for the UI (ADR-0008, OQ-S7). Writes go through the
/// command gateway; the provider is reached only through [AuthGateway].
abstract interface class AccountService {
  bool get signInAvailable;

  Future<SignInOutcome> signIn(SignInRequest request);

  /// Finish a [NeedsBindChoice]: true = move the current data to the account
  /// (no id changes, LF-INV-ID-001); false = new isolated profile
  /// (LF-INV-ID-002), the guest profile stays on the device.
  Future<SignInOutcome> completeBind({required bool moveData});

  /// Abandon a [NeedsBindChoice]: the provider session is signed out, nothing
  /// is bound.
  Future<void> cancelPendingBind();

  /// Sign out of the active profile. Its data stays (OQ-S7).
  Future<CommandResult> signOut();
}
