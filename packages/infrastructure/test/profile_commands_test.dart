// P01 T4 integration: Workspace + guest profile + account binding through the
// real Drift store and gateway. Acceptance tied to:
//   LF-INV-WA-001  one active Personal Workspace per profile
//   LF-INV-ID-001  bind (move) keeps every id (GS-22)
//   LF-INV-ID-002  declined move isolates a new profile; cross-profile denied
//                  (GS-11, GS-22)
//   LF-INV-SEC-001 no token/secret in the DB (GS-22 "no token in logs")
//   LF-INV-SEC-002 offline read path never calls AuthGateway (GS-22 airplane)
//   OQ-S7          sign-out keeps all profiles + data on the device
import 'package:application/application.dart';
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';

/// Owner-of-workspace policy (MVP): allow only the workspace owner.
class OwnerPolicy implements AuthorizationService {
  OwnerPolicy(this.ownerId);
  String ownerId;
  @override
  Future<String?> denyReason(ActorRef a, String action, ResourceRef r) async =>
      (a.kind == ActorKind.owner && a.id == ownerId) ? null : 'not the owner';
}

void main() {
  late AppDatabase db;
  late DriftCommandGateway gw;
  late ProfileStore store;
  late OwnerPolicy policy;
  final handler = const ProfileCommandHandler();
  var seq = 0;

  Command c(String profileId, String op, Map<String, Object?> payload,
          {Version? expected, ActorRef? actor}) =>
      Command(
        operationId: 'op${seq++}',
        actor: actor ?? ActorRef(ActorKind.owner, profileId),
        workspaceId: profileId, // owner policy scopes by the profile/owner id
        type: op,
        payload: {'op': op, 'id': profileId, ...payload},
        expectedVersion: expected,
        issuedAt: Instant.now(),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = ProfileStore(db);
    seq = 0;
  });
  tearDown(() => db.close());

  test('first launch creates one profile + one Personal Workspace (WA-001)',
      () async {
    final p = await store.ensureFirstProfile(displayName: 'Me');
    expect(p.displayName, 'Me');
    // Exactly one workspace, owned by the profile.
    final ws = await store.getPersonalWorkspace(p.profileId.value);
    expect(ws, isNotNull);
    expect(ws!.ownerId, p.profileId.value);
    expect(ws.kind, 'personal');
    expect((await db.select(db.workspaces).get()).length, 1);
    // Idempotent: a second call returns the same profile, no duplicate.
    final again = await store.ensureFirstProfile();
    expect(again.profileId, p.profileId);
    expect((await db.select(db.profiles).get()).length, 1);
  });

  test('guest -> bind (move) keeps every id; no token in DB (GS-22, ID-001, SEC-001)',
      () async {
    final guest = await store.ensureFirstProfile();
    policy = OwnerPolicy(guest.profileId.value);
    gw = DriftCommandGateway(db, policy);

    final auth = FakeAuthGateway();
    final session = await auth.signIn(const OAuthSignIn('github')); // interactive sign-in

    // Bind in place (user chose "move my data"): preserves ids (LF-INV-ID-001).
    final r = await gw.execute(
      c(guest.profileId.value, 'bind', {
        'accountId': session.accountId,
        'provider': session.provider,
        'hasData': true,
        'moveData': true,
      }, expected: Version.initial),
      handler,
    );
    expect(r, isA<CommandOk>(), reason: '$r');
    expect((r as CommandOk).entityId, guest.profileId.value); // SAME id

    final bound = await store.getActiveProfile();
    expect(bound!.profileId, guest.profileId); // unchanged
    expect(bound.activeWorkspaceId, guest.activeWorkspaceId); // unchanged
    expect(bound.isBound, isTrue);
    expect(bound.binding!.accountId, 'acc-123');

    // SEC-001: the secret token never reaches the DB. Scan every table's bytes.
    final token = auth.secretToken!;
    final dump = await _dumpAllRows(db);
    expect(dump.contains(token), isFalse,
        reason: 'auth token must never be persisted (LF-INV-SEC-001)');
    expect((await db.select(db.profiles).get()).length, 1); // still one profile
  });

  test('a "new space" can never be created inside this store (SR-03)',
      () async {
    final guest = await store.ensureFirstProfile(displayName: 'Guest');
    final taskGw = DriftCommandGateway(db, OwnerPolicy(guest.profileId.value));
    await taskGw.execute(
      Command(
        operationId: 'seed1',
        actor: ActorRef(ActorKind.owner, guest.profileId.value),
        workspaceId: guest.activeWorkspaceId.value,
        type: 'create',
        payload: {'op': 'create', 'id': 'task1', 'title': 'guest task'},
        issuedAt: Instant.now(),
      ),
      TaskCommandHandler(),
    );
    gw = DriftCommandGateway(db, OwnerPolicy(guest.profileId.value));

    // Declined move with data -> ProfileBinder decides on a NEW profile. In a
    // per-profile store that must be refused, not written next to the guest.
    final r = await gw.execute(
      c(guest.profileId.value, 'bind', {
        'accountId': 'acc-123',
        'provider': 'github',
        'hasData': true,
        'moveData': false,
      }, expected: Version.initial),
      handler,
    );
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
    expect(r.reason, contains('own store'));
    // Nothing written: still one profile, one workspace, guest unbound.
    expect(await db.select(db.profiles).get(), hasLength(1));
    expect(await db.select(db.workspaces).get(), hasLength(1));
    expect((await store.getActiveProfile())!.isBound, isFalse);
  });

  test('the removed "switch" op is rejected (switching is device-level now)',
      () async {
    final a = await store.ensureFirstProfile();
    gw = DriftCommandGateway(db, OwnerPolicy(a.profileId.value));
    final r = await gw.execute(
        c(a.profileId.value, 'switch', const {}, expected: Version.initial),
        handler);
    expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
  });
  test('cross-profile command is denied; no data crosses (GS-11, ID-002)', () async {
    final a = await store.ensureFirstProfile(); // profile A owns workspace A
    policy = OwnerPolicy(a.profileId.value);
    gw = DriftCommandGateway(db, policy);
    // An actor who is NOT the owner of A's workspace tries to bind A.
    final r = await gw.execute(
      c(a.profileId.value, 'bind', {
        'accountId': 'x', 'provider': 'github', 'hasData': false, 'moveData': false,
      }, actor: const ActorRef(ActorKind.owner, 'intruder'), expected: Version.initial),
      handler,
    );
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
    // A stays unbound; nothing crossed.
    final still = await store.getActiveProfile();
    expect(still!.isBound, isFalse);
  });

  test('sign-out clears the binding but keeps all profiles + data (OQ-S7)',
      () async {
    final guest = await store.ensureFirstProfile();
    policy = OwnerPolicy(guest.profileId.value);
    gw = DriftCommandGateway(db, policy);
    final auth = FakeAuthGateway();
    await auth.signIn(const OAuthSignIn('github'));
    await gw.execute(
      c(guest.profileId.value, 'bind',
          {'accountId': 'acc-123', 'provider': 'github', 'hasData': false, 'moveData': false},
          expected: Version.initial),
      handler,
    );
    // Sign out: the token cache is cleared via AuthGateway; the profile stays.
    await auth.signOut();
    final boundVersion = (await (db.select(db.profiles)
              ..where((p) => p.id.equals(guest.profileId.value)))
            .getSingle())
        .version;
    final r = await gw.execute(
      c(guest.profileId.value, 'signOut', const {},
          expected: Version(boundVersion)),
      handler,
    );
    expect(r, isA<CommandOk>(), reason: '$r');
    // Profile still present (data stays); just no longer bound.
    final after = await store.getActiveProfile();
    expect(after, isNotNull);
    expect(after!.isBound, isFalse);
    expect(await auth.currentSession(), isNull);
    expect(auth.calls.contains('signOut'), isTrue);
  });

  test('read path works offline and never calls the AuthGateway (SEC-002)',
      () async {
    final auth = FakeAuthGateway();
    await auth.signIn(const OAuthSignIn('github'));
    auth.calls.clear(); // forget the sign-in call; watch only the read path

    final p = await store.ensureFirstProfile();
    // Simulate the whole active-profile read path used by the UI on launch.
    final active = await store.getActiveProfile();
    final profiles = await store.listProfiles();
    final ws = await store.getPersonalWorkspace(p.profileId.value);

    expect(active, isNotNull);
    expect(profiles, isNotEmpty);
    expect(ws, isNotNull);
    // The data read path touched the AuthGateway zero times (LF-INV-SEC-002).
    expect(auth.calls, isEmpty,
        reason: 'the data read path must never call AuthGateway');
    // And the cached session is still readable with no network (offline-safe).
    expect(await auth.currentSession(), isNotNull);
  });
}

/// Concatenate the textual content of every table so a test can assert a secret
/// substring (an auth token) does not appear anywhere in the database.
Future<String> _dumpAllRows(AppDatabase db) async {
  final buf = StringBuffer();
  buf.writeln((await db.select(db.profiles).get()).toString());
  buf.writeln((await db.select(db.workspaces).get()).toString());
  buf.writeln((await db.select(db.auditLog).get()).toString());
  buf.writeln((await db.select(db.outbox).get()).toString());
  buf.writeln((await db.select(db.eventLog).get()).toString());
  buf.writeln((await db.select(db.opDedupe).get()).toString());
  return buf.toString();
}
