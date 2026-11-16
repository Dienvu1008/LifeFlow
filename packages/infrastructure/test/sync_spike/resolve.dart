// P04 spike S-04: per-type conflict resolution (ADR-0015, p04-plan.md D6/D7)
// as a pure function of the last synced copy (base), this device's copy and
// the server's copy. Never a global last-writer-wins (LF-INV-SYNC-003): each
// kind has its rule, and where one side's value has to give way, the losing
// value is kept as a review item ("Changes to review", D9), never dropped.
typedef _Row = Map<String, dynamic>;

/// Columns of every record that are bookkeeping, not content.
const meta = {'id', 'workspaceId', 'ownerId', 'version', 'createdAt', 'updatedAt', 'deletedAt', 'deletedBy'};

/// A value that lost a conflict, kept for the user to look at.
class Review {
  Review(this.kind, this.id, this.field, this.kept, this.other, this.reason);
  final String kind;
  final String id;
  final String field;
  final Object? kept;
  final Object? other;
  final String reason;
  @override
  String toString() => '$kind $id $field: kept $kept, other $other ($reason)';
}

/// A task's status never moves down in a conflict: a completion is not lost.
const _statusRank = ['inbox', 'todo', 'inProgress', 'cancelled', 'done'];

/// Kinds whose content is one value: merging halves is unsafe (a schedule).
const _wholeValue = {'schedule', 'reminder', 'exception', 'periodResult', 'focusSession'};

/// Fields of a task that are one value with a review on conflict (notes, D6).
const _reviewedFields = {'notes'};

class Resolution {
  Resolution(this.row, this.reviews);
  final _Row row;
  final List<Review> reviews;
}

/// Which side is newer when both changed the same thing: the higher version,
/// then the later update, then the device name (so every device agrees).
bool _localWins(_Row local, _Row remote, String localDevice, String remoteDevice) {
  final lv = local['version'] as int, rv = remote['version'] as int;
  if (lv != rv) return lv > rv;
  final lu = local['updatedAt'] as int, ru = remote['updatedAt'] as int;
  if (lu != ru) return lu > ru;
  return localDevice.compareTo(remoteDevice) > 0;
}

Resolution resolve(
  String kind,
  _Row? base,
  _Row local,
  _Row remote, {
  required String localDevice,
  required String remoteDevice,
}) {
  final reviews = <Review>[];
  final id = local['id'] as String;
  final localWins = _localWins(local, remote, localDevice, remoteDevice);
  final newer = localWins ? local : remote;
  final older = localWins ? remote : local;
  final out = <String, dynamic>{...remote};
  final version = ((local['version'] as int) > (remote['version'] as int) ? local['version'] : remote['version']) as int;

  bool changed(_Row side, String f) => base == null || !_same(side[f], base[f]);
  bool contentChanged(_Row side) => [
        for (final f in {...local.keys, ...remote.keys})
          if (!meta.contains(f)) f
      ].any((f) => changed(side, f));

  // Deletion. A completion is never undone by a conflict (its tombstone
  // means "not done"); for everything else the delete wins and the other
  // side's edits stay on the record in the trash (D7).
  final ld = local['deletedAt'], rd = remote['deletedAt'];
  final deleted = ld != null || rd != null;

  if (kind == 'completion') {
    final keep = ld == null ? local : (rd == null ? remote : newer);
    return Resolution({...keep, 'version': version + 1}, reviews);
  }

  if (_wholeValue.contains(kind)) {
    if (contentChanged(older) && contentChanged(newer) && !_sameContent(local, remote)) {
      reviews.add(Review(kind, id, '*', _content(newer), _content(older), 'changed on both devices'));
    }
    final row = {...newer};
    if (deleted && !(ld != null && rd != null)) {
      final del = ld != null ? local : remote;
      row
        ..['deletedAt'] = del['deletedAt']
        ..['deletedBy'] = del['deletedBy'];
    }
    return Resolution({...row, 'version': version + 1}, reviews);
  }

  // Field by field (tasks, lists, events, goals, ...).
  for (final f in {...local.keys, ...remote.keys}) {
    if (meta.contains(f)) continue;
    final lv = local[f], rv = remote[f];
    if (_same(lv, rv)) {
      out[f] = lv;
    } else if (!changed(local, f)) {
      out[f] = rv;
    } else if (!changed(remote, f)) {
      out[f] = lv;
    } else if (kind == 'task' && f == 'status') {
      out[f] = _statusRank.indexOf(lv as String) >= _statusRank.indexOf(rv as String) ? lv : rv;
    } else {
      out[f] = newer[f];
      if (_reviewedFields.contains(f)) {
        reviews.add(Review(kind, id, f, newer[f], older[f], 'changed on both devices'));
      }
    }
  }
  if (deleted) {
    final del = ld != null && rd != null ? newer : (ld != null ? local : remote);
    out
      ..['deletedAt'] = del['deletedAt']
      ..['deletedBy'] = del['deletedBy'];
    final edited = ld != null ? remote : local;
    if (!(ld != null && rd != null) && contentChanged(edited)) {
      reviews.add(Review(kind, id, 'deletedAt', 'deleted', 'edited', 'deleted on one device, edited on the other; the edits are kept in the trash'));
    }
  } else {
    out
      ..['deletedAt'] = null
      ..['deletedBy'] = null;
  }
  out['updatedAt'] = (local['updatedAt'] as int) > (remote['updatedAt'] as int) ? local['updatedAt'] : remote['updatedAt'];
  out['version'] = version + 1;
  return Resolution(out, reviews);
}

Map<String, dynamic> _content(_Row r) => {
      for (final e in r.entries)
        if (!meta.contains(e.key)) e.key: e.value
    };

bool _sameContent(_Row a, _Row b) => _same(_content(a), _content(b));

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    return a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
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
