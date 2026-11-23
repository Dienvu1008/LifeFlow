// ADR-0035: the desugar_jdk_libs notices ship with the app and are listed
// with the other open-source licenses.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeflow_app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Each test registers once (the registry keeps what was added before).
  setUp(LicenseRegistry.reset);

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

  test('ADR-0078: the C++/WinRT notice (MIT, compiled into the Windows TTS plugin) is registered', () async {
    registerBundledLicenses();
    final entries = await LicenseRegistry.licenses.where((e) => e.packages.contains(cppwinrtPackageName)).toList();
    expect(entries, hasLength(1));
    final text = entries.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('Microsoft.Windows.CppWinRT 2.0.210503.1'));
    expect(text, contains('Copyright (c) Microsoft Corporation.'));
    expect(text, contains('Permission is hereby granted, free of charge'));
  });

  test('ADR-0075: the PDFium notices are registered, each in full, with the FTL and IJG credits', () async {
    registerBundledLicenses();
    final entries = await LicenseRegistry.licenses.where((e) => e.packages.contains(pdfiumPackageName)).toList();
    final source = await rootBundle.loadString('assets/licenses/pdfium/SOURCE');
    final files = pdfiumNoticeFiles(source);
    expect(files, hasLength(21));
    // The credits, then one entry per notice.
    expect(entries, hasLength(1 + files.length));
    String textOf(LicenseEntry e) => e.paragraphs.map((p) => p.text).join('\n');
    final first = textOf(entries.first);
    for (final c in pdfiumCredits) {
      expect(first, contains(c));
    }
    expect(first, contains('https://github.com/bblanchon/pdfium-binaries/releases/tag/chromium/8125'));
    final all = entries.skip(1).map(textOf).join('\n');
    expect(all, contains('The FreeType Project LICENSE'));
    // freetype.txt is Latin-1: its "©" is read as such, not as a broken byte.
    expect(all, contains('Portions of this software are copyright © <year> The FreeType'));
    expect(all, contains('Independent JPEG Group'));
    expect(all, contains('UNICODE LICENSE V3'));
    expect(all, contains('Anti-Grain Geometry'));
    expect(all, contains('The LLVM Project is under the Apache License v2.0 with LLVM Exceptions'));
  });
}
