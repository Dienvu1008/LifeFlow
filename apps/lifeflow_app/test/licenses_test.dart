// ADR-0035: the desugar_jdk_libs notices ship with the app and are listed
// with the other open-source licenses.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeflow_app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the GPL-2.0 + Classpath Exception notices are registered in full', () async {
    registerBundledLicenses();
    final entries = await LicenseRegistry.licenses.where((e) => e.packages.contains(desugarPackageName)).toList();
    expect(entries, hasLength(1));
    final text = entries.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('The GNU General Public License (GPL)'));
    expect(text, contains('Version 2, June 1991'));
    expect(text, contains('"CLASSPATH" EXCEPTION TO THE GPL'));
    expect(text, contains('OPENJDK ASSEMBLY EXCEPTION'));
    expect(text, contains('ADDITIONAL INFORMATION ABOUT LICENSING'));
    expect(text, contains('https://github.com/google/desugar_jdk_libs/tree/'));
  });
}
