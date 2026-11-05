// THROWAWAY spike S-03a. PKCE (RFC 7636) helper, S256 only (SR-06).
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Pkce {
  Pkce._(this.verifier, this.challenge, this.state);

  final String verifier;
  final String challenge;
  final String state;

  static String _randomUrlSafe(int bytes) {
    final rnd = Random.secure();
    final b = List<int>.generate(bytes, (_) => rnd.nextInt(256));
    return base64UrlEncode(b).replaceAll('=', '');
  }

  /// Generates a PKCE pair with method S256 (never 'plain' — SR-06).
  factory Pkce.generate() {
    final verifier = _randomUrlSafe(64); // 43..128 chars after encoding
    final digest = sha256.convert(ascii.encode(verifier));
    final challenge = base64UrlEncode(digest.bytes).replaceAll('=', '');
    final state = _randomUrlSafe(16);
    return Pkce._(verifier, challenge, state);
  }
}
