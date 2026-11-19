// P04 T3 (ADR-0015, D6/D7): per-type merge rules, pure.
//   fields      different fields both kept; the same field: the newer side
//   status      a task's status never goes down (a completion is not lost)
//   notes       one value; the other kept for review
//   whole       a schedule is one value; the other kept for review
//   delete      beats an edit; the edits stay; a review says so
//   completion  an occurrence tick is never undone by a merge
//   append      measurements and records: never mixed
//   property    merging on either device gives the same record (so devices
//               that both merge still converge), and the version goes up
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

Map<String, dynamic> task({
  int version = 1,
  int updatedAt = 1,
  String title = 'Report',
  String status = 'todo',
  String? notes,
  int? colorIndex,
  int? deletedAt,
}) =>
    {
      'id': 't',
      'workspaceId': 'w',
      'ownerId': 'o',
      'version': version,
      'createdAt': 0,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'deletedBy': deletedAt == null ? null : 'o',
      'title': title,
      'status': status,
      'notes': notes,
      'colorIndex': colorIndex,
    };

SyncMerge merge(String kind, Map<String, dynamic>? base, Map<String, dynamic> l, Map<String, dynamic> r) =>
    mergeRecord(kind, base, l, r, localDevice: 'a', remoteDevice: 'b');

void main() {
  final base = task();

  test('different fields are both kept; the version goes above both sides', () {
    final m = merge('task', base, task(version: 2, updatedAt: 5, title: 'Q3 report'), task(version: 2, updatedAt: 6, colorIndex: 4));
    expect((m.row['title'], m.row['colorIndex'], m.row['version'], m.row['updatedAt'], m.reviews.length), ('Q3 report', 4, 3, 6, 0));
  });

  test('the same field: the newer side (version, then time, then device), no review for a title', () {
    expect(merge('task', base, task(version: 3, title: 'A'), task(version: 2, updatedAt: 9, title: 'B')).row['title'], 'A');
    expect(merge('task', base, task(version: 2, updatedAt: 5, title: 'A'), task(version: 2, updatedAt: 9, title: 'B')).row['title'], 'B');
    final tie = merge('task', base, task(version: 2, title: 'A'), task(version: 2, title: 'B'));
    expect((tie.row['title'], tie.reviews.length), ('B', 0), reason: "device 'b' > 'a'");
  });

  test('P04b: "changed by" is who made the kept change; records before v13 have none', () {
    final base = task();
    final l = {...task(version: 2, updatedAt: 5, title: 'Mine'), 'changedBy': 'acc-a'};
    final r = {...task(version: 2, updatedAt: 9, notes: 'Theirs'), 'changedBy': 'acc-b'};
    final m = merge('task', base, l, r);
    expect((m.row['title'], m.row['notes'], m.row['changedBy']), ('Mine', 'Theirs', 'acc-b'), reason: 'the later side');
    expect(merge('task', base, task(version: 2, title: 'x'), task(version: 2, notes: 'y')).row.containsKey('changedBy'), isFalse);
    expect(m.reviews, isEmpty, reason: 'bookkeeping, not content');
  });

  test('a task\'s status never goes down: a completion is not lost', () {
    for (final (l, r) in [('done', 'inProgress'), ('inProgress', 'done'), ('done', 'todo'), ('todo', 'done')]) {
      final m = merge('task', base, task(version: 2, updatedAt: 9, status: l), task(version: 2, updatedAt: 3, status: r));
      expect(m.row['status'], 'done', reason: '$l vs $r');
    }
    expect(merge('task', base, task(version: 2, status: 'cancelled'), task(version: 2, status: 'inProgress')).row['status'], 'cancelled');
  });

  test('notes changed on both: the newer kept, the other for review', () {
    final m = merge('task', base, task(version: 2, updatedAt: 9, notes: 'Train at 8'), task(version: 2, updatedAt: 3, notes: 'Bus at 9'));
    expect(m.row['notes'], 'Train at 8');
    expect(m.reviews.single, isA<SyncReview>()
        .having((r) => (r.field, r.kept, r.other, r.reason), 'review', ('notes', 'Train at 8', 'Bus at 9', SyncReviewReason.changedOnBoth)));
  });

  test('a delete beats an edit; the edit stays on the deleted record; a review says so', () {
    final m = merge('task', base, task(version: 2, deletedAt: 7), task(version: 2, updatedAt: 9, title: 'Revised'));
    expect((m.row['deletedAt'], m.row['deletedBy'], m.row['title']), (7, 'o', 'Revised'));
    expect(m.reviews.single.reason, SyncReviewReason.deletedAndEdited);
    final both = merge('task', base, task(version: 2, deletedAt: 7), task(version: 2, updatedAt: 9, deletedAt: 8));
    expect((both.row['deletedAt'], both.reviews.length), (8, 0));
    final undeleted = merge('task', task(deletedAt: 1), task(version: 2), task(deletedAt: 1, version: 2, title: 'x'));
    expect(undeleted.row['deletedAt'], isNull, reason: 'a restore on one side, an edit on the other');
  });

  test('a schedule is one value: the newer whole, the other for review', () {
    Map<String, dynamic> s(int v, int at, String first) =>
        {'id': 'task:t', 'version': v, 'updatedAt': at, 'deletedAt': null, 'deletedBy': null, 'firstDate': first, 'rule': 'weekly'};
    final m = merge('schedule', s(1, 1, '2026-11-01'), s(2, 5, '2026-12-01'), s(2, 9, '2026-12-03'));
    expect((m.row['firstDate'], m.row['version']), ('2026-12-03', 3));
    expect(m.reviews.single.field, '*');
    expect((m.reviews.single.other as Map)['firstDate'], '2026-12-01');
  });

  test('an occurrence tick is never undone; measurements are never mixed', () {
    final tick = {'id': 'task:t@2026-11-09', 'version': 1, 'updatedAt': 1, 'deletedAt': null, 'deletedBy': null};
    final untick = {...tick, 'version': 2, 'updatedAt': 9, 'deletedAt': 9, 'deletedBy': 'o'};
    for (final (l, r) in [({...tick, 'version': 2}, untick), (untick, {...tick, 'version': 2})]) {
      expect(merge('completion', tick, l, r).row['deletedAt'], isNull);
    }
    final m1 = {'id': 'm', 'version': 1, 'updatedAt': 1, 'deletedAt': null, 'deletedBy': null, 'value': 20.0};
    final m2 = {...m1, 'value': 99.0, 'updatedAt': 5};
    final m = merge('measurement', null, m1, m2);
    expect(m.row['value'], anyOf(20.0, 99.0));
    expect(m.reviews, isEmpty);
  });

  test('property: either device merging gives the same record', () {
    final rnd = Random(7);
    Map<String, dynamic> randomSide() => task(
          version: 2 + rnd.nextInt(2),
          updatedAt: rnd.nextInt(5),
          title: ['Report', 'A', 'B'][rnd.nextInt(3)],
          status: ['todo', 'inProgress', 'done', 'cancelled'][rnd.nextInt(4)],
          notes: [null, 'x', 'y'][rnd.nextInt(3)],
          colorIndex: [null, 1, 2][rnd.nextInt(3)],
          deletedAt: rnd.nextInt(4) == 0 ? rnd.nextInt(9) : null,
        );
    for (var i = 0; i < 2000; i++) {
      final l = randomSide(), r = randomSide();
      final onA = mergeRecord('task', base, l, r, localDevice: 'a', remoteDevice: 'b').row;
      final onB = mergeRecord('task', base, r, l, localDevice: 'b', remoteDevice: 'a').row;
      expect(onA, onB, reason: 'case $i: $l / $r');
      expect(onA['version'] as int, greaterThan(l['version'] as int));
      expect(onA['version'] as int, greaterThan(r['version'] as int));
      if (l['status'] == 'done' || r['status'] == 'done') expect(onA['status'], 'done');
    }
  });

  group('P05a T4: documents (ADR-0069)', () {
    Map<String, dynamic> doc({int version = 1, int updatedAt = 1, String title = 'Plan', String body = 'B0', String? parentId}) =>
        {
          'id': 'd',
          'workspaceId': 'w',
          'ownerId': 'o',
          'version': version,
          'createdAt': 0,
          'updatedAt': updatedAt,
          'deletedAt': null,
          'deletedBy': null,
          'parentId': parentId,
          'title': title,
          'body': body,
          'orderKey': 'a0',
        };

    test('a body changed on both: the newer stays, the other is a review item (GS-08)', () {
      final m = merge('document', doc(), doc(version: 2, updatedAt: 5, body: 'mine'), doc(version: 2, updatedAt: 9, body: 'theirs'));
      expect(m.row['body'], 'theirs');
      expect([for (final r in m.reviews) (r.field, r.kept, r.other, r.reason)],
          [('body', 'theirs', 'mine', SyncReviewReason.changedOnBoth)]);
    });

    test('a title on one side and a body on the other: both kept, nothing to review', () {
      final m = merge('document', doc(), doc(version: 2, title: 'New title'), doc(version: 2, updatedAt: 3, body: 'new body'));
      expect((m.row['title'], m.row['body']), ('New title', 'new body'));
      expect(m.reviews, isEmpty);
    });

    test('a revision is the same fact on both sides: either copy, never mixed', () {
      final rev = {'id': 'r', 'version': 1, 'updatedAt': 1, 'deletedAt': null, 'documentId': 'd', 'body': 'B'};
      final m = merge('documentRevision', null, rev, {...rev});
      expect(m.row['body'], 'B');
      expect(m.reviews, isEmpty);
    });

    test('a revision changed on both sides (damaged, or a hostile copy) is kept whole, never a mix of the two', () {
      final base = {'id': 'r', 'version': 1, 'updatedAt': 1, 'deletedAt': null, 'documentId': 'd', 'title': 'T', 'body': 'B'};
      final m = merge('documentRevision', base, {...base, 'title': 'T2'}, {...base, 'body': 'B2'});
      expect([m.row['title'], m.row['body']], anyOf(equals(['T2', 'B']), equals(['T', 'B2'])));
    });
  });
}
