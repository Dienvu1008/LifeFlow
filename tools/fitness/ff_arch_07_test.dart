// Self-test of the FF-ARCH-07 rules (run: dart run tools/fitness/ff_arch_07_test.dart).
// Each case must give the expected verdict; any mismatch exits 1.
import 'dart:io';

import 'ff_arch_07_licenses.dart';

void main() {
  var failed = 0;
  void expect(String name, List<String> problems, {required bool pass, String? mentions}) {
    final ok = problems.isEmpty == pass && (mentions == null || problems.any((p) => p.contains(mentions)));
    if (!ok) {
      failed++;
      stderr.writeln('FAIL $name: $problems');
    } else {
      print('ok   $name');
    }
  }

  const desugar = 'gradle:com.android.tools:desugar_jdk_libs';
  final notices = exceptions.values.first.notices.toSet();
  bool all(String p) => notices.contains(p);
  bool none(String p) => false;

  expect('accepted licenses pass',
      check(shipped: {'pub:a': '1.0.0', 'pub:b': '2.0.0'}, inventory: [Entry('pub:a', '1.0.0', 'MIT'), Entry('pub:b', '2.0.0', 'BSD-3-Clause')], exists: none),
      pass: true);
  expect('a package missing from the inventory fails',
      check(shipped: {'pub:a': '1.0.0', 'pub:new': '0.1.0'}, inventory: [Entry('pub:a', '1.0.0', 'MIT')], exists: none),
      pass: false, mentions: 'pub:new');
  expect('an upgrade without review fails',
      check(shipped: {'pub:a': '1.1.0'}, inventory: [Entry('pub:a', '1.0.0', 'MIT')], exists: none),
      pass: false, mentions: 'review');
  expect('AGPL fails',
      check(shipped: {'pub:x': '1.0.0'}, inventory: [Entry('pub:x', '1.0.0', 'AGPL-3.0-only')], exists: none),
      pass: false, mentions: 'not accepted');
  expect('plain GPL fails',
      check(shipped: {'pub:x': '1.0.0'}, inventory: [Entry('pub:x', '1.0.0', 'GPL-2.0-only')], exists: none),
      pass: false, mentions: 'not accepted');
  expect('the exception is only for its own package',
      check(shipped: {'pub:x': '1.0.0'}, inventory: [Entry('pub:x', '1.0.0', 'GPL-2.0-only WITH Classpath-exception-2.0')], exists: all),
      pass: false, mentions: 'not granted');
  expect('the exception needs its notice files',
      check(shipped: {desugar: '2.1.4'}, inventory: [Entry(desugar, '2.1.4', 'GPL-2.0-only WITH Classpath-exception-2.0')], exists: none),
      pass: false, mentions: 'notice file missing');
  expect('the exception with its notices passes',
      check(shipped: {desugar: '2.1.4'}, inventory: [Entry(desugar, '2.1.4', 'GPL-2.0-only WITH Classpath-exception-2.0')], exists: all),
      pass: true);
  expect('lock parsing skips path and sdk packages', [
    if (lockedPackages('''
packages:
  drift:
    dependency: "direct main"
    description:
      name: drift
    source: hosted
    version: "2.35.3"
  ui:
    dependency: "direct main"
    description:
      path: "../../packages/ui"
    source: path
    version: "0.0.1"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
sdks:
  dart: ">=3.9.0 <4.0.0"
''').toString() != '{pub:drift: 2.35.3}')
      'parsed wrong',
  ], pass: true);
  expect('gradle parsing', [
    if (gradleLibraries('dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}').toString() !=
        '{gradle:com.android.tools:desugar_jdk_libs: 2.1.4}')
      'parsed wrong',
  ], pass: true);
  expect('license guesses', [
    if (guessLicense('Permission is hereby granted, free of charge, to any person') != 'MIT') 'MIT',
    if (guessLicense('Redistribution and use in source and binary forms ... Neither the name of') != 'BSD-3-Clause') 'BSD-3',
    if (guessLicense('Redistribution and use in source and binary forms, with or without') != 'BSD-2-Clause') 'BSD-2',
    if (guessLicense('Apache License\nVersion 2.0, January 2004') != 'Apache-2.0') 'Apache',
    if (guessLicense('GNU AFFERO GENERAL PUBLIC LICENSE') != null) 'AGPL must not be guessed as accepted',
  ], pass: true);

  if (failed > 0) {
    stderr.writeln('FF-ARCH-07 self-test: $failed failed');
    exit(1);
  }
  print('FF-ARCH-07 self-test OK');
}
