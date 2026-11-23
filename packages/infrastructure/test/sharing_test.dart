// P04b T12 (ADR-0064): the sharing commands, end to end on the in-memory
// server, each person (and each device) with their own store, keys and
// personal sync turned on first (B5).
//   create     a named space (the name sealed, set by the owner only)
//   invite     both kinds, the rules seen first (SHARE-005), cancel
//   move       asked first: what becomes visible; nothing moves if it
//              changed (PRIV-002); a tracked task or a subtask alone never;
//              reminders stay personal (B2, B3); back out is a delete for
//              the others; (P05a T5) a document with its subdocuments and
//              history, its authors kept, its links left behind
//   devices    a move on one device of the account reaches its other device,
//              whichever sync comes first ("moved away", kept aside)
//   assign     to an owner or editor only (B9)
//   leave      the leaving rule (B8): disappear, export first, read-only
//   rules      a change is a notice for every member (SHARE-005); export by
//              the export rule (B14)
import 'dart:convert';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'profile_harness.dart' show MemoryKeys;

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

void okShare(SharingResult r) => expect(r.problem, isNull, reason: r.detail);

/// One device, signed in to [account].
class Device {
  Device._(this.account, this.server, this.db) : gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)) {
    remote = MemoryRemoteGateway(server, accountId: account);
    keyring = WorkspaceKeyring(slots.call);
    keys = SpaceKeyService(server: remote, keyring: keyring, slots: slots.call);
    personalSync = DriftSyncService(db: db, gateway: gw, remote: remote, keyring: keyring);
    spaceSync = DriftSpaceSyncService(db: db, gateway: gw, remote: remote, spaces: remote, keyring: keyring, keys: keys);
    sharing = DriftSharingService(db: db, gateway: gw, server: remote, keys: keys, keyring: keyring, sync: spaceSync);
    tasks = DriftTaskService(db, gw);
    scheduling = DriftTaskScheduling(db, gw);
    spaces = DriftSpaceService(db, gw);
    docs = DriftDocumentService(db, gw, deviceId: '$account-device');
    docQueries = DriftDocumentQueries(db);
  }
  final String account;
  final MemoryRemoteServer server;
  final AppDatabase db;
  final DriftCommandGateway gw;
  final slots = MemoryKeys();
  late final MemoryRemoteGateway remote;
  late final WorkspaceKeyring keyring;
  late final SpaceKeyService keys;
  late final DriftSyncService personalSync;
  late final DriftSpaceSyncService spaceSync;
  late final DriftSharingService sharing;
  late final DriftTaskService tasks;
  late final DriftTaskScheduling scheduling;
  late final DriftSpaceService spaces;
  late final DriftDocumentService docs;
  late final DriftDocumentQueries docQueries;

  static Future<Device> open(String account, MemoryRemoteServer server) async {
    final d = Device._(account, server, AppDatabase(NativeDatabase.memory()));
    final p = await ProfileStore(d.db).ensureFirstProfile();
    await (d.db.update(d.db.profiles)..where((x) => x.id.equals(p.profileId.value)))
        .write(ProfilesCompanion(accountId: Value(account), accountProvider: const Value('github')));
    return d;
  }

  Future<String> personal() async => (await ProfileStore(db).personalWorkspaceId())!;
  Future<Map<String, dynamic>?> row(String kind, String id) => recordKindByName[kind]!.readOne(db, id);
  Future<void> show(String ws) async => ok(await spaces.show(ws));
  Future<SyncReport> syncSpace() async {
    final r = await spaceSync.syncNow();
    expect(r.outcome, SyncOutcome.upToDate, reason: '$account: $r');
    return r;
  }

  Future<SyncReport> syncPersonal() async {
    final r = await personalSync.syncNow();
    expect(r.outcome, SyncOutcome.upToDate, reason: '$account personal: $r');
    return r;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MemoryRemoteServer server;
  final open = <Device>[];

  final words = <String, List<String>>{};
  // The server's clock moves on at each look, so a later change is later
  // (the store keeps times to the second).
  MemoryRemoteServer newServer() {
    var now = DateTime.now().toUtc();
    return MemoryRemoteServer(clock: () => now = now.add(const Duration(seconds: 2)));
  }

  setUp(() {
    server = newServer();
    words.clear();
  });
  tearDown(() async {
    for (final d in open) {
      await d.db.close();
    }
    open.clear();
  });

  /// A device of [account] with personal sync on (the first of the account
  /// sets it up; the next ones join with the recovery key).
  Future<Device> device(String account) async {
    final d = await Device.open(account, server);
    open.add(d);
    if (words[account] == null) {
      final offer = await d.personalSync.offerRecoveryKey();
      final (p1, p2) = offer.check;
      expect((await d.personalSync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1]))).problem, isNull);
      words[account] = offer.words;
    } else {
      final r = await d.personalSync.join(JoinChoice.mergeThisDevice, recoveryKey: words[account]!.join(' '));
      expect(r.problem, isNull);
    }
    return d;
  }

  /// [owner] makes "Family"; the others join it by "approve" invitations.
  Future<String> family(Device owner, List<(Device, SpaceRole)> others) async {
    final made = await owner.sharing.createSpace('Family');
    okShare(made);
    final ws = made.spaceId!;
    for (final (d, role) in others) {
      final inv = await owner.sharing.invite(ws, role, InviteKind.approve);
      okShare(inv);
      okShare(await d.sharing.join(inv.invitation!.link));
      okShare(await owner.sharing.approve(ws, d.account));
      expect(await d.spaceSync.refresh(), isNull);
      await d.show(ws);
    }
    return ws;
  }

  test('create: a named space, shown at once; the name reaches members sealed; only the owner renames it', () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final ws = await family(lan, [(minh, SpaceRole.editor)]);
    final mine = (await lan.spaces.spaces()).singleWhere((s) => s.shared);
    expect((mine.name, mine.role, mine.isShown, mine.rulesChanged), ('Family', SpaceRole.owner, true, false));
    await lan.syncSpace();
    await minh.syncSpace();
    expect((await minh.spaces.spaces()).singleWhere((s) => s.shared).name, 'Family');
    for (final s in server.dump(ws)) {
      expect(utf8.decode(s.sealed!, allowMalformed: true), isNot(contains('Family')), reason: 'the server never sees the name');
    }
    expect((await minh.sharing.renameSpace(ws, 'Mine now')).problem, SharingProblem.failed);
    okShare(await lan.sharing.renameSpace(ws, 'The Nguyens'));
    await lan.syncSpace();
    await minh.syncSpace();
    expect((await minh.spaces.spaces()).singleWhere((s) => s.shared).name, 'The Nguyens');
    expect((await lan.sharing.createSpace('')).problem, SharingProblem.failed);
  });

  test('T14 finding 1: the name typed when joining is the one sent; without one, the profile\'s', () async {
    final lan = await device('lan');
    final vy = await device('vy');
    final minh = await device('minh');
    await (minh.db.update(minh.db.profiles)).write(const ProfilesCompanion(displayName: Value('Minh')));
    final ws = (await lan.sharing.createSpace('Family')).spaceId!;
    Future<String> code() async => (await lan.sharing.invite(ws, SpaceRole.viewer, InviteKind.approve)).invitation!.code;
    expect((await vy.sharing.join(await code(), name: 'V' * 61)).problem, SharingProblem.failed,
        reason: 'at most 60 characters, as a member card');
    okShare(await vy.sharing.join(await code(), name: '  Vy  '));
    okShare(await minh.sharing.join(await code(), name: '  '));
    final names = {for (final m in await lan.sharing.members(ws)) m.accountId: m.name};
    expect(names, {'lan': null, 'vy': 'Vy', 'minh': 'Minh'},
        reason: 'the profile has no name, so Vy\'s typed one; Minh typed none, so the profile\'s');
  });

  test('T13 names (ADR-0065): who waits is named for the owner only; members\' names are sealed records', () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final vy = await device('vy');
    for (final (d, name) in [(lan, 'Lan'), (minh, 'Minh'), (vy, 'Vy')]) {
      await (d.db.update(d.db.profiles)).write(ProfilesCompanion(displayName: Value(name)));
    }
    final ws = (await lan.sharing.createSpace('Family')).spaceId!;
    final inv = (await lan.sharing.invite(ws, SpaceRole.viewer, InviteKind.approve)).invitation!;
    okShare(await vy.sharing.join(inv.code));
    final waiting = (await lan.sharing.members(ws)).singleWhere((m) => m.accountId == 'vy');
    expect((waiting.status, waiting.name), (MemberStatus.pending, 'Vy'), reason: 'the owner sees who waits');
    final raw = (await lan.remote.members(ws)).singleWhere((m) => m.accountId == 'vy').sealedName!;
    expect(utf8.decode(raw, allowMalformed: true), isNot(contains('Vy')), reason: 'the server never sees it');

    okShare(await lan.sharing.approve(ws, 'vy'));
    final atOnce = (await lan.sharing.invite(ws, SpaceRole.editor, InviteKind.joinAtOnce)).invitation!;
    okShare(await minh.sharing.join(atOnce.code));
    expect(await lan.spaceSync.refresh(), isNull, reason: 'the owner\'s device writes the names it has');
    await lan.syncSpace();
    for (final d in [minh, vy]) {
      expect(await d.spaceSync.refresh(), isNull);
      await d.show(ws);
      await d.syncSpace();
    }
    await minh.syncSpace(); // Minh's own card, then everyone's
    await lan.syncSpace();
    await vy.syncSpace();
    for (final d in [lan, minh, vy]) {
      final names = {for (final m in await d.sharing.members(ws)) m.accountId: m.name};
      expect(names, {'lan': 'Lan', 'minh': 'Minh', 'vy': 'Vy'}, reason: d.account);
      expect((await d.sharing.members(ws)).singleWhere((m) => m.isMe).accountId, d.account);
    }
    for (final s in server.dump(ws)) {
      expect(utf8.decode(s.sealed!, allowMalformed: true), isNot(anyOf(contains('Minh'), contains('Vy'))));
    }
    okShare(await minh.sharing.setMyName(ws, 'Minh N.'));
    expect((await vy.sharing.setMyName(ws, 'Not me')).problem, SharingProblem.notAllowed,
        reason: 'a viewer writes nothing to the space; the owner wrote their name');
    await minh.syncSpace();
    await lan.syncSpace();
    expect((await lan.sharing.memberNames(ws))['minh'], 'Minh N.');
    expect((await lan.sharing.memberNames(ws))['vy'], 'Vy');
    expect((await minh.sharing.setMyName(ws, '')).problem, SharingProblem.failed);
    expect(await vy.sharing.myAccountId(), 'vy');

    // Only the owner names someone else; a card pulled under another
    // member's id is not taken.
    final renameVy = await minh.gw.execute(
        Command(
            operationId: 'op-rename-vy',
            actor: const ActorRef(ActorKind.member, 'minh'),
            workspaceId: ws,
            type: 'NameMember',
            payload: {'op': 'setName', 'id': memberCardIdOf(ws, 'vy'), 'accountId': 'vy', 'name': 'Someone else'},
            issuedAt: Instant.now()),
        const MemberCardHandler());
    expect(renameVy, isA<CommandFailure>());
    final wrongId = await minh.gw.execute(
        Command(
            operationId: 'op-wrong-id',
            actor: const ActorRef(ActorKind.member, 'minh'),
            workspaceId: ws,
            type: 'NameMember',
            payload: {'op': 'setName', 'id': 'somewhere-else', 'accountId': 'minh', 'name': 'Minh'},
            issuedAt: Instant.now()),
        const MemberCardHandler());
    expect(wrongId, isA<CommandFailure>(), reason: 'a card\'s id is <space>:<account>');
    final sealer = await RecordSealer.of((await minh.keyring.keyOf(ws))!);
    final sid = await sealer.serverId('memberCard', 'forged');
    final card = {...(await minh.row('memberCard', memberCardIdOf(ws, 'minh')))!, 'id': 'forged', 'displayName': 'Forged', 'version': 1};
    await minh.remote.push(ws, 'minh', [
      RecordPush(id: sid, base: null, version: 1, deleted: false,
          sealed: await sealer.seal(sid, 1, {'kind': 'memberCard', 'id': 'forged', 'schemaVersion': AppDatabase.recordSchemaVersion, 'row': card}),
          operationId: 'op-forged')
    ], keyId: sealer.keyId);
    final r = await lan.syncSpace();
    expect(r.notTaken, 1);
    expect(await lan.row('memberCard', 'forged'), isNull);
  });

  test('B5: without personal sync, or signed out, no space is made or joined', () async {
    final guest = await Device.open('nosync', server);
    open.add(guest);
    expect((await guest.sharing.createSpace('Mine')).problem, SharingProblem.syncOff);
    await (guest.db.update(guest.db.profiles)).write(const ProfilesCompanion(signedOut: Value(true)));
    expect((await guest.sharing.createSpace('Mine')).problem, SharingProblem.notSignedIn);
  });

  test('invitations: the rules first (SHARE-005), "join at once", one use, cancel, the owner approves', () async {
    final lan = await device('lan');
    final jo = await device('jo');
    final vy = await device('vy');
    final ws = (await lan.sharing.createSpace('Family')).spaceId!;
    okShare(await lan.sharing.setRules(ws, const SpaceRules(leave: LeaveRule.keepReadOnly)));
    final atOnce = (await lan.sharing.invite(ws, SpaceRole.editor, InviteKind.joinAtOnce)).invitation!;
    expect(parseInvitation(atOnce.grouped), atOnce.code);
    final seen = await jo.sharing.peek(atOnce.grouped.toLowerCase());
    expect((seen.preview!.leave, seen.preview!.kind), (LeaveRule.keepReadOnly, InviteKind.joinAtOnce));
    okShare(await jo.sharing.join(atOnce.code));
    expect((await jo.spaces.spaces()).singleWhere((s) => s.shared).role, SpaceRole.editor);
    expect((await vy.sharing.join(atOnce.code)).problem, SharingProblem.noSuchInvitation, reason: 'one use');
    expect((await vy.sharing.peek('not a code')).problem, SharingProblem.noSuchInvitation);

    final cancelled = (await lan.sharing.invite(ws, SpaceRole.viewer, InviteKind.approve)).invitation!;
    final hash = (await lan.sharing.invitations(ws)).single.codeHash;
    okShare(await lan.sharing.cancelInvitation(ws, hash));
    expect((await vy.sharing.join(cancelled.code)).problem, SharingProblem.noSuchInvitation);

    final approve = (await lan.sharing.invite(ws, SpaceRole.viewer, InviteKind.approve)).invitation!;
    okShare(await vy.sharing.join(approve.code));
    expect([for (final s in await vy.spaces.spaces()) s.shared], [false], reason: 'waiting: not shown yet');
    final waiting = (await lan.sharing.members(ws)).where((m) => m.status == MemberStatus.pending).single;
    expect(waiting.accountId, 'vy');
    expect((await jo.sharing.approve(ws, 'vy')).problem, SharingProblem.notAllowed, reason: 'an editor cannot approve');
    okShare(await lan.sharing.approve(ws, 'vy'));
    expect(await vy.spaceSync.refresh(), isNull);
    expect((await vy.spaces.spaces()).singleWhere((s) => s.shared).role, SpaceRole.viewer);
  });

  test('move into a space: asked first; reminders stay personal; the member sees it; changed since shown: nothing moves',
      () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final ws = await family(lan, [(minh, SpaceRole.editor)]);
    await lan.show(await lan.personal());
    final trip = ok(await lan.tasks.create('Trip to Hue'));
    ok(await lan.tasks.setNotes(trip, 'Train at 8'));
    final sub = ok(await lan.tasks.create('Book tickets', parentId: trip));
    ok(await lan.scheduling.setSchedule(trip, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 1)))));
    ok(await DriftReminderService(lan.db, lan.gw).setReminders(ReminderSubject.task, trip, [const RemindMinutesBefore(60)]));
    final reminder = (await lan.db.select(lan.db.reminders).get()).single;

    final preview = await lan.sharing.previewMove('task', trip, ws);
    expect(preview.blocker, isNull);
    expect(preview.counts, {'task': 2, 'schedule': 1});
    expect(preview.titles, ['Trip to Hue', 'Book tickets']);
    expect((preview.hasNotes, preview.hasDates), (true, true));

    // Changed after it was shown: nothing moves (PRIV-002).
    ok(await lan.tasks.rename(sub, 'Book the train'));
    expect((await lan.sharing.move(preview)).problem, SharingProblem.changedSinceShown);
    expect((await lan.row('task', trip))!['workspaceId'], await lan.personal());

    okShare(await lan.sharing.move(await lan.sharing.previewMove('task', trip, ws)));
    for (final (k, id) in [('task', trip), ('task', sub), ('schedule', 'task:$trip')]) {
      final r = (await lan.row(k, id))!;
      expect((r['workspaceId'], r['ownerId']), (ws, 'lan'), reason: '$k $id');
    }
    final kept = (await lan.row('reminder', reminder.id))!;
    expect(kept['workspaceId'], await lan.personal(), reason: 'a reminder stays with the person (B2, B3)');
    expect((await lan.row('task', trip))!['taskListId'], isNull);

    await lan.syncPersonal();
    await lan.show(ws);
    await lan.syncSpace();
    await minh.syncSpace();
    expect((await minh.row('task', trip))!['notes'], 'Train at 8');
    expect((await minh.row('task', sub))!['title'], 'Book the train');
    expect(await minh.row('reminder', reminder.id), isNull);

    // And back out: the personal copy on the server was "moved away"; the
    // new one goes above it, nothing is refused.
    okShare(await lan.sharing.move(await lan.sharing.previewMove('task', trip, await lan.personal())));
    await lan.syncSpace();
    final back = await lan.syncPersonal();
    expect((back.failedRecords, back.pushed > 0), (0, true), reason: '$back');
    expect((await lan.row('task', trip))!['workspaceId'], await lan.personal());
  });

  test('P05b T6 steps 14, 29, 30: a PDF word is found only through a live document of the shown space, '
      'after the trash, a move to the space and back, and sync', () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final ws = await family(lan, [(minh, SpaceRole.editor)]);
    await lan.show(await lan.personal());
    final pdf = AttachmentRef(hash: 'sha256:${'e' * 64}', name: 'P1.pdf', size: 9, mime: 'application/pdf');
    final index = PdfTextIndex(lan.db, _HereFiles(), read: (_) async => const PdfText(PdfTextStatus.indexed, ['Tờ khai thuế']));
    final search = DriftSearchQueries(lan.db, pdfs: index);
    Future<List<String>> found() async => [for (final h in (await search.search('khai')).files) h.documentTitle];

    final d = ok(await lan.docs.create('Hồ sơ thuế'));
    ok(await lan.docs.save(d,
        title: 'Hồ sơ thuế', body: DocumentBody([DocBlock('f', BlockType.attachment, attachment: pdf)])));
    await index.catchUp();
    expect(await found(), ['Hồ sơ thuế']);

    // Step 14: the trash, then a sync, then restored.
    ok(await lan.docs.trash(d));
    expect(await found(), isEmpty, reason: 'in the trash');
    await lan.syncPersonal();
    await index.catchUp();
    expect(await found(), isEmpty, reason: 'in the trash, after a sync');
    ok(await lan.docs.restore(d));
    expect(await found(), ['Hồ sơ thuế']);

    // Steps 28-30: into the space and back.
    okShare(await lan.sharing.move(await lan.sharing.previewMove('document', d, ws)));
    await lan.syncSpace();
    await lan.syncPersonal();
    await index.catchUp();
    expect(await found(), isEmpty, reason: 'Personal shown: the document moved');
    await lan.show(ws);
    expect(await found(), ['Hồ sơ thuế'], reason: 'the space shown');
    okShare(await lan.sharing.move(await lan.sharing.previewMove('document', d, await lan.personal())));
    await lan.syncSpace();
    await lan.syncPersonal();
    await index.catchUp();
    expect(await found(), isEmpty, reason: 'the space shown: the document left');
    await lan.show(await lan.personal());
    expect(await found(), ['Hồ sơ thuế']);
  });

  test('P05a T5 (C2, C8): a document moves with its subdocuments and its whole history; its links stay; '
      'the members see who wrote what; a viewer saves nothing; and back out', () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final vy = await device('vy');
    final ws = await family(lan, [(minh, SpaceRole.editor), (vy, SpaceRole.viewer)]);
    await lan.show(await lan.personal());
    final d = ok(await lan.docs.create('Recipes'));
    ok(await lan.docs.save(d, title: 'Recipes', body: _text('Rice first')));
    final child = ok(await lan.docs.create('Phở', parentId: d));
    final old = ok(await lan.docs.create('Old notes', parentId: d));
    ok(await lan.docs.trash(old));
    final t = ok(await lan.tasks.create('Buy rice'));
    ok(await lan.docs.link(d, DocumentItemType.task, t));

    final preview = await lan.sharing.previewMove('document', d, ws);
    expect(preview.blocker, isNull);
    expect(preview.counts, {'document': 2, 'documentRevision': 3}, reason: '"…and 3 earlier versions" (C8)');
    expect(preview.titles, ['Recipes', 'Phở'], reason: 'a revision is counted, not listed; the trashed one stays');
    expect((preview.hasNotes, preview.hasDates), (true, false), reason: 'a document\'s text is shown as notes');
    final alone = await lan.sharing.previewMove('document', child, ws);
    expect(alone.counts, {'document': 1, 'documentRevision': 1});
    expect(alone.hasNotes, isFalse, reason: 'an empty document');

    // Changed after it was shown: nothing moves (PRIV-002).
    ok(await lan.docs.save(child, title: 'Phở', body: _text('Broth for 6 hours')));
    expect((await lan.sharing.move(preview)).problem, SharingProblem.changedSinceShown);
    expect((await lan.row('document', d))!['workspaceId'], await lan.personal());

    okShare(await lan.sharing.move(await lan.sharing.previewMove('document', d, ws)));
    final revisions = await lan.db.select(lan.db.documentRevisions).get();
    for (final r in revisions.where((r) => r.documentId != old)) {
      expect((r.workspaceId, r.ownerId, r.changedBy), (ws, 'lan', 'lan'), reason: 'the mover wrote them');
    }
    expect((await lan.row('document', d))!['parentId'], isNull);
    expect((await lan.row('document', child))!['parentId'], d);
    final left = (await lan.row('document', old))!;
    expect((left['workspaceId'], left['deletedAt'] != null), (await lan.personal(), true));
    final link = (await lan.db.select(lan.db.documentLinks).get()).single;
    expect(link.workspaceId, await lan.personal(), reason: 'links stay where they are, as goal links');

    await lan.syncPersonal();
    await lan.show(ws);
    expect(await lan.docQueries.linksOf(d), isEmpty, reason: 'a link shows where its document is');
    expect(await lan.docs.link(d, DocumentItemType.task, t), isA<CommandFailure>(), reason: 'the task is personal');
    expect(await lan.docs.unlink(d, DocumentItemType.task, t), isA<CommandFailure>(),
        reason: 'the link left behind is not the space\'s to change');
    await lan.syncSpace();
    await minh.syncSpace();
    await vy.syncSpace();
    final seen = (await minh.docQueries.document(d))!;
    expect((seen.title, seen.body.blocks.single.text), ('Recipes', 'Rice first'));
    expect([for (final r in await minh.docQueries.revisions(d)) (r.documentVersion, r.author)], [(2, 'lan'), (1, 'lan')]);
    expect(await minh.docQueries.revisions(child), hasLength(2));
    expect(await minh.row('document', old), isNull);
    expect(await minh.db.select(minh.db.documentLinks).get(), isEmpty);

    ok(await minh.docs.save(d, title: 'Recipes', body: _text('Rice first, then water')));
    expect(await vy.docs.save(d, title: 'Recipes', body: _text('Mine now')), isA<CommandFailure>(), reason: 'a viewer');
    await minh.syncSpace();
    await lan.syncSpace();
    expect([for (final r in await lan.docQueries.revisions(d)) r.author], ['minh', 'lan', 'lan']);

    // And back out, with what Minh wrote: for the others it is a delete.
    final out = await lan.sharing.previewMove('document', d, await lan.personal());
    expect(out.counts, {'document': 2, 'documentRevision': 5});
    okShare(await lan.sharing.move(out));
    await lan.syncSpace();
    await lan.syncPersonal();
    await minh.syncSpace();
    expect((await minh.row('document', d))!['deletedAt'], isNotNull);
    await lan.show(await lan.personal());
    expect([for (final r in await lan.docQueries.revisions(d)) r.author], ['minh', 'lan', 'lan'], reason: 'who wrote what is kept');
    expect((await lan.row('document', d))!['changedBy'], isNull);
    expect([for (final l in await lan.docQueries.linksOf(d)) l.itemId], [t], reason: 'back with its link');

    // In again: a revision names who wrote it once; the authors stay.
    okShare(await lan.sharing.move(await lan.sharing.previewMove('document', d, ws)));
    await lan.show(ws);
    expect([for (final r in await lan.docQueries.revisions(d)) r.author], ['minh', 'lan', 'lan']);
    expect((await lan.row('document', d))!['changedBy'], 'lan', reason: 'the document itself: moved by Lan');
  });

  test('P05a T5: a document moved reaches the account\'s other device, whichever sync comes first', () async {
    for (final personalFirst in [true, false]) {
      server = newServer();
      words.clear();
      final pc = await device('lan');
      final phone = await device('lan');
      final ws = await family(pc, []);
      await pc.show(await pc.personal());
      final d = ok(await pc.docs.create('Packing list'));
      ok(await pc.docs.save(d, title: 'Packing list', body: _text('Passports')));
      await pc.syncPersonal();
      await phone.syncPersonal();
      expect(await phone.spaceSync.refresh(), isNull);

      okShare(await pc.sharing.move(await pc.sharing.previewMove('document', d, ws)));
      await pc.syncPersonal();
      await pc.show(ws);
      await pc.syncSpace();

      await phone.show(ws);
      if (personalFirst) {
        await phone.syncPersonal();
        expect(await phone.row('document', d), isNull, reason: 'gone from personal');
        await phone.syncSpace();
      } else {
        final r = await phone.syncSpace();
        expect(r.notTaken, greaterThan(0), reason: 'kept aside while it is still personal here');
        await phone.syncPersonal();
        await phone.syncSpace();
      }
      final there = (await phone.row('document', d))!;
      expect((there['workspaceId'], there['deletedAt']), (ws, null), reason: 'personal first: $personalFirst');
      expect([for (final r in await phone.docQueries.revisions(d)) (r.documentVersion, r.author)], [(2, 'lan'), (1, 'lan')],
          reason: 'personal first: $personalFirst');
    }
  });

  test('what never moves: a tracked task, a subtask alone, into a space one is not in', () async {
    final lan = await device('lan');
    final ws = await family(lan, []);
    await lan.show(await lan.personal());
    final habit = ok(await lan.tasks.create('Run'));
    ok(await DriftHabitService(lan.db, lan.gw, const _Utc()).setHabit(habit, isHabit: true));
    final parent = ok(await lan.tasks.create('Parent'));
    final child = ok(await lan.tasks.create('Child', parentId: parent));
    expect((await lan.sharing.previewMove('task', habit, ws)).blocker, contains('tracked'));
    expect((await lan.sharing.previewMove('task', child, ws)).blocker, contains('top-level'));
    expect((await lan.sharing.previewMove('task', parent, 'not-a-space')).blocker, isNotNull);
    final blocked = await lan.sharing.previewMove('task', habit, ws);
    expect((await lan.sharing.move(blocked)).problem, SharingProblem.cannotMove);

    // A task leaves its personal list behind; a list takes its tasks along.
    final lists = DriftOverviewService(lan.db, lan.gw);
    final shopping = ok(await lists.createList('Shopping'));
    final milk = ok(await lan.tasks.create('Milk', listId: shopping));
    final bread = ok(await lan.tasks.create('Bread', listId: shopping));
    okShare(await lan.sharing.move(await lan.sharing.previewMove('task', milk, ws)));
    final moved = (await lan.row('task', milk))!;
    expect((moved['workspaceId'], moved['taskListId']), (ws, null));
    final all = await lan.sharing.previewMove('taskList', shopping, ws);
    expect([all.counts, all.titles], [{'taskList': 1, 'task': 1}, ['Shopping', 'Bread']]);
    okShare(await lan.sharing.move(all));
    final b = (await lan.row('task', bread))!;
    expect((b['workspaceId'], b['taskListId']), (ws, shopping));
  });

  test('a move reaches the account\'s other device whichever sync comes first ("moved away")', () async {
    for (final personalFirst in [true, false]) {
      server = newServer();
      words.clear();
      final pc = await device('lan');
      final phone = await device('lan');
      final ws = await family(pc, []);
      await pc.show(await pc.personal());
      final t = ok(await pc.tasks.create('Groceries'));
      await pc.syncPersonal();
      await phone.syncPersonal();
      expect((await phone.row('task', t))!['workspaceId'], await phone.personal());
      expect(await phone.spaceSync.refresh(), isNull);

      okShare(await pc.sharing.move(await pc.sharing.previewMove('task', t, ws)));
      await pc.syncPersonal();
      await pc.show(ws);
      await pc.syncSpace();

      await phone.show(ws);
      if (personalFirst) {
        await phone.syncPersonal();
        expect(await phone.row('task', t), isNull, reason: 'gone from personal');
        await phone.syncSpace();
      } else {
        final r = await phone.syncSpace();
        expect(r.notTaken, 1, reason: 'kept aside while it is still personal here');
        expect((await phone.row('task', t))!['workspaceId'], await phone.personal());
        await phone.syncPersonal();
        await phone.syncSpace();
      }
      expect((await phone.row('task', t))!['workspaceId'], ws, reason: 'personal first: $personalFirst');
      expect((await phone.row('task', t))!['deletedAt'], isNull);
    }
  });

  test('move back out: the mover keeps it, on every device; for the others it is a delete (B3)', () async {
    final lan = await device('lan');
    final phone = await device('lan');
    final minh = await device('minh');
    final ws = await family(lan, [(minh, SpaceRole.editor)]);
    expect(await phone.spaceSync.refresh(), isNull);
    await phone.show(ws);
    final t = ok(await minh.tasks.create('Minh\'s idea'));
    await minh.syncSpace();
    await lan.syncSpace();
    await phone.syncSpace();

    final out = await lan.sharing.previewMove('task', t, await lan.personal());
    okShare(await lan.sharing.move(out));
    expect((await lan.row('task', t))!['workspaceId'], await lan.personal());
    await lan.syncSpace();
    await lan.syncPersonal();
    await minh.syncSpace();
    expect((await minh.row('task', t))!['deletedAt'], isNotNull, reason: 'gone for the others');
    await phone.syncSpace();
    await phone.syncPersonal();
    final there = (await phone.row('task', t))!;
    expect((there['workspaceId'], there['deletedAt']), (await phone.personal(), null));
  });

  test('assign to an owner or an editor (B9); a viewer assigns nothing', () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final vy = await device('vy');
    final ws = await family(lan, [(minh, SpaceRole.editor), (vy, SpaceRole.viewer)]);
    final t = ok(await lan.tasks.create('Take out the bins'));
    okShare(await lan.sharing.assign(t, 'minh'));
    expect((await lan.sharing.assign(t, 'vy')).problem, SharingProblem.failed, reason: 'a viewer is not assigned');
    await lan.syncSpace();
    await vy.syncSpace();
    expect((await vy.sharing.assign(t, null)).problem, SharingProblem.notAllowed);
    // A viewer cannot move things out of the space either (B4).
    final out = await vy.sharing.previewMove('task', t, await vy.personal());
    expect(out.blocker, isNull);
    expect((await vy.sharing.move(out)).problem, SharingProblem.cannotMove);
    expect((await vy.row('task', t))!['workspaceId'], ws);
    await minh.syncSpace();
    expect((await minh.row('task', t))!['assigneeId'], 'minh');
    okShare(await minh.sharing.assign(t, null));
    expect(ws, isNotEmpty);
  });

  test('leaving rules (B8): disappear; export first, then let go; a read-only copy', () async {
    for (final rule in LeaveRule.values) {
      server = newServer();
      words.clear();
      final lan = await device('lan');
      final minh = await device('minh');
      final ws = await family(lan, [(minh, SpaceRole.editor)]);
      okShare(await lan.sharing.setRules(ws, SpaceRules(leave: rule)));
      final t = ok(await lan.tasks.create('Shared'));
      await lan.syncSpace();
      await minh.syncSpace();
      expect((await minh.sharing.rulesNotices()).map((n) => n.rules.leave),
          rule == LeaveRule.disappear ? isEmpty : [rule], reason: 'a change is a notice; the same rules are none');

      okShare(await minh.sharing.leave(ws));
      final listed = (await minh.spaces.spaces()).where((s) => s.shared).toList();
      switch (rule) {
        case LeaveRule.disappear:
          expect(listed, isEmpty);
          expect(await minh.row('task', t), isNull);
        case LeaveRule.disappearWithExport:
          expect(listed.single.left, SpaceLeft.exportFirst);
          final (file, problem) = await minh.sharing.exportSpace(ws);
          expect(problem, isNull);
          expect(file!.contents, contains('Shared'));
          okShare(await minh.sharing.forgetSpace(ws));
          expect(await minh.row('task', t), isNull);
          expect((await minh.spaces.spaces()).where((s) => s.shared), isEmpty);
        case LeaveRule.keepReadOnly:
          expect((listed.single.left, listed.single.isShown), (SpaceLeft.readOnly, true), reason: 'still shown, read only');
          expect((await minh.row('task', t))!['title'], 'Shared');
          expect(await minh.tasks.rename(t, 'Changed after leaving'), isA<CommandFailure>());
          expect((await minh.spaceSync.syncNow()).pushed, 0);
          okShare(await minh.sharing.forgetSpace(ws));
          expect(await minh.row('task', t), isNull);
      }
      expect(await minh.keyring.keyOf(ws), isNull, reason: '$rule: the key goes in every case');
    }
  });

  test('removed: no access, a new key; the removed device follows the rule; the owner leaves only after handing over',
      () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final vy = await device('vy');
    final ws = await family(lan, [(minh, SpaceRole.editor), (vy, SpaceRole.editor)]);
    final t = ok(await lan.tasks.create('Plan'));
    await lan.syncSpace();
    await vy.syncSpace();
    final oldKeyId = (await RecordSealer.of((await lan.keyring.keyOf(ws))!)).keyId;
    okShare(await lan.sharing.removeMember(ws, 'vy'));
    expect((await RecordSealer.of((await lan.keyring.keyOf(ws))!)).keyId, isNot(oldKeyId));
    expect(await lan.keyring.previousKeyOf(ws), isNull, reason: 'sealed again at once');
    expect(await vy.spaceSync.refresh(), isNull);
    expect(await vy.row('task', t), isNull, reason: 'the default rule: it disappears');
    await minh.syncSpace();
    expect((await minh.row('task', t))!['title'], 'Plan');

    expect((await lan.sharing.leave(ws)).problem, SharingProblem.ownerMustHandOver);
    okShare(await lan.sharing.handOver(ws, 'minh'));
    expect(await minh.spaceSync.refresh(), isNull);
    expect((await minh.spaces.spaces()).singleWhere((s) => s.shared).role, SpaceRole.owner);
    expect((await lan.spaces.spaces()).singleWhere((s) => s.shared).role, SpaceRole.editor);
    okShare(await minh.sharing.setRole(ws, 'lan', SpaceRole.viewer));
    expect(await lan.spaceSync.refresh(), isNull);
    expect(await lan.tasks.rename(t, 'As a viewer'), isA<CommandFailure>());
  });

  test('export by the export rule (B14); deleting the space for everyone', () async {
    final lan = await device('lan');
    final minh = await device('minh');
    final ws = await family(lan, [(minh, SpaceRole.editor)]);
    ok(await lan.tasks.create('Recipes'));
    await lan.syncSpace();
    await minh.syncSpace();
    expect((await minh.sharing.exportSpace(ws)).$2, SharingProblem.exportNotAllowed);
    final (own, why) = await lan.sharing.exportSpace(ws);
    expect(why, isNull);
    expect(own!.contents, contains('Recipes'));
    expect(own.suggestedName, startsWith('lifeflow-space-family-'));
    okShare(await lan.sharing.setRules(ws, const SpaceRules(export: ExportRule.everyMember)));
    expect(await minh.spaceSync.refresh(), isNull);
    expect((await minh.sharing.exportSpace(ws)).$2, isNull);
    expect((await minh.sharing.rulesNotices()).single.rules.export, ExportRule.everyMember);
    await minh.sharing.rulesSeen(ws);
    expect(await minh.sharing.rulesNotices(), isEmpty);

    expect((await minh.sharing.deleteSpace(ws)).problem, SharingProblem.notAllowed);
    okShare(await lan.sharing.deleteSpace(ws));
    expect((await lan.spaces.spaces()).where((s) => s.shared), isEmpty);
    expect(await minh.spaceSync.refresh(), isNull);
    expect((await minh.spaces.spaces()).where((s) => s.shared), isEmpty);
  });
}

/// P05b T6 steps 14, 29, 30: every file is "here"; its bytes are its hash.
class _HereFiles implements AttachmentService {
  @override
  Future<AttachmentAdded> add(Uint8List bytes, {required String name, required String mime}) async =>
      AttachmentAdded.ok(AttachmentRef(hash: attachmentHashOf(bytes), name: name, size: bytes.length, mime: mime));
  @override
  Future<AttachmentAvailability> availability(String hash) async => AttachmentAvailability.here;
  @override
  Future<AttachmentContent> open(String hash) async => AttachmentContent(AttachmentAvailability.here, Uint8List(1));
  @override
  Future<int> sweep({Duration grace = const Duration(days: 1)}) async => 0;
}

DocumentBody _text(String s) => DocumentBody([DocBlock('b1', BlockType.paragraph, runs: [TextRun(s)])]);

class _Utc implements DeviceTime {
  const _Utc();
  @override
  Instant now() => Instant.now();
  @override
  String zone() => 'UTC';
}
