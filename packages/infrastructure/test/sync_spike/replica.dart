// P04 spike S-04: one device's side of sync, over a real profile store.
//   push  the records that pending outbox rows touched (a merged record
//         keeps its row pending, as its version is above the base), each
//         with the version it was last synced at as its base
//   pull  the server's changes in change-number order: taken as they are
//         when this device has no unsynced change to the record, otherwise
//         merged per type (resolve.dart) and pushed again on top
// Spike simplifications, for T1/T3 to replace: rows are read and written
// through the record registry directly (T3 applies them as commands of
// actor `sync` through the gateway, GOV-001); the last synced copies live in
// memory (T1: a `sync_base` table); records are not sealed (S-15).
import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:infrastructure/infrastructure.dart';

import 'e2e.dart';
import 'fake_server.dart';
import 'resolve.dart';

class Replica {
  Replica(this.name, this.db, this.server, {this.sealer});
  final String name;
  final AppDatabase db;
  final FakeServer server;

  /// End-to-end encryption (spike S-15); without it records go as plain
  /// JSON (spike S-04).
  final RecordSealer? sealer;

  /// The last synced copy of each record, by (kind, local id).
  final base = <String, Row>{};
  int cursor = 0;
  final reviews = <Review>[];


  /// Local (kind, id) of the server ids this device has seen.
  final _ids = <String, (String, String)>{};
  int purged = 0;
  int conflictsSeen = 0;

  static String _key(String kind, String id) => '$kind|$id';

  Future<Row?> _read(String kind, String id) async {
    final k = recordKindByName[kind]!;
    for (final r in await k.readAll(db)) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  Future<void> _write(String kind, Row row) async {
    final k = recordKindByName[kind]!;
    await db.batch((b) => k.upsert(b, db, [row]));
  }

  /// Push, then pull, until nothing is left to push (a conflict pulls and
  /// merges, the merge pushes again).
  Future<void> sync({int rounds = 5}) async {
    for (var i = 0; i < rounds; i++) {
      final conflicts = await push();
      await pull();
      if (conflicts == 0 && (await _pending()).isEmpty) return;
    }
    throw StateError('$name: sync did not settle');
  }

  Future<Set<(String, String)>> _pending() async {
    final rows = await db.customSelect("SELECT DISTINCT entity_type, entity_id FROM outbox WHERE status = 'pending'").get();
    return {
      for (final r in rows)
        if (recordKindByName.containsKey(r.read<String>('entity_type')))
          (r.read<String>('entity_type'), r.read<String>('entity_id')),
    };
  }

  Future<int> push() async {
    final touched = await _pending();
    if (touched.isEmpty) return 0;
    final items = <PushItem>[];
    final rows = <String, Row>{};
    for (final (kind, id) in touched) {
      final row = await _read(kind, id);
      if (row == null) continue;
      final key = _key(kind, id);
      final b = base[key];
      if (b != null && b['version'] == row['version']) continue; // already on the server
      final sid = sealer == null ? opaqueId(kind, id) : await sealer!.serverId(kind, id);
      rows[sid] = row;
      _ids[sid] = (kind, id);
      final content = {'kind': kind, 'id': id, 'row': row};
      items.add(PushItem(
        id: sid,
        base: b?['version'] as int?,
        version: row['version'] as int,
        deleted: row['deletedAt'] != null,
        sealed: sealer == null ? jsonEncode(content) : base64Encode(await sealer!.seal(sid, row['version'] as int, content)),
        // One operation per (device, record, version): a retry after a lost
        // answer is the same operation, so the server accepts it once.
        op: opaqueId('$name:$kind:${row['version']}', id),
      ));
    }
    final result = server.push(name, items);
    for (final sid in result.accepted) {
      final row = rows[sid]!;
      final kind = _ids[sid]!.$1;
      base[_key(kind, row['id'] as String)] = row;
    }
    // Outbox rows whose records are now on the server are done.
    for (final (kind, id) in touched) {
      final b = base[_key(kind, id)];
      final row = await _read(kind, id);
      if (row == null || (b != null && b['version'] == row['version'])) {
        await db.customStatement(
            "UPDATE outbox SET status = 'acked' WHERE status = 'pending' AND entity_type = ? AND entity_id = ?",
            [kind, id]);
      }
    }
    conflictsSeen += result.conflicts.length;
    return result.conflicts.length;
  }

  Future<void> pull() async {
    for (final s in server.pull(cursor)) {
      cursor = s.seq;
      if (s.sealed == null) {
        // Purged on the server: the content goes here too (GS-14).
        final known = _ids[s.id];
        if (known != null && await _read(known.$1, known.$2) != null) {
          final table = recordKindByName[known.$1]!.exportKey;
          await db.customStatement('DELETE FROM ${_sqlName(table)} WHERE id = ?', [known.$2]);
          base.remove(_key(known.$1, known.$2));
          purged++;
        }
        continue;
      }
      final env = sealer == null
          ? jsonDecode(s.sealed!) as Map<String, dynamic>
          : await sealer!.open(s.id, s.version, base64Decode(s.sealed!));
      final kind = env['kind'] as String;
      final id = env['id'] as String;
      final remote = (env['row'] as Map).cast<String, dynamic>();
      _ids[s.id] = (kind, id);
      final key = _key(kind, id);
      final b = base[key];
      if (b != null && b['version'] == remote['version'] && s.device == name) continue; // our own push
      final local = await _read(kind, id);
      if (local == null || (b != null && local['version'] == b['version'])) {
        await _write(kind, remote);
        base[key] = remote;
        continue;
      }
      if (_same(local, remote)) {
        base[key] = remote;
        continue;
      }
      // This device changed the record too: merge per type.
      final r = resolve(kind, b, local, remote, localDevice: name, remoteDevice: s.device);
      reviews.addAll(r.reviews);
      await _write(kind, r.row);
      base[key] = remote;
    }
  }

  /// Every record of the profile, by kind, without bookkeeping that differs
  /// per device (for comparing replicas).
  Future<Map<String, Map<String, Row>>> snapshot() async => {
        for (final k in recordKinds)
          k.name: {
            for (final r in await k.readAll(db)) r['id'] as String: r,
          },
      };

  Future<int> pendingOutbox() async =>
      (await db.customSelect("SELECT count(*) AS n FROM outbox WHERE status = 'pending'", variables: const <Variable>[]).getSingle())
          .read<int>('n');
}

bool _same(Row a, Row b) => jsonEncode(a) == jsonEncode(b);

/// taskLists -> task_lists (Drift's table names).
String _sqlName(String exportKey) =>
    exportKey.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
