// P03 UX U2 (ADR-0046): fractional order keys. Every list, task and event
// has a key; items in one container (the lists; the items in no list; the
// items of a list; the subtasks of a task) are shown by key, then by id.
// A drop computes ONE new key between its two neighbours, so a move rewrites
// one row (R-DATA-LOSS) and two devices that move different items never
// touch the same rows.
//
// The keys follow the known "fractional indexing" scheme (an integer part
// whose first character gives its length, then a fraction in base 62 with
// no trailing zero). Keys compare as plain strings (ASCII: 0-9 < A-Z < a-z).
// Appending at the end only increments the integer part, so keys stay short.

const _digits = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const _base = 62;
const _smallestInteger = 'A00000000000000000000000000';

/// The key of the first item of an empty container.
const firstOrderKey = 'a0';

class InvalidOrderKey implements Exception {
  const InvalidOrderKey(this.key);
  final String key;
  @override
  String toString() => 'InvalidOrderKey($key)';
}

int _digit(String c) {
  final i = _digits.indexOf(c);
  if (i < 0 || c.length != 1) throw const InvalidOrderKey('bad digit');
  return i;
}

int? _integerLength(String head) {
  final c = head.codeUnitAt(0);
  if (c >= 0x61 && c <= 0x7a) return c - 0x61 + 2; // a..z
  if (c >= 0x41 && c <= 0x5a) return 0x5a - c + 2; // A..Z
  return null;
}

/// Whether [key] is a well-formed order key.
bool isValidOrderKey(String key) {
  if (key.isEmpty || key == _smallestInteger) return false;
  final n = _integerLength(key[0]);
  if (n == null || key.length < n) return false;
  for (var i = 1; i < key.length; i++) {
    if (!_digits.contains(key[i])) return false;
  }
  return !(key.length > n && key.endsWith('0'));
}

void _check(String key) {
  if (!isValidOrderKey(key)) throw InvalidOrderKey(key);
}

String _integerPart(String key) => key.substring(0, _integerLength(key[0])!);

/// A fraction strictly between [a] and [b] (b == null: above all). Neither
/// has a trailing zero; '' is the lowest fraction.
String _midpoint(String a, String? b) {
  if (b != null) {
    var n = 0;
    while ((n < a.length ? a[n] : '0') == b[n]) {
      n++;
    }
    if (n > 0) return b.substring(0, n) + _midpoint(n < a.length ? a.substring(n) : '', b.substring(n));
  }
  final da = a.isEmpty ? 0 : _digit(a[0]);
  final db = b == null ? _base : _digit(b[0]);
  if (db - da > 1) return _digits[((da + db) / 2).round()];
  if (b != null && b.length > 1) return b[0];
  return _digits[da] + _midpoint(a.isEmpty ? '' : a.substring(1), null);
}

String? _increment(String integer) {
  final head = integer[0];
  final digs = integer.substring(1).split('');
  var carry = true;
  for (var i = digs.length - 1; carry && i >= 0; i--) {
    final d = _digit(digs[i]) + 1;
    if (d == _base) {
      digs[i] = '0';
    } else {
      digs[i] = _digits[d];
      carry = false;
    }
  }
  if (!carry) return head + digs.join();
  if (head == 'Z') return 'a0';
  if (head == 'z') return null;
  final h = String.fromCharCode(head.codeUnitAt(0) + 1);
  if (h.compareTo('a') > 0) {
    digs.add('0');
  } else {
    digs.removeLast();
  }
  return h + digs.join();
}

String? _decrement(String integer) {
  final head = integer[0];
  final digs = integer.substring(1).split('');
  var borrow = true;
  for (var i = digs.length - 1; borrow && i >= 0; i--) {
    final d = _digit(digs[i]) - 1;
    if (d == -1) {
      digs[i] = _digits[_base - 1];
    } else {
      digs[i] = _digits[d];
      borrow = false;
    }
  }
  if (!borrow) return head + digs.join();
  if (head == 'a') return 'Z${_digits[_base - 1]}';
  if (head == 'A') return null;
  final h = String.fromCharCode(head.codeUnitAt(0) - 1);
  if (h.compareTo('Z') < 0) {
    digs.add(_digits[_base - 1]);
  } else {
    digs.removeLast();
  }
  return h + digs.join();
}

/// A key strictly between [a] and [b]. A null [a] means "before everything",
/// a null [b] "after everything". Throws [InvalidOrderKey] for a malformed
/// key and [ArgumentError] when a >= b.
String orderKeyBetween(String? a, String? b) {
  if (a != null) _check(a);
  if (b != null) _check(b);
  if (a != null && b != null && a.compareTo(b) >= 0) {
    throw ArgumentError('$a >= $b');
  }
  if (a == null) {
    if (b == null) return firstOrderKey;
    final ib = _integerPart(b);
    final fb = b.substring(ib.length);
    if (ib == _smallestInteger) return ib + _midpoint('', fb);
    if (ib.compareTo(b) < 0) return ib;
    final d = _decrement(ib);
    if (d == null) throw ArgumentError('no key before $b');
    return d;
  }
  final ia = _integerPart(a);
  final fa = a.substring(ia.length);
  if (b == null) {
    final i = _increment(ia);
    return i ?? ia + _midpoint(fa, null);
  }
  final ib = _integerPart(b);
  final fb = b.substring(ib.length);
  if (ia == ib) return ia + _midpoint(fa, fb);
  final i = _increment(ia);
  if (i == null) throw ArgumentError('no key after $a');
  if (i.compareTo(b) < 0) return i;
  return ia + _midpoint(fa, null);
}

/// [n] increasing keys after [a] (null: from the start), for a backfill.
List<String> orderKeysAfter(String? a, int n) {
  final out = <String>[];
  var prev = a;
  for (var i = 0; i < n; i++) {
    prev = orderKeyBetween(prev, null);
    out.add(prev);
  }
  return out;
}

/// The key for an item dropped right after [after] in a container whose
/// items, in display order, have [keys] (the moved item already left out).
/// [after] null = at the top. Items with equal keys (two devices may write
/// the same key) are kept together: the drop goes after all of them.
String orderKeyAfterIndex(List<String> keys, int? after) {
  if (after == null) return orderKeyBetween(null, keys.isEmpty ? null : keys.first);
  final prev = keys[after];
  String? next;
  for (var i = after + 1; i < keys.length; i++) {
    if (keys[i].compareTo(prev) > 0) {
      next = keys[i];
      break;
    }
  }
  return orderKeyBetween(prev, next);
}
