// P04 T7 (ADR-0059; data-classification.md §2): what may be synced.
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('cloud sync: Public, Personal and Confidential yes; Restricted only with consent (PRIV-001)', () {
    expect({for (final c in DataClassification.values) c: cloudSyncAllowed(c)}, {
      DataClassification.public: true,
      DataClassification.personal: true,
      DataClassification.confidential: true,
      DataClassification.restricted: false,
    });
    expect(cloudSyncAllowed(DataClassification.restricted, restrictedConsent: true), isTrue);
  });

  test('measurements typed in, counted by focus or restored are not health data', () {
    expect(personalMeasurementSources, {'manual', 'focusSession', 'import'});
  });
}
