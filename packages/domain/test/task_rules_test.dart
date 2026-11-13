// P01 T3 pure-domain tests: status transitions (LF-INV-TASK-004), hierarchy
// acyclicity + bounded depth (LF-INV-TASK-002/003, GS-18), measurable target
// validation (LF-INV-TASK-010 groundwork).
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

void main() {
  group('status transitions (LF-INV-TASK-004)', () {
    test('valid and invalid transitions', () {
      expect(isValidTransition(TaskStatus.inbox, TaskStatus.todo), isTrue);
      expect(isValidTransition(TaskStatus.todo, TaskStatus.done), isTrue);
      expect(isValidTransition(TaskStatus.done, TaskStatus.todo), isTrue); // re-open
      expect(isValidTransition(TaskStatus.done, TaskStatus.inbox), isFalse);
      expect(isValidTransition(TaskStatus.cancelled, TaskStatus.inbox), isFalse);
      expect(isValidTransition(TaskStatus.todo, TaskStatus.todo), isTrue); // no-op allowed
    });
  });

  group('measurable target validation (LF-INV-TASK-010 groundwork)', () {
    test('about requires min <= max', () {
      expect(const MeasurableTarget(type: TargetType.about, min: 1, max: 5, unit: 'p').validate(), isNull);
      expect(const MeasurableTarget(type: TargetType.about, min: 5, max: 1, unit: 'p').validate(), isNotNull);
      expect(const MeasurableTarget(type: TargetType.atLeast, min: 5000, unit: 'steps').validate(), isNull);
    });
  });

  group('hierarchy depth (LF-INV-TASK-002)', () {
    test('create at depth boundary', () {
      expect(TaskHierarchyRules.createDepthError(null), isNull); // root
      expect(TaskHierarchyRules.createDepthError(maxTaskDepth - 1), isNull); // last allowed
      expect(TaskHierarchyRules.createDepthError(maxTaskDepth), isNotNull); // too deep
    });

    test('reparent counts the subtasks that move along (P03 UX U2)', () {
      // A task with two levels below it fits under a depth-1 parent, not
      // under a depth-2 one (its deepest subtask would be at depth 5).
      String? at(int parentDepth, int height) => TaskHierarchyRules.reparentError(
            taskId: EntityId('t'),
            newParentId: EntityId('p'),
            newParentAncestorsIncludingSelf: {'p'},
            newParentDepth: parentDepth,
            movedSubtreeHeight: height,
          );
      expect(at(1, 3), isNull);
      expect(at(2, 3), isNotNull);
      expect(at(1, 4), isNotNull);
      expect(at(3, 1), isNull);
    });


    test('reparent rejects exceeding depth', () {
      final t = EntityId('t');
      expect(
        TaskHierarchyRules.reparentError(
          taskId: t,
          newParentId: EntityId('p'),
          newParentAncestorsIncludingSelf: {'p'},
          newParentDepth: maxTaskDepth, // child would be maxDepth+1
        ),
        isNotNull,
      );
    });
  });

  group('hierarchy acyclicity (LF-INV-TASK-003, GS-18)', () {
    test('reparent under self or a descendant is rejected', () {
      final t = EntityId('t');
      // new parent chain includes t itself -> cycle
      expect(
        TaskHierarchyRules.reparentError(
          taskId: t,
          newParentId: EntityId('d'),
          newParentAncestorsIncludingSelf: {'d', 'c', 't'},
          newParentDepth: 2,
        ),
        isNotNull,
      );
    });

    test('property: a random sequence of valid reparents never creates a cycle', () {
      // Model a forest; apply only reparents the rules accept; assert acyclic.
      final rnd = Random(42);
      final ids = List.generate(12, (i) => 'n$i');
      final parent = <String, String?>{for (final id in ids) id: null};

      Set<String> ancestorsIncludingSelf(String id) {
        final chain = <String>{};
        String? cur = id;
        var guard = 0;
        while (cur != null && guard++ < 100) {
          if (!chain.add(cur)) break; // safety; should not happen if acyclic
          cur = parent[cur];
        }
        return chain;
      }

      int depthOf(String id) {
        var d = 1;
        var cur = parent[id];
        var guard = 0;
        while (cur != null && guard++ < 100) {
          d++;
          cur = parent[cur];
        }
        return d;
      }

      int heightOf(String id) {

        var h = 1;

        for (final c in ids.where((c) => parent[c] == id)) {

          h = max(h, 1 + heightOf(c));

        }

        return h;

      }

      

      for (var i = 0; i < 500; i++) {
        final child = ids[rnd.nextInt(ids.length)];
        final np = ids[rnd.nextInt(ids.length)];
        if (np == child) continue;
        final err = TaskHierarchyRules.reparentError(
          taskId: EntityId(child),
          newParentId: EntityId(np),
          newParentAncestorsIncludingSelf: ancestorsIncludingSelf(np),
          newParentDepth: depthOf(np),
          movedSubtreeHeight: heightOf(child),
        );
        if (err == null) parent[child] = np; // accepted -> apply
      }

      // Assert the resulting graph is acyclic and within depth.
      for (final id in ids) {
        final seen = <String>{};
        String? cur = id;
        var guard = 0;
        while (cur != null) {
          expect(seen.add(cur), isTrue, reason: 'cycle detected at $cur');
          cur = parent[cur];
          expect(guard++ < 50, isTrue);
        }
        expect(depthOf(id) <= maxTaskDepth, isTrue, reason: '$id exceeds depth');
      }
    });
  });

  test('Task identity is stable across copyWith (LF-INV-TASK-001)', () {
    final t = Task(id: EntityId('t1'), workspaceId: 'ws', ownerId: 'o', title: 'a');
    final t2 = t.copyWith(title: 'b', status: TaskStatus.done, version: Version.initial.next);
    expect(t2.id, t.id);
    expect(t2.title, 'b');
    expect(t2.status, TaskStatus.done);
    expect(t2.version.value, 2);
  });
}
