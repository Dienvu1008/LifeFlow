import 'package:foundation/foundation.dart';

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

/// The only port that talks to the identity provider (Supabase Auth, ADR-0003).
///
/// LF-INV-SEC-002: the gateway is called ONLY for sign-in, session read and
/// sign-out — never on the data read path. An auth failure or offline state
/// must never block access to the active profile's local data. Implementations
/// read the cached session from secure storage so [currentSession] works
/// offline without any network call.
abstract interface class AuthGateway {
  /// Interactive sign-in via the given provider (OAuth loopback for GitHub,
  /// email for the baseline). Returns the session or throws on failure.
  Future<AuthSession> signIn(String provider);

  /// The cached session, read from secure storage. MUST NOT hit the network:
  /// returns the last session if present, else null. Safe offline / airplane
  /// mode (LF-INV-SEC-002).
  Future<AuthSession?> currentSession();

  /// Clear the cached session. Local profiles and their data are untouched
  /// (OQ-S7: sign-out returns to the profile chooser, nothing is deleted).
  Future<void> signOut();
}
