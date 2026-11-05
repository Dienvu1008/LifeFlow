// P01 T5 — at-rest encryption self-check (ADR-0021, LF-INV-SEC-011, GS-19).
// Headless: the warning/flag logic is pure Dart, independent of the native
// cipher build. Verifies the tracked-exception posture is NON-silent on
// Windows and that Android-encrypted produces no warning.
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

void main() {
  group('StorageSecurity.evaluate (ADR-0021)', () {
    test('Android encrypted: no warning, flag true, cipher asserted (SEC-011)',
        () async {
      final warnings = <String>[];
      final sec = StorageSecurity(
        platform: StoragePlatform.android,
        onWarning: warnings.add,
      );
      final status = await sec.evaluate(() async => 'sqlite3mc');

      expect(status.encrypted, isTrue);
      expect(status.cipher, 'sqlite3mc');
      expect(status.hasWarning, isFalse);
      expect(status.isTrackedException, isFalse);
      expect(warnings, isEmpty);
      expect(status.toDiagnostics()['atRestEncrypted'], isTrue);
    });

    test('Windows plain: NON-silent tracked exception (warn + flag false)',
        () async {
      final warnings = <String>[];
      final sec = StorageSecurity(
        platform: StoragePlatform.windows,
        onWarning: warnings.add,
      );
      final status = await sec.evaluate(() async => null); // plain DB

      expect(status.encrypted, isFalse);
      expect(status.cipher, isNull);
      expect(status.isTrackedException, isTrue); // sanctioned, ADR-0021
      expect(status.hasWarning, isTrue);
      // Non-silent: the warning was emitted to the sink exactly once.
      expect(warnings.length, 1);
      expect(warnings.single, contains('Windows'));
      expect(warnings.single, contains('BitLocker'));
      // Diagnostics record the exception explicitly (not a silent downgrade).
      final diag = status.toDiagnostics();
      expect(diag['atRestEncrypted'], isFalse);
      expect(diag['trackedException'], isTrue);
      expect(diag['warning'], isNotNull);
    });

    test('non-Windows plain is a policy VIOLATION, not a tracked exception',
        () async {
      final warnings = <String>[];
      final sec = StorageSecurity(
        platform: StoragePlatform.android,
        onWarning: warnings.add,
      );
      final status = await sec.evaluate(() async => null);

      expect(status.encrypted, isFalse);
      expect(status.isTrackedException, isFalse); // NOT sanctioned on Android
      expect(status.hasWarning, isTrue);
      expect(status.warning, contains('NOT an accepted'));
      expect(warnings.length, 1);
    });

    test('empty cipher string is treated as not encrypted', () async {
      final sec = StorageSecurity(platform: StoragePlatform.windows);
      final status = await sec.evaluate(() async => '');
      expect(status.encrypted, isFalse);
    });
  });

  group('AppDatabase.activeCipher() on a plain build', () {
    test('a plain in-memory DB reports no cipher (null)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // The bundled sqlite in tests is plain; PRAGMA cipher yields nothing.
      final cipher = await db.activeCipher();
      expect(cipher, isNull);

      // Wiring it through StorageSecurity on Windows -> tracked exception.
      final warnings = <String>[];
      final status =
          await StorageSecurity(platform: StoragePlatform.windows, onWarning: warnings.add)
              .evaluate(db.activeCipher);
      expect(status.encrypted, isFalse);
      expect(status.isTrackedException, isTrue);
      expect(warnings, isNotEmpty);
    });
  });
}
