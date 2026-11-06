import 'dart:async';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

/// A fake AuthGateway standing in for Supabase. The session lives in memory
/// (= "secure storage"); currentSession() never does network I/O so it is safe
/// offline. [calls] records every invocation so a test can assert the read
/// path never touched it (LF-INV-SEC-002). The secret token is kept here only,
/// never handed to persistence (LF-INV-SEC-001).
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.accountId = 'acc-123', this.isConfigured = true});

  /// The provider user id the next sign-in returns.
  String accountId;

  @override
  final bool isConfigured;

  /// When set, the next sign-in throws this instead of succeeding.
  AuthFailure? failNext;

  AuthSession? _session;
  String? _secretToken; // the thing that must never reach the DB
  final List<String> calls = [];

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    final provider = switch (request) {
      EmailPasswordSignIn() => 'email',
      OAuthSignIn(:final provider) => provider,
    };
    calls.add('signIn:$provider');
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    _secretToken = 'tok_${DateTime.now().microsecondsSinceEpoch}';
    _session = AuthSession(
        accountId: accountId, provider: provider, issuedAt: Instant.now());
    return _session!;
  }

  @override
  Future<AuthSession?> currentSession() async {
    calls.add('currentSession');
    return _session; // from cache, no network -> works offline
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _session = null;
    _secretToken = null;
  }

  String? get secretToken => _secretToken;

  final _revoked = StreamController<void>.broadcast();

  @override
  Stream<void> get sessionRevoked => _revoked.stream;

  /// Simulates the provider ending the session while online (ADR-0024).
  void revoke() {
    _session = null;
    _secretToken = null;
    _revoked.add(null);
  }
}
