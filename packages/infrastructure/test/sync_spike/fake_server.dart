// P04 spike S-04: an in-memory server with the semantics of
// supabase/migrations/..._sync_records.sql (spike S-03): per-record version
// check, replay of an accepted operation is a no-op, one change number per
// accepted change, pull in change-number order, purge keeps the tombstone.
import 'dart:convert';

import 'package:crypto/crypto.dart';

class ServerRecord {
  ServerRecord(this.id, this.version, this.seq, this.deleted, this.sealed, this.device, this.op);
  final String id;
  int version;
  int seq;
  bool deleted;
  String? sealed;
  String device;
  String op;
  DateTime updatedAt = DateTime.now();
}

class PushItem {
  PushItem({required this.id, required this.base, required this.version, required this.deleted, required this.sealed, required this.op});
  final String id;
  final int? base;
  final int version;
  final bool deleted;
  final String sealed;
  final String op;
}

class PushResult {
  PushResult(this.accepted, this.conflicts);
  final List<String> accepted;
  final Map<String, int?> conflicts;
}

/// The opaque server id of a local record (D12): never the local id itself.
String opaqueId(String kind, String localId) => sha256.convert(utf8.encode('$kind:$localId')).toString();

class FakeServer {
  final records = <String, ServerRecord>{};
  int lastSeq = 0;
  int pushes = 0;

  /// When set, the next push fails before anything is stored (a dropped
  /// connection): the device must retry.
  bool failNextPush = false;

  /// When set, the next push is stored but its answer is lost: the device
  /// retries the same operations (LF-INV-SYNC-001).
  bool loseNextAnswer = false;

  PushResult push(String device, List<PushItem> items) {
    pushes++;
    if (failNextPush) {
      failNextPush = false;
      throw StateError('connection lost');
    }
    final accepted = <String>[];
    final conflicts = <String, int?>{};
    for (final r in items) {
      final cur = records[r.id];
      if (cur != null && cur.op == r.op) {
        accepted.add(r.id);
        continue;
      }
      if ((cur == null && r.base == null) || (cur != null && cur.version == r.base)) {
        if (r.version <= (r.base ?? 0)) throw ArgumentError('the new version must be above the base');
        final seq = ++lastSeq;
        if (cur == null) {
          records[r.id] = ServerRecord(r.id, r.version, seq, r.deleted, r.sealed, device, r.op);
        } else {
          cur
            ..version = r.version
            ..seq = seq
            ..deleted = r.deleted
            ..sealed = r.sealed
            ..device = device
            ..op = r.op
            ..updatedAt = DateTime.now();
        }
        accepted.add(r.id);
      } else {
        conflicts[r.id] = cur?.version;
      }
    }
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw StateError('answer lost');
    }
    return PushResult(accepted, conflicts);
  }

  List<ServerRecord> pull(int after) =>
      [for (final r in records.values) if (r.seq > after) r]..sort((a, b) => a.seq.compareTo(b.seq));

  /// Purge: the content of records deleted before [before] goes; the
  /// tombstone stays with a new change number (GS-14).
  int purge(DateTime before) {
    var n = 0;
    for (final r in records.values.toList()..sort((a, b) => a.seq.compareTo(b.seq))) {
      if (r.deleted && r.sealed != null && r.updatedAt.isBefore(before)) {
        r
          ..sealed = null
          ..seq = ++lastSeq;
        n++;
      }
    }
    return n;
  }
}
