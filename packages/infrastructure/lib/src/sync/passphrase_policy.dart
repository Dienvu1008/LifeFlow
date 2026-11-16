// P04 T1b (p04-plan.md D15, owner 2026-11-14): the minimum for a sync
// passphrase: at least 12 characters, and not a common password, also not
// one with digits or symbols added at either end ("password2024!"). It is
// stretched with Argon2id (sealing.dart), so length matters more than
// symbols.
import 'common_passwords.dart';

const minPassphraseLength = 12;

enum PassphraseProblem { tooShort, tooCommon }

/// Null when [passphrase] may be used.
PassphraseProblem? checkPassphrase(String passphrase) {
  final p = passphrase.trim();
  if (p.runes.length < minPassphraseLength) return PassphraseProblem.tooShort;
  final lower = p.toLowerCase();
  final core = lower.replaceAll(_ends, '');
  if (commonPasswords.contains(lower) || (core.length >= 4 && commonPasswords.contains(core))) {
    return PassphraseProblem.tooCommon;
  }
  // A short piece or a common word said again and again ("aaaaaaaaaaaa",
  // "passwordpassword").
  final unit = _repeatedUnit(core.isEmpty ? lower : core);
  if (unit != null && (unit.runes.length < 4 || commonPasswords.contains(unit))) return PassphraseProblem.tooCommon;
  return null;
}

/// The shortest piece that [s] is two or more copies of, or null.
String? _repeatedUnit(String s) {
  final r = s.runes.toList();
  for (var k = 1; k <= r.length ~/ 2; k++) {
    if (r.length % k != 0) continue;
    var same = true;
    for (var i = k; i < r.length && same; i++) {
      same = r[i] == r[i % k];
    }
    if (same) return String.fromCharCodes(r.sublist(0, k));
  }
  return null;
}

/// Digits, punctuation, symbols and spaces at either end (any script's
/// letters stay, so a Vietnamese word is not cut).
final _ends = RegExp(r'^[\p{N}\p{P}\p{S}\s]+|[\p{N}\p{P}\p{S}\s]+$', unicode: true);
