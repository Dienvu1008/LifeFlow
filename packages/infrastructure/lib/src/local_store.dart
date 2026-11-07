// P01 T6b / T5a: opening the local store with the at-rest posture of
// ADR-0021 as amended by ADR-0022.
//
// The app links SQLite3MultipleCiphers on every platform. Whether a database
// is encrypted depends only on whether a key is applied, so one binary serves
// both postures:
//   - Default (Android and Windows): encrypted, random 256-bit key from
//     secure storage (OQ-DATA-1). An existing plain DB is encrypted in place.
//   - Windows plain fallback (explicit build flag only): plain, a tracked
//     exception (ADR-0021 option B kept as a controlled fallback).
//
// Encryption is detected from the FILE HEADER, never from `PRAGMA cipher`:
// sqlite3mc reports its configured cipher even for an unkeyed (plain) file,
// so that pragma cannot tell plain from encrypted (found in T6b).
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app_database.dart';
import 'storage_security.dart';

/// What the store should do at rest on a platform (ADR-0021).
enum AtRestPolicy { encrypt, plain }

/// ADR-0022: every platform is encrypted. [windowsPlainFallback] restores the
/// ADR-0021 plain Windows posture for a build that explicitly asks for it
/// (controlled fallback; still a visible tracked exception).
AtRestPolicy atRestPolicyFor(StoragePlatform platform,
        {bool windowsPlainFallback = false}) =>
    switch (platform) {
      StoragePlatform.windows when windowsPlainFallback => AtRestPolicy.plain,
      _ => AtRestPolicy.encrypt,
    };

/// Where the database key lives. Backed by platform secure storage in the app
/// (`flutter_secure_storage`, LF-INV-SEC-001); never the DB, files or logs.
abstract interface class DatabaseKeyStore {
  Future<String?> read();
  Future<void> write(String key);
}

/// The store could not be opened safely. Nothing was deleted or rewritten.
class StoreUnavailable implements Exception {
  const StoreUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'StoreUnavailable: $reason';
}

/// SQLite's 16-byte magic header for an unencrypted database file.
const _plainHeader = 'SQLite format 3\u0000';

/// True if [file] is an unencrypted SQLite database (or empty / missing, which
/// holds no data yet). Reads only the first 16 bytes.
bool isPlainSqliteFile(File file) {
  if (!file.existsSync()) return true;
  final raf = file.openSync();
  try {
    final head = raf.readSync(16);
    if (head.isEmpty) return true;
    return String.fromCharCodes(head) == _plainHeader;
  } finally {
    raf.closeSync();
  }
}

/// A random 256-bit key as 64 lowercase hex characters. Hex only, so it can be
/// placed in a PRAGMA literal with no quoting risk.
String generateDatabaseKey([Random? random]) {
  final r = random ?? Random.secure();
  final sb = StringBuffer();
  for (var i = 0; i < 32; i++) {
    sb.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

final _hexKey = RegExp(r'^[0-9a-f]{64}$');

String _keyPragma(String key) {
  if (!_hexKey.hasMatch(key)) {
    // Refuse anything that is not our own key format (no injection, no
    // accidental weak keys).
    throw const StoreUnavailable('database key has an unexpected format');
  }
  return "PRAGMA key = '$key'";
}

/// The opened store plus what was done to it.
class OpenedStore {
  const OpenedStore(this.db, {required this.migratedToEncrypted});
  final AppDatabase db;

  /// True when an existing plain database was encrypted in place on this
  /// launch (first launch after upgrading to an encrypting build).
  final bool migratedToEncrypted;
}

/// Opens (creating if needed) the local database at [file] with [policy].
///
/// encrypt:
///  - no key yet and no data -> generate a key, store it FIRST, then create.
///  - no key yet, plain data on disk -> generate + store key, then encrypt the
///    file in place (`PRAGMA rekey`). Idempotent if interrupted.
///  - no key but an encrypted file -> [StoreUnavailable] (the key was lost;
///    per OQ-DATA-1 the data cannot be read). The file is left untouched.
/// plain:
///  - an encrypted file on disk -> [StoreUnavailable]; never silently
///    downgrade or overwrite it.
Future<OpenedStore> openLocalStore({
  required File file,
  required AtRestPolicy policy,
  required DatabaseKeyStore keys,
  bool background = true,
}) async {
  final plainOnDisk = isPlainSqliteFile(file);
  final hasData = file.existsSync() && file.lengthSync() > 0;

  if (policy == AtRestPolicy.plain) {
    if (!plainOnDisk) {
      throw const StoreUnavailable(
          'the database on disk is encrypted but this build opens it plain');
    }
    return OpenedStore(
        AppDatabase(_executor(file, null, background: background)),
        migratedToEncrypted: false);
  }

  var key = await keys.read();
  if (key == null) {
    if (hasData && !plainOnDisk) {
      throw const StoreUnavailable(
          'the database is encrypted but its key is missing from secure storage');
    }
    key = generateDatabaseKey();
    // Persist the key before any byte is encrypted with it.
    await keys.write(key);
  }
  final pragma = _keyPragma(key);

  var migrated = false;
  if (hasData && plainOnDisk) {
    final raw = sqlite3.open(file.path);
    try {
      raw.execute("PRAGMA rekey = '$key'");
    } finally {
      raw.close();
    }
    if (isPlainSqliteFile(file)) {
      throw const StoreUnavailable('encrypting the existing database failed');
    }
    migrated = true;
  }

  return OpenedStore(
      AppDatabase(_executor(file, pragma, background: background)),
      migratedToEncrypted: migrated);
}

QueryExecutor _executor(File file, String? keyPragma,
    {required bool background}) {
  void setup(Database db) {
    if (keyPragma != null) {
      db.execute(keyPragma);
      // Fails fast with "file is not a database" on a wrong key, before Drift
      // runs migrations against it.
      db.select('SELECT count(*) FROM sqlite_master');
    }
  }

  return background
      ? NativeDatabase.createInBackground(file, setup: setup)
      : NativeDatabase(file, setup: setup);
}

/// Cipher probe for [StorageSecurity.evaluate] based on the file header.
CipherProbe fileCipherProbe(File file) =>
    () async => isPlainSqliteFile(file) ? null : 'sqlite3mc';
