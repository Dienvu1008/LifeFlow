import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

void main() {
  test('EntityId.generate produces distinct, stable, v7-shaped ids', () {
    final a = EntityId.generate();
    final b = EntityId.generate();
    expect(a, isNot(equals(b)));
    // UUID v7 is 36 chars with the version nibble '7'.
    expect(a.value.length, 36);
    expect(a.value[14], '7');
    // Value round-trips and equality is by value.
    expect(EntityId(a.value), equals(a));
  });

  test('LocalDate compares by value and formats ISO-like', () {
    final d = LocalDate(2026, 3, 9);
    expect(d, LocalDate(2026, 3, 9));
    expect(d.toString(), '2026-03-09');
    expect(d == LocalDate(2026, 3, 10), isFalse);
  });

  test('Result is a sealed Ok/Err', () {
    const Result<int, String> ok = Ok(1);
    const Result<int, String> err = Err('bad');
    expect(ok, isA<Ok<int, String>>());
    expect(err, isA<Err<int, String>>());
  });
}
