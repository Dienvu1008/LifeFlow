// P03 UX U2 (ADR-0046, R-DATA-LOSS): random drag sequences through the real
// gateway and handlers, against a model. After every drop:
//   - accepted exactly when the model says so (cycle, depth with the moved
//     subtasks, stale position, an event under a task);
//   - an accepted drop rewrites one row, a refused one none;
//   - every container shows the model's order; no item is lost or doubled;
//   - depth <= 4; an event is never under a task (U-D1).
import 'dart:math';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show maxTaskDepth;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

class _Owner implements AuthorizationService {
  @override
  Future<String?> denyReason(ActorRef a, String action, ResourceRef r) async => null;
}

void main() {
  for (final seed in [1, 2, 3]) {
    test('property: 250 random drops keep the model (seed $seed)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.workspaces).insert(WorkspacesCompanion.insert(id: 'ws', ownerId: 'o', createdAt: DateTime.utc(2026)));
      final gw = DriftCommandGateway(db, _Owner());
      final taskH = TaskCommandHandler();
      const eventH = EventCommandHandler();
      const listH = ListCommandHandler();
      var seq = 0;
      Future<CommandResult> run(CommandHandler h, Map<String, Object?> payload, {int? version}) => gw.execute(
          Command(
            operationId: 'op${seq++}',
            actor: const ActorRef(ActorKind.owner, 'o'),
            workspaceId: 'ws',
            type: payload['op'] as String,
            payload: payload,
            expectedVersion: version == null ? null : Version(version),
            issuedAt: Instant.now(),
          ),
          h);

      // The model: container -> ordered ids; parent of each task.
      final model = <String, List<String>>{};
      final parent = <String, String?>{};
      final containerOf = <String, String>{};
      List<String> c(String k) => model.putIfAbsent(k, () => []);
      void put(String id, String k, {String? after}) {
        final list = c(k);
        list.insert(after == null ? 0 : list.indexOf(after) + 1, id);
        containerOf[id] = k;
      }

      final lists = ['L0', 'L1', 'L2'];
      final tasks = [for (var i = 0; i < 10; i++) 'T$i'];
      final events = [for (var i = 0; i < 4; i++) 'E$i'];
      for (final l in lists) {
        expect(await run(listH, {'op': 'create', 'id': l, 'title': l}), isA<CommandOk>());
        c('lists').add(l);
      }
      for (final t in tasks) {
        expect(await run(taskH, {'op': 'create', 'id': t, 'title': t}), isA<CommandOk>());
        c('in:').add(t);
        containerOf[t] = 'in:';
        parent[t] = null;
      }
      for (final e in events) {
        final r = await run(eventH, {
          'op': 'create',
          'id': e,
          'title': e,
          'schedule': scheduleFieldsJson('event', e,
              specOfInput(TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 11, 12)))), null),
        });
        expect(r, isA<CommandOk>(), reason: '$r');
        c('in:').add(e);
        containerOf[e] = 'in:';
      }

      Future<Map<String, int>> versions() async => {
            for (final t in await db.select(db.tasks).get()) t.id: t.version,
            for (final e in await db.select(db.events).get()) e.id: e.version,
            for (final l in await db.select(db.taskLists).get()) l.id: l.version,
          };
      Future<int> version(String id) async => (await versions())[id]!;

      int depth(String t) {
        var d = 1;
        for (var p = parent[t]; p != null; p = parent[p]) {
          d++;
        }
        return d;
      }

      int height(String t) {
        var h = 1;
        for (final k in tasks.where((k) => parent[k] == t)) {
          h = max(h, 1 + height(k));
        }
        return h;
      }

      bool isAncestorOrSelf(String a, String t) {
        for (String? p = t; p != null; p = parent[p]) {
          if (p == a) return true;
        }
        return false;
      }

      Future<Map<String, List<String>>> stored() async {
        final out = <String, List<(String, String)>>{};
        void add(String k, String id, String key) => out.putIfAbsent(k, () => []).add((key, id));
        for (final l in await db.select(db.taskLists).get()) {
          add('lists', l.id, l.orderKey);
        }
        for (final t in await db.select(db.tasks).get()) {
          add(t.parentTaskId != null ? 'under:${t.parentTaskId}' : 'in:${t.taskListId ?? ''}', t.id, t.orderKey);
          if (t.parentTaskId != null) expect(t.taskListId, isNull, reason: 'a subtask keeps no list');
        }
        for (final e in await db.select(db.events).get()) {
          add('in:${e.listId ?? ''}', e.id, e.orderKey);
        }
        return {
          for (final MapEntry(:key, :value) in out.entries)
            key: [for (final p in value..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2))) p.$2]
        };
      }

      final rnd = Random(seed);
      String? pick(List<String> from) => from.isEmpty ? null : from[rnd.nextInt(from.length)];
      var accepted = 0, refusedCount = 0;

      for (var i = 0; i < 250; i++) {
        final before = await versions();
        final kind = rnd.nextInt(10);
        late bool expectOk;
        late CommandResult r;
        void Function() apply = () {};

        if (kind == 0) {
          // A list.
          final l = pick(lists)!;
          final others = [...c('lists')]..remove(l);
          final stale = rnd.nextInt(8) == 0;
          final after = stale ? pick(tasks) : (rnd.nextBool() ? null : pick(others));
          expectOk = after == null || others.contains(after);
          r = await run(listH, {'op': 'move', 'id': l, 'afterId': after}, version: await version(l));
          apply = () {
            c('lists').remove(l);
            put(l, 'lists', after: after);
          };
        } else {
          // A task or an event, to a random place.
          final isEvent = kind <= 2;
          final id = isEvent ? pick(events)! : pick(tasks)!;
          final where = rnd.nextInt(3);
          final String? listId = where == 1 ? pick(lists) : null;
          final String? parentId = where == 2 ? pick(tasks) : null;
          final k = parentId != null ? 'under:$parentId' : 'in:${listId ?? ''}';
          final others = [...c(k)]..remove(id);
          final stale = rnd.nextInt(8) == 0;
          final after = stale ? pick([...tasks, ...events]) : (rnd.nextBool() ? null : pick(others));
          final positionOk = after == null || others.contains(after);
          if (isEvent) {
            expectOk = parentId == null && positionOk;
            r = await run(eventH, {'op': 'move', 'id': id, 'listId': listId, 'parentId': parentId, 'afterId': after},
                version: await version(id));
          } else {
            final hierarchyOk = parentId == null ||
                (!isAncestorOrSelf(id, parentId) && depth(parentId) + height(id) <= maxTaskDepth);
            expectOk = hierarchyOk && positionOk;
            r = await run(taskH, {'op': 'move', 'id': id, 'listId': listId, 'parentId': parentId, 'afterId': after},
                version: await version(id));
          }
          apply = () {
            c(containerOf[id]!).remove(id);
            put(id, k, after: after);
            if (!isEvent) parent[id] = parentId;
          };
        }

        expect(r is CommandOk, expectOk, reason: 'step $i: $r');
        if (r is CommandOk) {
          apply();
          accepted++;
        } else {
          refusedCount++;
        }
        final changed = (await versions()).entries.where((e) => before[e.key] != e.value).length;
        expect(changed, r is CommandOk ? 1 : 0, reason: 'step $i rewrote $changed rows');

        final s = await stored();
        final m = {
          for (final e in model.entries)
            if (e.value.isNotEmpty) e.key: e.value
        };
        expect(s, m, reason: 'step $i');
        final all = s.values.expand((v) => v).toList();
        expect(all.length, lists.length + tasks.length + events.length);
        expect(all.toSet().length, all.length);
        for (final t in tasks) {
          expect(depth(t), lessThanOrEqualTo(maxTaskDepth));
        }
        expect(s.keys.where((k) => k.startsWith('under:')).expand((k) => s[k]!).where(events.contains), isEmpty);
      }
      // The sequence exercised both outcomes.
      expect(accepted, greaterThan(50));
      expect(refusedCount, greaterThan(20));
    });
  }
}
