// P03 UX U2 (ADR-0046): fractional order keys. Keys compare as strings; a
// key between two keys is strictly between them; appending keeps keys short;
// random insertions stay ordered and well-formed (R-DATA-LOSS).
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('the first key, and keys before and after it', () {
    expect(orderKeyBetween(null, null), firstOrderKey);
    final after = orderKeyBetween(firstOrderKey, null);
    final before = orderKeyBetween(null, firstOrderKey);
    expect(after, 'a1');
    expect(before, 'Zz');
    expect(before.compareTo(firstOrderKey) < 0, isTrue);
    expect(after.compareTo(firstOrderKey) > 0, isTrue);
  });

  test('a key between two keys is strictly between them', () {
    expect(orderKeyBetween('a0', 'a1'), 'a0V');
    expect(orderKeyBetween('a0', 'a0V'), 'a0G');
    expect(orderKeyBetween('a0V', 'a1'), 'a0l');
    expect(orderKeyBetween('Zz', 'a0'), 'ZzV');
    expect(orderKeyBetween('a1', 'a2'), 'a1V');
  });

  test('integer parts roll over: az -> b00, Z0 -> Yzz', () {
    expect(orderKeyBetween('az', null), 'b00');
    expect(orderKeyBetween('b00', null), 'b01');
    expect(orderKeyBetween(null, 'Z0'), 'Yzz');
  });

  test('appending 10 000 items keeps keys short and increasing', () {
    final keys = orderKeysAfter(null, 10000);
    for (var i = 1; i < keys.length; i++) {
      expect(keys[i].compareTo(keys[i - 1]) > 0, isTrue, reason: '${keys[i - 1]} !< ${keys[i]}');
    }
    expect(keys.map((k) => k.length).reduce(max), lessThanOrEqualTo(4));
  });

  test('prepending 2 000 items keeps keys short and decreasing', () {
    var k = firstOrderKey;
    for (var i = 0; i < 2000; i++) {
      final n = orderKeyBetween(null, k);
      expect(n.compareTo(k) < 0, isTrue);
      k = n;
    }
    expect(k.length, lessThanOrEqualTo(4));
  });

  test('malformed keys and a reversed range are refused', () {
    for (final bad in ['', 'a', 'a00', 'a0 ', '!0', 'A00000000000000000000000000', 'b0']) {
      expect(isValidOrderKey(bad), isFalse, reason: bad);
      expect(() => orderKeyBetween(bad, null), throwsA(isA<InvalidOrderKey>()), reason: bad);
    }
    for (final good in ['a0', 'a0V', 'Zz', 'b00', 'zzzzzzzzzzzzzzzzzzzzzzzzzzz']) {
      expect(isValidOrderKey(good), isTrue, reason: good);
    }
    expect(() => orderKeyBetween('a1', 'a0'), throwsArgumentError);
    expect(() => orderKeyBetween('a1', 'a1'), throwsArgumentError);
  });

  test('property: 3 000 random insertions keep a strict order of valid keys', () {
    final rnd = Random(20261112);
    final keys = <String>[];
    for (var i = 0; i < 3000; i++) {
      final at = keys.isEmpty ? null : (rnd.nextInt(keys.length + 1) - 1);
      final k = orderKeyAfterIndex(keys, at == -1 ? null : at);
      final pos = at == null || at == -1 ? 0 : at + 1;
      keys.insert(pos, k);
      expect(isValidOrderKey(k), isTrue, reason: k);
    }
    for (var i = 1; i < keys.length; i++) {
      expect(keys[i].compareTo(keys[i - 1]) > 0, isTrue, reason: '${keys[i - 1]} !< ${keys[i]}');
    }
    // Random positions grow keys only logarithmically.
    expect(keys.map((k) => k.length).reduce(max), lessThan(30));
  });

  test('property: repeated drops into the same gap stay ordered', () {
    var lo = 'a0';
    const hi = 'a1';
    for (var i = 0; i < 500; i++) {
      final k = orderKeyBetween(lo, hi);
      expect(k.compareTo(lo) > 0 && k.compareTo(hi) < 0, isTrue);
      lo = k;
    }
  });

  test('a drop after tied keys goes after all of them', () {
    // Two devices wrote the same key: [a0, a1, a1, a2]; drop after index 1.
    final k = orderKeyAfterIndex(['a0', 'a1', 'a1', 'a2'], 1);
    expect(k.compareTo('a1') > 0 && k.compareTo('a2') < 0, isTrue);
    // At the top, and after the last one.
    expect(orderKeyAfterIndex(['a0'], null).compareTo('a0') < 0, isTrue);
    expect(orderKeyAfterIndex(['a0', 'a0'], 0).compareTo('a0') > 0, isTrue);
  });

  test('item colours: 12 indexes or none', () {
    expect(itemColorCount, 12);
    expect(itemColorError(null), isNull);
    expect(itemColorError(0), isNull);
    expect(itemColorError(11), isNull);
    expect(itemColorError(12), isNotNull);
    expect(itemColorError(-1), isNotNull);
  });
}
