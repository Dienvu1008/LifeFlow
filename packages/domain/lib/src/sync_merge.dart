// P04 T3 (ADR-0015, ADR-0052 §4, p04-plan.md D6/D7; spike S-04): merging a
// record changed on this device and on the server since they last agreed.
// A pure function of three copies of the record as JSON: the last synced one
// (base, null when both sides made the record), this device's and the
// server's. Never a global last-writer-wins (LF-INV-SYNC-003): each kind has
// its rule, and where a value gives way it is kept as a review item ("Changes
// to review", D9), never dropped.

/// Bookkeeping columns of every record, not content.
/// P04b (v13): `changedBy`, who changed it last in a shared space, follows the
/// newer side.
const syncMetaFields = {
  'id', 'workspaceId', 'ownerId', 'version', 'createdAt', 'updatedAt', 'deletedAt', 'deletedBy', 'changedBy',
};

/// A value that gave way in a merge, kept for the user to look at.
class SyncReview {
  const SyncReview({required this.field, required this.kept, required this.other, required this.reason});

  /// The field, '*' for a whole record, 'deletedAt' for a delete against an edit.
  final String field;
  final Object? kept;
  final Object? other;
  final SyncReviewReason reason;
}

enum SyncReviewReason {
  /// Both devices changed it; the newer change was kept.
  changedOnBoth,

  /// Deleted on one device, edited on the other: deleted, the edits kept.
  deletedAndEdited,
}

class SyncMerge {
  const SyncMerge(this.row, this.reviews);

  /// The merged record, its version above both sides'.
  final Map<String, dynamic> row;
  final List<SyncReview> reviews;
}

/// A task's status never moves down in a merge: a completion is not lost.
const _statusRank = ['inbox', 'todo', 'inProgress', 'cancelled', 'done'];

/// Kinds whose content is one value: merging halves of it is unsafe.
const _wholeValueKinds = {'schedule', 'reminder', 'exception', 'periodResult', 'focusSession', 'workspaceSettings'};

/// Kinds that are never changed after they are made (append-only, EXEC-001):
/// the same id on both sides is the same fact, so either copy will do.
/// P05a T4 (ADR-0069): a document's revisions are written once (DOC-006).
const _appendOnlyKinds = {'measurement', 'executionRecord', 'documentRevision'};

/// Fields that are one value with a review when both sides changed them.
/// P05a T4 (ADR-0069): a document's body changed on both sides: the newer
/// stays and the other is a review item. Nothing is lost either way: each
/// side's save is a revision of its own, and revisions sync append-only.
const _reviewedFields = {'task': {'notes'}, 'document': {'body'}};

SyncMerge mergeRecord(
  String kind,
  Map<String, dynamic>? base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote, {
  required String localDevice,
  required String remoteDevice,
}) {
  final reviews = <SyncReview>[];
  final localWins = _localWins(local, remote, localDevice, remoteDevice);
  final newer = localWins ? local : remote;
  final older = localWins ? remote : local;
  final top = _int(local['version']) > _int(remote['version']) ? _int(local['version']) : _int(remote['version']);
  final updated = _int(local['updatedAt']) > _int(remote['updatedAt']) ? local['updatedAt'] : remote['updatedAt'];

  bool changed(Map<String, dynamic> side, String f) => base == null || !_same(side[f], base[f]);
  Iterable<String> contentFields() => {...local.keys, ...remote.keys}.where((f) => !syncMetaFields.contains(f));
  bool contentChanged(Map<String, dynamic> side) => contentFields().any((f) => changed(side, f));

  final ld = local['deletedAt'], rd = remote['deletedAt'];

  // An occurrence tick: its tombstone means "not done"; done wins.
  if (kind == 'completion') {
    final keep = ld == null ? local : (rd == null ? remote : newer);
    return SyncMerge({...keep, 'version': top + 1, 'updatedAt': updated}, reviews);
  }

  if (_appendOnlyKinds.contains(kind)) {
    // Only a delete can differ (a trashed record): the delete wins.
    final keep = ld != null ? local : (rd != null ? remote : newer);
    return SyncMerge({...keep, 'version': top + 1, 'updatedAt': updated}, reviews);
  }

  if (_wholeValueKinds.contains(kind)) {
    if (contentChanged(local) && contentChanged(remote) && !_same(_content(local), _content(remote))) {
      reviews.add(SyncReview(
          field: '*', kept: _content(newer), other: _content(older), reason: SyncReviewReason.changedOnBoth));
    }
    final row = {...newer};
    if ((ld == null) != (rd == null)) {
      final del = ld != null ? local : remote;
      row
        ..['deletedAt'] = del['deletedAt']
        ..['deletedBy'] = del['deletedBy'];
    }
    return SyncMerge({...row, 'version': top + 1, 'updatedAt': updated}, reviews);
  }

  // Field by field: tasks, lists, events, calendars, goals, milestones, links.
  final out = <String, dynamic>{...remote};
  final reviewed = _reviewedFields[kind] ?? const <String>{};
  for (final f in contentFields()) {
    final lv = local[f], rv = remote[f];
    if (_same(lv, rv)) {
      out[f] = lv;
    } else if (!changed(local, f)) {
      out[f] = rv;
    } else if (!changed(remote, f)) {
      out[f] = lv;
    } else if (kind == 'task' && f == 'status' && lv is String && rv is String) {
      out[f] = _rank(lv) >= _rank(rv) ? lv : rv;
    } else {
      out[f] = newer[f];
      if (reviewed.contains(f)) {
        reviews.add(SyncReview(field: f, kept: newer[f], other: older[f], reason: SyncReviewReason.changedOnBoth));
      }
    }
  }
  // Deletion is a field too: a side that did not change it gives way. When
  // both changed it, a delete beats a restore. A delete against an edit:
  // deleted, the edits stay on the record in the trash, with a review (D7).
  final Map<String, dynamic> del;
  if (_same(ld, rd) || !changed(local, 'deletedAt')) {
    del = remote;
  } else if (!changed(remote, 'deletedAt')) {
    del = local;
  } else if ((ld == null) != (rd == null)) {
    del = ld != null ? local : remote;
  } else {
    del = newer;
  }
  out
    ..['deletedAt'] = del['deletedAt']
    ..['deletedBy'] = del['deletedBy'];
  final deletedHere = ld != null && changed(local, 'deletedAt');
  final deletedThere = rd != null && changed(remote, 'deletedAt');
  if (out['deletedAt'] != null && deletedHere != deletedThere && contentChanged(deletedHere ? remote : local)) {
    reviews.add(const SyncReview(
        field: 'deletedAt', kept: 'deleted', other: 'edited', reason: SyncReviewReason.deletedAndEdited));
  }
  out
    ..['updatedAt'] = updated
    ..['version'] = top + 1;
  // Who changed it last: the newer side (absent in records before v13).
  if (local.containsKey('changedBy') || remote.containsKey('changedBy')) out['changedBy'] = newer['changedBy'];
  return SyncMerge(out, reviews);
}

/// Which side is newer when both changed the same thing: the higher version,
/// then the later update, then the device name, so every device agrees.
bool _localWins(Map<String, dynamic> local, Map<String, dynamic> remote, String localDevice, String remoteDevice) {
  final lv = _int(local['version']), rv = _int(remote['version']);
  if (lv != rv) return lv > rv;
  final lu = _int(local['updatedAt']), ru = _int(remote['updatedAt']);
  if (lu != ru) return lu > ru;
  return localDevice.compareTo(remoteDevice) > 0;
}

int _rank(String status) => _statusRank.indexOf(status);
int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

Map<String, dynamic> _content(Map<String, dynamic> r) => {
      for (final e in r.entries)
        if (!syncMetaFields.contains(e.key)) e.key: e.value
    };

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
