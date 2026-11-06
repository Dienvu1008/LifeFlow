// P01 T6b/T6c: sign-in / bind / sign-out over per-profile stores, with the
// real stores, gateway and authorization policy; only the provider is faked.
//   ADR-0008       empty guest binds without asking; guest with data must choose
//   LF-INV-ID-001  "move" keeps every profile, workspace and task id (GS-22)
//   LF-INV-ID-002  "new space" is a NEW FILE with its own key (SR-03); the
//                  guest's data stays in the guest's file (GS-22)
//   OQ-S7          sign-out keeps data; a different account gets its own
//                  profile; the same account returns to its profile
//   LF-INV-SEC-001 no token in any store
//   LF-INV-SEC-002 sign-in failure leaves local data fully usable
import 'dart:io';

import 'package:application/application.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

void main() {
  late Directory base;
  late MemoryKeys keys;
  late ProfileDirectory dir;
  late TestHost host;
  late FakeAuthGateway auth;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_acct_');
    keys = MemoryKeys();
    dir = await openDirectory(base, keys);
    host = TestHost(dir);
    await host.openActive();
    auth = FakeAuthGateway();
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  Services s() => Services(host, auth);
  const github = OAuthSignIn('github');

  test('empty guest binds in place without asking (ADR-0008)', () async {
    final before = host.currentId!;
    final r = await s().accounts.signIn(github);
    expect(r, isA<SignedIn>());
    final p = (r as SignedIn).profile;
    expect(p.id, before);
    expect(p.isBound, isTrue);
    expect(p.provider, 'github');
    expect(r.switchedProfile, isFalse);
    expect(host.activations, isEmpty);
    expect(await dir.list(), hasLength(1));
    expect((await dir.active())!.accountId, 'acc-123'); // registry in sync
  });

  test('guest with data must choose; "move" keeps every id (GS-22, ID-001)',
      () async {
    final svc = s();
    final guest = host.currentId!;
    await svc.tasks.create('Guest task');
    final taskIds = (await svc.queries.watchTasks().first).map((t) => t.id).toList();
    final ws = (await host.db.select(host.db.workspaces).get()).single.id;

    expect(await svc.accounts.signIn(github), isA<NeedsBindChoice>());
    expect((await dir.active())!.isBound, isFalse); // nothing bound yet

    expect(await svc.accounts.completeBind(moveData: true), isA<SignedIn>());
    expect(host.currentId, guest);
    expect((await dir.active())!.isBound, isTrue);
    expect((await host.db.select(host.db.workspaces).get()).single.id, ws);
    expect((await svc.queries.watchTasks().first).map((t) => t.id), taskIds);
  });

  test('"new space" is a new file + key; the guest file keeps its data (SR-03)',
      () async {
    final svc = s();
    final guest = host.currentId!;
    await svc.tasks.create('Guest task');

    expect(await svc.accounts.signIn(github), isA<NeedsBindChoice>());
    final r = await svc.accounts.completeBind(moveData: false);
    expect(r, isA<SignedIn>());
    final created = (r as SignedIn).profile;
    expect(r.switchedProfile, isTrue);
    expect(created.id, isNot(guest));
    expect(host.activations, [created.id]); // the app switched stores

    // Separate file and separate key.
    expect(dir.profileFile(created.id).existsSync(), isTrue);
    expect(keys.values[ProfileDirectory.profileKeyName(created.id)],
        isNot(keys.values[ProfileDirectory.profileKeyName(guest)]));
    // The new store holds exactly its own bound profile and no guest data.
    final now = s();
    expect(await now.titles(), isEmpty);
    expect((await host.db.select(host.db.profiles).get()).single.accountId, 'acc-123');
    expect(await host.db.select(host.db.auditLog).get(), hasLength(1)); // its bind

    // The guest is still listed, unbound, and its file still has its task.
    final all = await dir.list();
    expect(all, hasLength(2));
    expect(all.firstWhere((e) => e.id == guest).isBound, isFalse);
    await now.profiles.switchTo(guest);
    expect(await s().titles(), ['Guest task']);
  });

  test('cancelling the choice signs out and binds nothing', () async {
    final svc = s();
    await svc.tasks.create('Guest task');
    expect(await svc.accounts.signIn(github), isA<NeedsBindChoice>());
    await svc.accounts.cancelPendingBind();
    expect(auth.calls.last, 'signOut');
    expect((await dir.active())!.isBound, isFalse);
    expect(await svc.accounts.completeBind(moveData: true), isA<SignInFailed>());
    expect(await dir.list(), hasLength(1));
  });

  test('sign-out keeps the profile and its data (OQ-S7)', () async {
    final svc = s();
    await svc.accounts.signIn(github);
    await svc.tasks.create('Mine');
    expect(await svc.accounts.signOut(), isA<CommandOk>());
    expect(auth.calls.last, 'signOut');
    expect((await dir.active())!.isBound, isFalse);
    expect(await svc.titles(), ['Mine']);
    expect(await dir.list(), hasLength(1));
  });

  test('signing out a guest profile is refused, nothing changes', () async {
    expect(await s().accounts.signOut(), isA<CommandFailure>());
    expect(auth.calls, isEmpty);
  });

  test('the same account returns to its own profile, never bound twice',
      () async {
    final guest = host.currentId!;
    var svc = s();
    await svc.tasks.create('Guest task');
    await svc.accounts.signIn(github);
    final created =
        (await svc.accounts.completeBind(moveData: false) as SignedIn).profile;

    svc = s();
    await svc.profiles.switchTo(guest);
    svc = s();
    final r = await svc.accounts.signIn(github);
    expect(r, isA<SignedIn>());
    expect((r as SignedIn).profile.id, created.id);
    expect(r.switchedProfile, isTrue);
    expect(host.currentId, created.id);
    expect((await dir.list()).where((e) => e.isBound), hasLength(1));
  });

  test('a different account on a bound profile gets its own profile (OQ-S7)',
      () async {
    var svc = s();
    final first = (await svc.accounts.signIn(github) as SignedIn).profile;
    await svc.tasks.create('First account task');

    auth.accountId = 'acc-other';
    final r = await svc.accounts
        .signIn(const EmailPasswordSignIn('b@example.com', 'pw'));
    expect(r, isA<SignedIn>());
    final second = (r as SignedIn).profile;
    expect(second.id, isNot(first.id));
    expect(second.provider, 'email');
    svc = s();
    expect(await svc.titles(), isEmpty); // isolated store
    expect((await dir.list()).firstWhere((e) => e.id == first.id).provider, 'github');
  });

  test('a provider failure is reported; local data stays usable (SEC-002)',
      () async {
    final svc = s();
    await svc.tasks.create('Offline task');
    auth.failNext =
        const AuthFailure(AuthFailureKind.network, 'You appear to be offline.');
    final r = await svc.accounts.signIn(github);
    expect((r as SignInFailed).kind, AuthFailureKind.network);
    expect((await dir.active())!.isBound, isFalse);
    expect(await svc.tasks.create('Still works'), isA<CommandOk>());
    expect(await svc.titles(), ['Offline task', 'Still works']);
  });

  test('an unconfigured build refuses sign-in without calling the provider',
      () async {
    final off = Services(host, FakeAuthGateway(isConfigured: false));
    expect(off.accounts.signInAvailable, isFalse);
    final r = await off.accounts.signIn(github);
    expect((r as SignInFailed).kind, AuthFailureKind.notConfigured);
  });

  test('no token ever reaches any store or the registry file (SEC-001)',
      () async {
    final svc = s();
    await svc.tasks.create('x');
    await svc.accounts.signIn(github);
    await svc.accounts.completeBind(moveData: false); // two stores now
    final token = auth.secretToken!;
    await host.close();
    await dir.close();
    // Reopen everything plain-readable via the stores and dump all rows.
    dir = await openDirectory(base, keys);
    final buf = StringBuffer();
    for (final e in await dir.list()) {
      final db = (await dir.openProfile(e.id)).db;
      buf
        ..write(await db.select(db.profiles).get())
        ..write(await db.select(db.auditLog).get())
        ..write(await db.select(db.outbox).get())
        ..write(await db.select(db.eventLog).get())
        ..write(await db.select(db.opDedupe).get());
      await db.close();
    }
    buf.write(await dir.list());
    expect(buf.toString().contains(token), isFalse);
    host = TestHost(dir);
    await host.openActive();
  });

  test('every account change is audited in that profile\'s store', () async {
    final svc = s();
    await svc.accounts.signIn(github);
    await svc.accounts.signOut();
    final actions = (await host.db.select(host.db.auditLog).get()).map((a) => a.action);
    expect(actions, containsAll(['BindAccount', 'SignOut']));
  });
}
