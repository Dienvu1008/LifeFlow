// P04 T6 (ADR-0058; p04a-exit-gate.md): the owner's device checks, run by
// the agent on the real stack: two devices with their own encrypted stores,
// the real HttpRemoteGateway, a local Supabase with the project's migrations
// (Docker), one account. Real-size records (long notes, a habit occurrence
// moved and done), so the T6 findings stay found.
//   step 1  an edit on one device reaches the other
//   step 3  notes changed on both while offline: a review item; "Take the
//           other" on either device; after Sync now on both, the same notes
//   step 4  deleted on one, renamed on the other: in the trash, renamed,
//           with a review item
// Runs only with LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY
// (as remote_contract_test.dart; CI job supabase-db).
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'profile_harness.dart' show MemoryKeys;

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

class Device {
  Device(this.db, RemoteGateway remote)
      : gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)) {
    tasks = DriftTaskService(db, gw);
    plan = DriftTaskScheduling(db, gw);
    sync = DriftSyncService(db: db, gateway: gw, remote: remote, keyring: WorkspaceKeyring(MemoryKeys().call));
  }
  final AppDatabase db;
  final DriftCommandGateway gw;
  late final DriftTaskService tasks;
  late final DriftTaskScheduling plan;
  late final DriftSyncService sync;

  Future<Map<String, dynamic>?> task(String id) => recordKindByName['task']!.readOne(db, id);

  /// Sync now; it must end up to date.
  Future<SyncReport> now() async {
    final r = await sync.syncNow();
    expect(r.outcome, SyncOutcome.upToDate, reason: '$r');
    return r;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final url = Platform.environment['LIFEFLOW_TEST_SUPABASE_URL'];
  final anon = Platform.environment['LIFEFLOW_TEST_SUPABASE_ANON_KEY'];
  if (url == null || anon == null) {
    test('two devices on local Supabase', () {}, skip: 'set LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY');
    return;
  }
  final client = http.Client();
  tearDownAll(client.close);
  late Directory dir;
  final open = <AppDatabase>[];

  setUp(() => dir = Directory.systemTemp.createTempSync('lifeflow_e2e_'));
  tearDown(() async {
    for (final db in open) {
      await db.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  /// One new account; both devices sign in to it.
  Future<String> account() async {
    final res = await client.post(Uri.parse('$url/auth/v1/signup'),
        headers: {'apikey': anon, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': 'e2e-${const Uuid().v4()}@example.test', 'password': 'correct horse battery staple'}));
    if (res.statusCode != 200) throw StateError('sign-up failed: ${res.statusCode}');
    return (jsonDecode(res.body) as Map)['access_token'] as String;
  }

  Future<Device> device(String name, String token) async {
    final db = AppDatabase(NativeDatabase(File('${dir.path}/$name.db')));
    open.add(db);
    await ProfileStore(db).ensureFirstProfile();
    return Device(db, HttpRemoteGateway(baseUrl: url, anonKey: anon, accessToken: () async => token, client: client));
  }

  /// Windows turns sync on with a recovery key; Android joins with the words.
  Future<(Device, Device)> pair() async {
    final token = await account();
    final windows = await device('windows', token);
    final offer = await windows.sync.offerRecoveryKey();
    final (p1, p2) = offer.check;
    expect((await windows.sync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1]))).problem, isNull);
    final android = await device('android', token);
    final joined = await android.sync.join(JoinChoice.mergeThisDevice, recoveryKey: offer.words.join(' '));
    expect(joined.problem, isNull);
    expect(joined.firstSync!.outcome, SyncOutcome.upToDate, reason: '${joined.firstSync}');
    return (windows, android);
  }

  final longNotes = List.filled(40, 'Bring the forms, the receipts and the signed copy.').join(' ');

  test('step 1 and the T6 findings: real-size records and a moved, done occurrence reach the other device', () async {
    final (w, a) = await pair();
    final id = ok(await w.tasks.create('Run every day'));
    ok(await w.tasks.setNotes(id, longNotes));
    ok(await w.plan.setSchedule(id, TaskScheduleInput(
        start: SchedulePointInput.date(LocalDate(2026, 11, 9)), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
    ok(await w.plan.changeOccurrence(id, LocalDate(2026, 11, 10), MoveThisOccurrence(LocalDate(2026, 11, 11))));
    ok(await w.plan.setOccurrenceDone(id, LocalDate(2026, 11, 10), done: true));
    await w.now();
    await a.now();
    expect((await a.task(id))!['notes'], longNotes);
    expect(await recordKindByName['completion']!.readOne(a.db, 'task:$id@2026-11-10'), isNotNull);
    expect(await recordKindByName['exception']!.readOne(a.db, 'task:$id@2026-11-10'), isNotNull);
    ok(await a.tasks.rename(id, 'Run every morning'));
    await a.now();
    await w.now();
    expect((await w.task(id))!['title'], 'Run every morning');
  });

  for (final lookFirst in [false, true]) {
    test('step 3: notes changed on both offline; "Take the other"; ${lookFirst ? 'the other device still shows the kept note until it syncs; ' : ''}Sync now on both: the same notes', () async {
      final (w, a) = await pair();
      final id = ok(await w.tasks.create('Pay the rent'));
      await w.now();
      await a.now();
      // Both offline: each changes the notes.
      ok(await w.tasks.setNotes(id, 'Windows: $longNotes'));
      ok(await a.tasks.setNotes(id, 'Android: $longNotes'));
      // Back online: Windows first, then Android (it merges).
      await w.now();
      await a.now();
      await w.now();
      final wn = (await w.task(id))!['notes'], an = (await a.task(id))!['notes'];
      expect(wn, an, reason: 'after the merge both show the kept note');
      final reviewer = (await a.sync.reviews()).isNotEmpty ? a : w;
      final item = (await reviewer.sync.reviews()).single;
      expect((item.field, item.reason, item.kept, item.canTakeOther), ('notes', SyncReviewKind.changedOnBoth, wn, true));
      final other = item.other;
      expect(other, isNot(wn));

      // "Take the other" where the item is (the device that merged).
      expect((await reviewer.sync.resolveReview(item.id, takeOther: true)).problem, isNull);
      expect((await reviewer.task(id))!['notes'], other, reason: 'this device at once');
      final elsewhere = identical(reviewer, w) ? a : w;
      if (lookFirst) {
        // What the owner saw: before its next sync the other device still has the kept note.
        expect((await elsewhere.task(id))!['notes'], wn);
      }
      await reviewer.now();
      await elsewhere.now();
      expect((await w.task(id))!['notes'], other);
      expect((await a.task(id))!['notes'], other, reason: 'both devices the same after Sync now');
      expect([...await w.sync.reviews(), ...await a.sync.reviews()], isEmpty);
    });
  }

  test('step 4: deleted on one device, renamed on the other: in the trash, renamed, with a review item', () async {
    final (w, a) = await pair();
    final id = ok(await w.tasks.create('Old plan'));
    await w.now();
    await a.now();
    ok(await w.tasks.trash(id));
    ok(await a.tasks.rename(id, 'New plan'));
    await w.now();
    await a.now();
    await w.now();
    for (final d in [w, a]) {
      final t = (await d.task(id))!;
      expect((t['title'], t['deletedAt'] != null), ('New plan', true));
    }
    final items = [...await w.sync.reviews(), ...await a.sync.reviews()];
    expect(items.single.reason, SyncReviewKind.deletedAndEdited);
  });

  test('GS-08 (P05a T4): a document changed on both offline: both saves kept, one review; "Take the other" reaches the other device',
      () async {
    final (w, a) = await pair();
    DriftDocumentService docs(Device d) => DriftDocumentService(d.db, DriftCommandGateway(d.db, WorkspaceOwnerAuthorization(d.db)));
    DocumentBody body(String s) => DocumentBody([DocBlock('b1', BlockType.paragraph, runs: [TextRun(s)])]);
    Future<String> text(Device d, String id) async => (await DriftDocumentQueries(d.db).document(id))!.body.plainText();
    final id = ok(await docs(w).create('Kế hoạch năm'));
    ok(await docs(w).save(id, title: 'Kế hoạch năm', body: body(longNotes)));
    await w.now();
    await a.now();
    expect(await text(a, id), longNotes, reason: 'a real-size body arrives');
    ok(await docs(w).save(id, title: 'Kế hoạch năm', body: body('Windows: đi Đà Nẵng')));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    ok(await docs(a).save(id, title: 'Kế hoạch năm', body: body('Android: đi Huế')));
    await w.now();
    await a.now();
    await w.now();
    expect(await text(w, id), await text(a, id));
    for (final d in [w, a]) {
      final texts = [
        for (final r in await DriftDocumentQueries(d.db).revisions(id))
          (await DriftDocumentQueries(d.db).revisionContent(r.id))!.$2.plainText(),
      ];
      expect(texts, containsAll(['Windows: đi Đà Nẵng', 'Android: đi Huế', longNotes]), reason: 'no content lost (DOC-005)');
    }
    final items = [...await w.sync.reviews(), ...await a.sync.reviews()];
    expect([for (final i in items) (i.recordKind, i.field)], [('document', 'body')]);
    final reviewer = (await w.sync.reviews()).isNotEmpty ? w : a;
    final other = identical(reviewer, w) ? a : w;
    final shown = await text(reviewer, id);
    final item = (await reviewer.sync.reviews()).single;
    expect((await reviewer.sync.resolveReview(item.id, takeOther: true)).problem, isNull);
    final taken = await text(reviewer, id);
    expect(taken, isNot(shown));
    await reviewer.now();
    await other.now();
    expect(await text(other, id), taken);
    expect((await DriftDocumentQueries(other.db).revisions(id)).first.reason, RevisionReason.conflict);
  });
}
