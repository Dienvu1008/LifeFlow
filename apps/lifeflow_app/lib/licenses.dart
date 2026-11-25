// ADR-0035, ADR-0075: licenses of shipped code that Flutter does not list by
// itself. Dart packages register their own LICENSE files; Android libraries
// pulled in by Gradle, and the PDFium binary that pdfrx's build hook
// downloads, do not, so their notices are bundled as assets and added here.
// They appear in Settings > Open-source licenses (showLicensePage).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:infrastructure/infrastructure.dart' show syncDataLicenses;

/// Shown as the package name on the license page.
const desugarPackageName = 'desugar_jdk_libs (Android)';

/// Shown as the package name of the PDFium notices (ADR-0075).
const pdfiumPackageName = 'PDFium (used by pdfrx)';

/// The credit lines FreeType's FTL and the IJG license ask for (ADR-0075).
const pdfiumCredits = [
  'Portions of this software are copyright © The FreeType Project (www.freetype.org). All rights reserved.',
  'This software is based in part on the work of the Independent JPEG Group.',
];

/// Shown as the package name of the C++/WinRT notice (ADR-0078).
const cppwinrtPackageName = 'C++/WinRT (Windows, used by flutter_tts)';

/// Shown as the package name of the llama.cpp runtime's notices (ADR-0084).
const llamacppPackageName = 'llama.cpp (local models, used by llamadart)';

const _dir = 'assets/licenses/desugar_jdk_libs';
const _llamacppDir = 'assets/licenses/llamacpp';
const _cppwinrtDir = 'assets/licenses/cppwinrt';
const _pdfiumDir = 'assets/licenses/pdfium';

/// The notice files SOURCE lists (`notice <file> <sha256>`), in order.
List<String> pdfiumNoticeFiles(String source) => [
      for (final l in source.split('\n'))
        if (l.trim().startsWith('notice ')) l.trim().split(RegExp(r'\s+'))[1],
    ];

/// A notice file's text: UTF-8, or Latin-1 when it is not UTF-8 (FreeType's
/// FTL is Latin-1, its "©" one byte).
String noticeText(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Adds the notices Flutter does not list by itself to the app's license
/// list. Call once at startup.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final source = await rootBundle.loadString('$_dir/SOURCE');
    final parts = [
      for (final f in ['LICENSE', 'ASSEMBLY_EXCEPTION', 'ADDITIONAL_LICENSE_INFO'])
        await rootBundle.loadString('$_dir/$f'),
    ];
    yield LicenseEntryWithLineBreaks(
      const [desugarPackageName],
      'Android core library desugaring, used unmodified by the Android build.\n'
      '${source.trim()}\n\n${parts.join('\n\n')}',
    );
  });
  // P05b T1 (ADR-0075): the PDFium binary, used as published, and the
  // libraries inside it: the credits first, then each notice unchanged.
  LicenseRegistry.addLicense(() async* {
    final source = await rootBundle.loadString('$_pdfiumDir/SOURCE');
    final release = source.split('\n').where((l) => l.startsWith('http')).firstOrNull?.trim() ?? '';
    yield LicenseEntryWithLineBreaks(
      const [pdfiumPackageName],
      'The PDF engine of the PDF viewer, used unmodified as published at $release.\n\n'
      '${pdfiumCredits.join('\n')}',
    );
    for (final f in pdfiumNoticeFiles(source)) {
      final bytes = await rootBundle.load('$_pdfiumDir/$f');
      yield LicenseEntryWithLineBreaks(const [pdfiumPackageName], noticeText(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)));
    }
  });
  // P05b T4 (ADR-0078): C++/WinRT, which flutter_tts's Windows build fetches
  // from NuGet and compiles into its plugin (MIT: its notice travels along).
  LicenseRegistry.addLicense(() async* {
    final source = await rootBundle.loadString('$_cppwinrtDir/SOURCE');
    final license = await rootBundle.loadString('$_cppwinrtDir/LICENSE');
    yield LicenseEntryWithLineBreaks(const [cppwinrtPackageName], '${source.split('\n').first.trim()}\n\n$license');
  });
  // P06 T4 (ADR-0084): the llama.cpp runtime that llamadart's build hook
  // downloads, used as published, and the code built into it.
  LicenseRegistry.addLicense(() async* {
    final source = await rootBundle.loadString('$_llamacppDir/SOURCE');
    final release = source.split('\n').where((l) => l.startsWith('http')).firstOrNull?.trim() ?? '';
    yield LicenseEntryWithLineBreaks(
      const [llamacppPackageName],
      'The runtime of the local models, used unmodified as published at $release.',
    );
    for (final f in pdfiumNoticeFiles(source)) {
      yield LicenseEntryWithLineBreaks(const [llamacppPackageName], await rootBundle.loadString('$_llamacppDir/$f'));
    }
  });
  // P04 T1b: the word lists of sync (recovery keys, the passphrase check).
  LicenseRegistry.addLicense(() async* {
    for (final (name, text) in syncDataLicenses) {
      yield LicenseEntryWithLineBreaks([name], text);
    }
  });
}
