// P01 T7d (ADR-0027): delete a profile from this device.
//   - only a profile that is not open; one profile always remains
//   - file, key and registry entry are all removed; other profiles untouched
//   - an interrupted delete is finished on the next open
import 'dart:io';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

void main() {
  late Directory base;
  late MemoryKeys keys;
  late ProfileDirectory dir;
  late TestHost host;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_delete_');
    keys = MemoryKeys();
    dir = await openDirectory(base, keys);
    host = TestHost(dir);
    await host.openActive();
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  Future<String> profileWithTask(String name) async {
    final p = await dir.createProfile(displayName: name);
    final store = await dir.openProfile(p.id);
    final db = store.db;
    final ws = (await db.select(db.workspaces).getSingle()).id;
    await DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)).execute(
        Command(
          operationId: 'op-$name',
          actor: ActorRef(ActorKind.owner, p.id),
          workspaceId: ws,
          type: 'CreateTask',
          payload: {'op': 'create', 'id': 'task-$name', 'title': '$name task'},
          issuedAt: Instant.now(),
        ),
        TaskCommandHandler());
    await db.close();
    return p.id;
  }

  List<String> filesOf(String id) => Directory('${base.path}${Platform.pathSeparator}profiles')
      .listSync()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.startsWith(id))
      .toList();

  test('removes the registry entry, the file and the key; others untouched',
      () async {
    final keep = await profileWithTask('Keep');
    final gone = await profileWithTask('Gone');
    final service = DirectoryProfileService(dir, host);

    final r = await service.delete(gone);
    expect(r, isA<CommandOk>(), reason: '$r');
    expect((await dir.list()).map((e) => e.id), isNot(contains(gone)));
    expect(filesOf(gone), isEmpty);
    expect(keys.values.containsKey(ProfileDirectory.profileKeyName(gone)), isFalse);

    // The other profile still opens with its data and key.
    expect(keys.values.containsKey(ProfileDirectory.profileKeyName(keep)), isTrue);
    final store = await dir.openProfile(keep);
    addTearDown(store.db.close);
    expect((await store.db.select(store.db.tasks).getSingle()).title, 'Keep task');
    // And the active one is still active.
    expect((await dir.active())!.id, host.currentId);
  });

  test('the open profile cannot be deleted', () async {
    final active = host.currentId!;
    final r = await DirectoryProfileService(dir, host).delete(active);
    expect((r as CommandFailure).kind, CommandFailureKind.policyDenied);
    expect(dir.profileFile(active).existsSync(), isTrue);
    expect((await dir.active())!.id, active);
  });

  test('an unknown profile is reported, not thrown', () async {
    final r = await DirectoryProfileService(dir, host).delete('nope');
    expect((r as CommandFailure).kind, CommandFailureKind.notFound);
  });

  test('a signed-out account profile can be deleted, and its account can '
      'sign in again to a fresh profile', () async {
    final svc = Services(host, FakeAuthGateway());
    final s = await svc.accounts.signIn(const OAuthSignIn('github'));
    if (s is NeedsBindChoice) await svc.accounts.completeBind(moveData: true);
    final accountProfile = host.currentId!;
    await svc.accounts.signOut(); // locked, guest is now open
    expect(host.currentId, isNot(accountProfile));

    final r = await DirectoryProfileService(dir, host).delete(accountProfile);
    expect(r, isA<CommandOk>(), reason: '$r');
    expect(await dir.findByAccount('acc-123'), isNull);
  });

  test('an interrupted delete is finished on the next open', () async {
    final gone = await profileWithTask('Gone');
    // Secure storage fails once while the key is removed (the app stops
    // here): the profile is already unlisted, the key is left behind.
    keys.failNextDelete = true;
    await expectLater(dir.deleteProfile(gone), throwsA(anything));
    expect((await dir.list()).map((e) => e.id), isNot(contains(gone)));
    expect(keys.values.containsKey(ProfileDirectory.profileKeyName(gone)), isTrue);

    await host.close();
    await dir.close();
    dir = await openDirectory(base, keys);
    host = TestHost(dir);
    await host.openActive();
    expect(filesOf(gone), isEmpty);
    expect(keys.values.containsKey(ProfileDirectory.profileKeyName(gone)), isFalse);
    expect((await dir.list()).map((e) => e.id), isNot(contains(gone)));
  });
}
