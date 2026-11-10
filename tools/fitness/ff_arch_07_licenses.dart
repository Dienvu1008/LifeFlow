// FF-ARCH-07: license scan (ADR-0018, ADR-0035, risk R-LICENSE-SCAN).
//
// Every package the app ships (apps/lifeflow_app/pubspec.lock, hosted and git
// sources) and every Android library declared in the app's Gradle file must be
// listed in tools/fitness/license_inventory.txt with its exact version and an
// SPDX license id. The scan fails when:
//   - a locked package or Gradle library is missing, or listed with another
//     version (an upgrade must be reviewed);
//   - a listed license is not accepted by ADR-0018;
//   - a recorded exception (ADR-0035) is used by another package, or its
//     notice files are missing from the app.
//
// Run: dart run tools/fitness/ff_arch_07_licenses.dart
//      dart run tools/fitness/ff_arch_07_licenses.dart --detect
// --detect only suggests inventory lines for missing packages, from the
// LICENSE files in the local pub cache. A human reviews them before adding.
import 'dart:io';

const lockFile = 'apps/lifeflow_app/pubspec.lock';
const gradleFile = 'apps/lifeflow_app/android/app/build.gradle.kts';
const inventoryFile = 'tools/fitness/license_inventory.txt';

/// ADR-0018 rule 2 (exactly; anything else needs a decision first).
const accepted = {'MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'MPL-2.0'};

/// ADR-0035: exceptions, each only for the named entry, with the notice files
/// the app must ship.
const exceptions = {
  'GPL-2.0-only WITH Classpath-exception-2.0': (
    only: {'gradle:com.android.tools:desugar_jdk_libs'},
    notices: [
      'apps/lifeflow_app/assets/licenses/desugar_jdk_libs/LICENSE',
      'apps/lifeflow_app/assets/licenses/desugar_jdk_libs/ASSEMBLY_EXCEPTION',
      'apps/lifeflow_app/assets/licenses/desugar_jdk_libs/ADDITIONAL_LICENSE_INFO',
    ],
  ),
};

class Entry {
  Entry(this.key, this.version, this.license);
  final String key; // pub:<name> | gradle:<group>:<artifact>
  final String version;
  final String license;
}

/// Hosted and git packages of the lock file: name -> version.
Map<String, String> lockedPackages(String text) {
  final out = <String, String>{};
  String? name;
  String? version;
  String? source;
  void flush() {
    if (name != null && version != null && (source == 'hosted' || source == 'git')) out['pub:$name'] = version;
  }

  for (final line in text.split('\n')) {
    final pkg = RegExp(r'^  ([a-z0-9_]+):\s*$').firstMatch(line);
    if (pkg != null) {
      flush();
      name = pkg[1];
      version = null;
      source = null;
      continue;
    }
    if (line.startsWith('sdks:')) break;
    final v = RegExp(r'^    version: "([^"]+)"').firstMatch(line);
    if (v != null) version = v[1];
    final s = RegExp(r'^    source: (\w+)').firstMatch(line);
    if (s != null) source = s[1];
  }
  flush();
  return out;
}

/// `implementation("g:a:v")`-style Android libraries: key -> version.
Map<String, String> gradleLibraries(String text) => {
      for (final m in RegExp(r'''(?:implementation|api|coreLibraryDesugaring)\(\s*"([^":]+):([^":]+):([^"]+)"\s*\)''')
          .allMatches(text))
        'gradle:${m[1]}:${m[2]}': m[3]!,
    };

List<Entry> readInventory(String text) => [
      for (final raw in text.split('\n'))
        if (raw.trim().isNotEmpty && !raw.trimLeft().startsWith('#'))
          () {
            // <key> <version> <license...>   (license may contain spaces)
            final parts = raw.trim().split(RegExp(r'\s+'));
            if (parts.length < 3) throw FormatException('bad inventory line: $raw');
            return Entry(parts[0], parts[1], parts.sublist(2).join(' '));
          }(),
    ];

/// Problems found (empty = pass).
List<String> check({
  required Map<String, String> shipped,
  required List<Entry> inventory,
  required bool Function(String path) exists,
}) {
  final problems = <String>[];
  final byKey = {for (final e in inventory) e.key: e};
  for (final MapEntry(:key, value: version) in shipped.entries) {
    final e = byKey[key];
    if (e == null) {
      problems.add('$key $version is not in $inventoryFile (record its license first, ADR-0018 rule 6)');
    } else if (e.version != version) {
      problems.add('$key is $version but the inventory says ${e.version} (review the license of the new version)');
    }
  }
  for (final e in inventory) {
    if (accepted.contains(e.license)) continue;
    final x = exceptions[e.license];
    if (x == null) {
      problems.add('${e.key}: license "${e.license}" is not accepted by ADR-0018');
    } else if (!x.only.contains(e.key)) {
      problems.add('${e.key}: the exception "${e.license}" (ADR-0035) is not granted to this package');
    } else if (shipped.containsKey(e.key)) {
      for (final n in x.notices) {
        if (!exists(n)) problems.add('${e.key}: notice file missing: $n (ADR-0035)');
      }
    }
  }
  return problems;
}

/// A guess from a LICENSE text, or null.
String? guessLicense(String t) {
  final s = t.toLowerCase();
  if (s.contains('apache license') && s.contains('version 2.0')) return 'Apache-2.0';
  if (s.contains('mozilla public license') && s.contains('2.0')) return 'MPL-2.0';
  if (s.contains('permission is hereby granted, free of charge')) return 'MIT';
  if (s.contains('redistribution and use in source and binary forms')) {
    return s.contains('neither the name') || s.contains('may be used to endorse') ? 'BSD-3-Clause' : 'BSD-2-Clause';
  }
  if (s.contains('this software is provided \'as-is\'') && s.contains('altered source versions')) return 'Zlib';
  if (s.contains('permission to use, copy, modify, and/or distribute this software')) return 'ISC';
  return null;
}

String pubCache() {
  final env = Platform.environment;
  if (env['PUB_CACHE'] != null) return env['PUB_CACHE']!;
  if (Platform.isWindows) return '${env['LOCALAPPDATA']}\\Pub\\Cache';
  return '${env['HOME']}/.pub-cache';
}

void main(List<String> args) {
  final shipped = {
    ...lockedPackages(File(lockFile).readAsStringSync()),
    ...gradleLibraries(File(gradleFile).readAsStringSync()),
  };
  final inventoryText = File(inventoryFile).existsSync() ? File(inventoryFile).readAsStringSync() : '';
  final inventory = readInventory(inventoryText);

  if (args.contains('--detect')) {
    final known = {for (final e in inventory) e.key: e.version};
    for (final MapEntry(:key, value: version) in shipped.entries) {
      if (known[key] == version) continue;
      if (!key.startsWith('pub:')) {
        print('$key $version ?  # Gradle: check the license by hand');
        continue;
      }
      final name = key.substring(4);
      final dir = Directory('${pubCache()}${Platform.pathSeparator}hosted${Platform.pathSeparator}pub.dev'
          '${Platform.pathSeparator}$name-$version');
      final lic = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING']
          .map((f) => File('${dir.path}${Platform.pathSeparator}$f'))
          .where((f) => f.existsSync())
          .firstOrNull;
      final guess = lic == null ? null : guessLicense(lic.readAsStringSync());
      print('$key $version ${guess ?? '?'}${guess == null ? '  # no recognised LICENSE: check by hand' : ''}');
    }
    return;
  }

  final problems = check(shipped: shipped, inventory: inventory, exists: (p) => File(p).existsSync());
  if (problems.isNotEmpty) {
    stderr.writeln('FF-ARCH-07 FAILED:');
    for (final p in problems) {
      stderr.writeln('  - $p');
    }
    exit(1);
  }
  print('FF-ARCH-07 OK: ${shipped.length} shipped packages and libraries, all with accepted licenses');
}
