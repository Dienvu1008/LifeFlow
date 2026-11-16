// P04 T1b (p04-plan.md D15, ADR-0052 §5): the recovery key. 256 random
// bits, shown as 24 words of the BIP-39 English list with an 8-bit checksum
// (so a wrong or swapped word is almost always caught), and as a QR code a
// phone can scan. Before sync starts the user types two of the words back,
// so a key that was not written down is noticed (owner, 2026-11-14).
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;

import 'bip39_english.dart';

/// A recovery key; [bytes] are secret and must never be logged or stored
/// in plain text.
class RecoveryKey {
  RecoveryKey._(this.bytes);
  final Uint8List bytes;

  /// A new random key.
  factory RecoveryKey.generate([Random? random]) {
    final r = random ?? Random.secure();
    return RecoveryKey._(Uint8List.fromList([for (var i = 0; i < 32; i++) r.nextInt(256)]));
  }

  /// The 24 words, in order: 256 bits + the first 8 bits of their SHA-256,
  /// 11 bits per word.
  List<String> get words {
    final bits = StringBuffer();
    for (final b in [...bytes, hash.sha256.convert(bytes).bytes.first]) {
      bits.write(b.toRadixString(2).padLeft(8, '0'));
    }
    final s = bits.toString();
    return [for (var i = 0; i < 24; i++) bip39English[int.parse(s.substring(i * 11, i * 11 + 11), radix: 2)]];
  }

  /// What the QR code holds: upper-case words, so the code can use QR's
  /// compact alphanumeric mode.
  String get qrText => '$_qrPrefix ${words.join(' ').toUpperCase()}';

  /// From typed or pasted words, or from a scanned QR code. Case, extra
  /// spaces and line breaks do not matter.
  static RecoveryKey parse(String text) {
    var t = text.trim().toLowerCase();
    if (t.startsWith(_qrPrefix.toLowerCase())) t = t.substring(_qrPrefix.length);
    final words = t.split(RegExp(r'[\s,]+')).where((w) => w.isNotEmpty).toList();
    if (words.length != 24) throw RecoveryKeyInvalid.count(words.length);
    final bits = StringBuffer();
    for (var i = 0; i < 24; i++) {
      final n = _index[words[i]];
      if (n == null) throw RecoveryKeyInvalid.word(i + 1);
      bits.write(n.toRadixString(2).padLeft(11, '0'));
    }
    final s = bits.toString();
    final all = [for (var i = 0; i < 33; i++) int.parse(s.substring(i * 8, i * 8 + 8), radix: 2)];
    final key = Uint8List.fromList(all.sublist(0, 32));
    if (hash.sha256.convert(key).bytes.first != all[32]) throw const RecoveryKeyInvalid.checksum();
    return RecoveryKey._(key);
  }

  /// Two different word positions (1-based, in order) to ask for back.
  static (int, int) checkPositions([Random? random]) {
    final r = random ?? Random.secure();
    final a = r.nextInt(24);
    var b = r.nextInt(23);
    if (b >= a) b++;
    final (x, y) = a < b ? (a, b) : (b, a);
    return (x + 1, y + 1);
  }

  /// Whether [answers] are the words at [positions] (case and spaces aside).
  bool confirms((int, int) positions, (String, String) answers) {
    final w = words;
    String norm(String s) => s.trim().toLowerCase();
    return norm(answers.$1) == w[positions.$1 - 1] && norm(answers.$2) == w[positions.$2 - 1];
  }

  static const _qrPrefix = 'LIFEFLOW RECOVERY 1';
  static final Map<String, int> _index = {for (var i = 0; i < bip39English.length; i++) bip39English[i]: i};
}

/// Why typed words are not a recovery key; [message] is safe to show.
class RecoveryKeyInvalid implements Exception {
  const RecoveryKeyInvalid._(this.message);
  RecoveryKeyInvalid.count(int n) : this._('A recovery key has 24 words; this has $n.');
  RecoveryKeyInvalid.word(int position) : this._('Word $position is not a recovery-key word. Check its spelling.');
  const RecoveryKeyInvalid.checksum() : this._('These words are not a recovery key. Check each word.');
  final String message;
  @override
  String toString() => 'RecoveryKeyInvalid: $message';
}
