// P03 UX U2 (ADR-0046): lists, colours and order keys in export / restore.
//   GS-20   export -> clean install keeps the lists, the colours, the order
//           keys and the lists of events
//   v6 file an older export gets order keys in the order it showed, no colour
//   SR-14   a bad colour, a bad key or an event in an unknown list is refused
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show isValidOrderKey;
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late DriftOverviewService overview;
  late DriftEventService events;
  late DriftDataTransferService transfer;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_ovx_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    svc = Services(host, FakeAuthGateway());
    overview = DriftOverviewService(host.db, gw);
    events = DriftEventService(host.db, gw);
    transfer = DriftDataTransferService(host.db, dir);
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: '$r');
    return (r as CommandOk).entityId;
  }

  Future<void> seed() async {
    final work = ok(await overview.createList('Work', colorIndex: 2));
    final home = ok(await overview.createList('Home'));
    ok(await overview.moveList(home));
    final p = ok(await svc.tasks.create('Plan', listId: work));
    ok(await svc.tasks.create('Step', parentId: p));
    final loose = ok(await svc.tasks.create('Loose'));
    ok(await overview.setTaskColor(loose, 7));
    final e = ok(await events.create(
        EventInput(title: 'Meeting', start: SchedulePointInput.date(LocalDate(2026, 11, 12)), listId: work)));
    ok(await overview.setEventColor(e, 11));
    ok(await overview.moveEvent(e, ItemPlace.inList(work)));
  }

  Future<List<String>> organized(AppDatabase db) async => [
        for (final l in await db.select(db.taskLists).get()) 'list ${l.id} ${l.title} ${l.colorIndex} ${l.orderKey}',
        for (final t in await db.select(db.tasks).get())
          'task ${t.id} ${t.taskListId} ${t.parentTaskId} ${t.colorIndex} ${t.orderKey}',
        for (final e in await db.select(db.events).get()) 'event ${e.id} ${e.listId} ${e.colorIndex} ${e.orderKey}',
      ]..sort();

  Map<String, Object?> payloadOf(String text) =>
      ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();

  test('GS-20: export -> clean install keeps lists, colours, order keys and event lists', () async {
    await seed();
    final before = await organized(host.db);
    final file = await transfer.exportActiveProfile();
    final b = Directory.systemTemp.createTempSync('lifeflow_ovx_clean_');
    final clean = await openDirectory(b, MemoryKeys());
    addTearDown(() async {
      await clean.close();
      b.deleteSync(recursive: true);
    });
    final h = TestHost(clean);
    await h.openActive();
    addTearDown(h.close);
    expect(await DriftDataTransferService(h.db, clean).restore(file.contents), isA<Restored>());
    final store = await clean.openProfile(host.currentId!);
    addTearDown(store.db.close);
    expect(await organized(store.db), before);
  });

  test('a schema-6 file gets order keys in the order it showed, and no colours', () async {
    await svc.tasks.create('First');
    final p = ok(await svc.tasks.create('Second'));
    await svc.tasks.create('Child', parentId: p);
    await svc.tasks.create('Third');
    final payload = payloadOf((await transfer.exportActiveProfile()).contents);
    for (final key in ['taskLists', 'tasks', 'events']) {
      for (final r in (payload[key] as List).cast<Map>()) {
        r
          ..remove('colorIndex')
          ..remove('orderKey')
          ..remove('listId');
      }
    }
    // Same creation second: the file order decides.
    final parsed = ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: 6),
        currentSchemaVersion: AppDatabase.currentSchemaVersion);
    final rows = {for (final t in parsed.records['task']!) t['title']: t};
    expect(rows.values.every((t) => isValidOrderKey(t['orderKey'] as String) && t['colorIndex'] == null), isTrue);
    String key(String t) => rows[t]!['orderKey'] as String;
    expect(key('First').compareTo(key('Second')) < 0 && key('Second').compareTo(key('Third')) < 0, isTrue);
  });

  test('U-D13: the result policy travels with the profile; a v7 file gets "target"; a bad one is refused', () async {
    final payload = payloadOf((await transfer.exportActiveProfile()).contents);
    final profile = (payload['profiles'] as List).cast<Map>().single;
    expect(profile['manualResults'], 'target');
    profile.remove('manualResults');
    final old = ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: 7),
        currentSchemaVersion: AppDatabase.currentSchemaVersion);
    expect(old.profile.manualResults, 'target');
    profile['manualResults'] = 'maybe';
    expect(
        () => ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: AppDatabase.currentSchemaVersion),
            currentSchemaVersion: AppDatabase.currentSchemaVersion),
        throwsA(isA<ExportRejected>().having((e) => e.message, 'message', contains('result policy'))));
  });

  test('dogfooding F3: notes travel in the file; a v8 file gets none; unreadable notes are refused', () async {
    final t = ok(await svc.tasks.create('Visa'));
    ok(await svc.tasks.setNotes(t, 'Bring the forms'));
    final payload = payloadOf((await transfer.exportActiveProfile()).contents);
    final row = (payload['tasks'] as List).cast<Map>().single;
    expect(row['notes'], 'Bring the forms');
    row.remove('notes');
    final old = ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: 8),
        currentSchemaVersion: AppDatabase.currentSchemaVersion);
    expect(old.records['task']!.single['notes'], isNull);
    row['notes'] = 'x' * 20001; // longer than a task keeps
    expect(
        () => ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: AppDatabase.currentSchemaVersion),
            currentSchemaVersion: AppDatabase.currentSchemaVersion),
        throwsA(isA<ExportRejected>()));
  });

  group('untrusted organize fields (SR-14)', () {
    late Map<String, Object?> payload;
    setUp(() async {
      await seed();
      payload = payloadOf((await transfer.exportActiveProfile()).contents);
    });
    void rejected(String mentions) {
      try {
        ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: AppDatabase.currentSchemaVersion),
            currentSchemaVersion: AppDatabase.currentSchemaVersion);
        fail('expected rejection: $mentions');
      } on ExportRejected catch (e) {
        expect(e.kind, RestoreRejection.invalidContents);
        expect(e.message, contains(mentions));
      }
    }

    Map row(String key) => (payload[key] as List).cast<Map>().first;

    test('a colour outside the palette', () {
      row('tasks')['colorIndex'] = 12;
      rejected('a task has an unknown colour');
    });
    test('a colour that is not a number', () {
      row('taskLists')['colorIndex'] = 'red';
      rejected('unreadable');
    });
    test('a bad order key', () {
      row('events')['orderKey'] = 'a00';
      rejected('an event has a bad order key');
    });
    test('an event in an unknown list', () {
      row('events')['listId'] = 'nope';
      rejected('event points to an unknown taskList');
    });
  });
}
