// P01 T6b: sign-in / bind / sign-out on the real store, gateway and the
// production authorization policy; only the identity provider is faked.
//   ADR-0008       empty guest binds without asking; guest with data must choose
//   LF-INV-ID-001  "move" keeps every profile, workspace and task id (GS-22)
//   LF-INV-ID-002  "new session" isolates; guest data stays, not visible (GS-22)
//   OQ-S7          sign-out keeps data; a different account gets its own profile;
//                  the same account returns to its own profile, never bound twice
//   LF-INV-SEC-001 no token in the DB
//   LF-INV-SEC-002 sign-in failure leaves local data fully usable
import 'package:application/application.dart';
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';

void main() {
  late AppDatabase db;
  late DriftCommandGateway gw;
  late FakeAuthGateway auth;
  late DriftAccountService accounts;
  late DriftTaskService tasks;
  late DriftTaskQueries queries;
  late DriftProfileService profiles;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    auth = FakeAuthGateway();
    accounts = DriftAccountService(db, gw, auth);
    tasks = DriftTaskService(db, gw);
    queries = DriftTaskQueries(db);
    profiles = DriftProfileService(db, gw);
    await ProfileStore(db).ensureFirstProfile(displayName: 'Guest');
  });
  tearDown(() => db.close());

  Future<List<String>> titles() async =>
      (await queries.watchTasks().first).map((t) => t.title).toList();

  const github = OAuthSignIn('github');

  test('empty guest binds in place without asking (ADR-0008)', () async {
    final before = (await profiles.active())!;
    final r = await accounts.signIn(github);
    expect(r, isA<SignedIn>());
    final s = r as SignedIn;
    expect(s.profile.id, before.id); // same profile
    expect(s.profile.isBound, isTrue);
    expect(s.profile.provider, 'github');
    expect(s.switchedProfile, isFalse);
    expect((await profiles.list()), hasLength(1));
  });

  test('guest with data must choose; "move" keeps every id (GS-22, ID-001)',
      () async {
    final guest = (await profiles.active())!;
    await tasks.create('Guest task');
    final taskIdsBefore =
        (await queries.watchTasks().first).map((t) => t.id).toList();
    final wsBefore = (await db.select(db.workspaces).get()).single.id;

    final r = await accounts.signIn(github);
    expect(r, isA<NeedsBindChoice>());
    // Nothing is bound until the user decides.
    expect((await profiles.active())!.isBound, isFalse);

    final done = await accounts.completeBind(moveData: true);
    expect(done, isA<SignedIn>());
    final after = (await profiles.active())!;
    expect(after.id, guest.id);
    expect(after.isBound, isTrue);
    expect((await db.select(db.workspaces).get()).single.id, wsBefore);
    expect((await queries.watchTasks().first).map((t) => t.id), taskIdsBefore);
  });

  test('"new session" isolates; the guest and its data stay (GS-22, ID-002)',
      () async {
    final guest = (await profiles.active())!;
    await tasks.create('Guest task');

    expect(await accounts.signIn(github), isA<NeedsBindChoice>());
    final r = await accounts.completeBind(moveData: false);
    expect(r, isA<SignedIn>());
    final s = r as SignedIn;
    expect(s.switchedProfile, isTrue);
    expect(s.profile.id, isNot(guest.id));
    expect(s.profile.isBound, isTrue);

    // The new account profile sees none of the guest's data.
    expect(await titles(), isEmpty);
    // The guest is still there, unbound, with its data.
    final all = await profiles.list();
    expect(all, hasLength(2));
    final g = all.firstWhere((p) => p.id == guest.id);
    expect(g.isBound, isFalse);
    await profiles.switchTo(guest.id);
    expect(await titles(), ['Guest task']);
  });

  test('cancelling the choice signs out and binds nothing', () async {
    await tasks.create('Guest task');
    expect(await accounts.signIn(github), isA<NeedsBindChoice>());
    await accounts.cancelPendingBind();
    expect(auth.calls.last, 'signOut');
    expect((await profiles.active())!.isBound, isFalse);
    expect(await accounts.completeBind(moveData: true), isA<SignInFailed>());
    expect(await titles(), ['Guest task']);
  });

  test('sign-out keeps the profile and its data (OQ-S7)', () async {
    await accounts.signIn(github);
    await tasks.create('Mine');
    final r = await accounts.signOut();
    expect(r, isA<CommandOk>(), reason: '$r');
    expect(auth.calls.last, 'signOut');
    final p = (await profiles.active())!;
    expect(p.isBound, isFalse);
    expect(await titles(), ['Mine']);
    expect(await profiles.list(), hasLength(1));
  });

  test('signing out a guest profile is refused, nothing changes', () async {
    final r = await accounts.signOut();
    expect(r, isA<CommandFailure>());
    expect(auth.calls, isEmpty);
  });

  test('the same account returns to its own profile, never bound twice',
      () async {
    final guest = (await profiles.active())!;
    await tasks.create('Guest task');
    await accounts.signIn(github);
    final created =
        (await accounts.completeBind(moveData: false) as SignedIn).profile;

    // Back on the guest, the same account signs in again.
    await profiles.switchTo(guest.id);
    final r = await accounts.signIn(github);
    expect(r, isA<SignedIn>());
    expect((r as SignedIn).profile.id, created.id);
    expect(r.switchedProfile, isTrue);
    final bound = (await profiles.list()).where((p) => p.isBound);
    expect(bound, hasLength(1)); // still exactly one profile for the account
  });

  test('a different account on a bound profile gets its own profile (OQ-S7)',
      () async {
    final first = (await accounts.signIn(github) as SignedIn).profile;
    await tasks.create('First account task');

    auth.accountId = 'acc-other';
    final r = await accounts.signIn(const EmailPasswordSignIn('b@example.com', 'pw'));
    expect(r, isA<SignedIn>());
    final second = (r as SignedIn).profile;
    expect(second.id, isNot(first.id));
    expect(second.provider, 'email');
    expect(await titles(), isEmpty); // isolated from the first account

    final all = await profiles.list();
    expect(all.firstWhere((p) => p.id == first.id).provider, 'github');
  });

  test('a provider failure is reported; local data stays usable (SEC-002)',
      () async {
    await tasks.create('Offline task');
    auth.failNext =
        const AuthFailure(AuthFailureKind.network, 'You appear to be offline.');
    final r = await accounts.signIn(github);
    expect(r, isA<SignInFailed>());
    expect((r as SignInFailed).kind, AuthFailureKind.network);
    // Nothing bound, and reads/writes still work.
    expect((await profiles.active())!.isBound, isFalse);
    expect(await tasks.create('Still works'), isA<CommandOk>());
    expect(await titles(), ['Offline task', 'Still works']);
  });

  test('an unconfigured build refuses sign-in without calling the provider',
      () async {
    final off = DriftAccountService(db, gw, FakeAuthGateway(isConfigured: false));
    expect(off.signInAvailable, isFalse);
    final r = await off.signIn(github);
    expect((r as SignInFailed).kind, AuthFailureKind.notConfigured);
  });

  test('no token ever reaches the database (SEC-001)', () async {
    await tasks.create('x');
    await accounts.signIn(github);
    await accounts.completeBind(moveData: true);
    final token = auth.secretToken!;
    final dump = StringBuffer()
      ..write(await db.select(db.profiles).get())
      ..write(await db.select(db.auditLog).get())
      ..write(await db.select(db.outbox).get())
      ..write(await db.select(db.eventLog).get())
      ..write(await db.select(db.opDedupe).get());
    expect(dump.toString().contains(token), isFalse);
  });

  test('every account change is audited (ADR-0011)', () async {
    await accounts.signIn(github);
    await accounts.signOut();
    final actions = (await db.select(db.auditLog).get()).map((a) => a.action);
    expect(actions, containsAll(['BindAccount', 'SignOut']));
  });
}
