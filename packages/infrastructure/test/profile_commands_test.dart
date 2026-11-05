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

/// Owner-of-workspace policy (MVP): allow only the workspace owner.
class OwnerPolicy implements AuthorizationService {
  OwnerPolicy(this.ownerId);
  String ownerId;
  @override
  Future<String?> denyReason(ActorRef a, String action, ResourceRef r) async =>
      (a.kind == ActorKind.owner && a.id == ownerId) ? null : 'not the owner';
}

/// A fake AuthGateway standing in for Supabase. The session lives in memory
/// (= "secure storage"); currentSession() never does network I/O so it is safe
/// offline. [calls] records every invocation so a test can assert the read
/// path never touched it (LF-INV-SEC-002). The secret token is kept here only,
/// never handed to persistence (LF-INV-SEC-001).
class FakeAuthGateway implements AuthGateway {
  AuthSession? _session;
  String? _secretToken; // the thing that must never reach the DB
  final List<String> calls = [];

  @override
  Future<AuthSession> signIn(String provider) async {
    calls.add('signIn:$provider');
    _secretToken = 'tok_${DateTime.now().microsecondsSinceEpoch}';
    _session = AuthSession(
        accountId: 'acc-123', provider: provider, issuedAt: Instant.now());
    return _session!;
  }

  @override
  Future<AuthSession?> currentSession() async {
    calls.add('currentSession');
    return _session; // from cache, no network -> works offline
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _session = null;
    _secretToken = null;
  }

  String? get secretToken => _secretToken;
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
    final session = await auth.signIn('github'); // interactive sign-in

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

  test('guest -> bind (new session) isolates a fresh profile; old data stays (GS-22, ID-002)',
      () async {
    final guest = await store.ensureFirstProfile(displayName: 'Guest');
    // Give the guest some data so "hasData" is real.
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

    policy = OwnerPolicy(guest.profileId.value);
    gw = DriftCommandGateway(db, policy);
    final auth = FakeAuthGateway();
    final session = await auth.signIn('github');

    // User declined move -> a NEW isolated profile+workspace.
    final r = await gw.execute(
      c(guest.profileId.value, 'bind', {
        'accountId': session.accountId,
        'provider': session.provider,
        'hasData': true,
        'moveData': false,
      }, expected: Version.initial),
      handler,
    );
    expect(r, isA<CommandOk>(), reason: '$r');
    final newId = (r as CommandOk).entityId;
    expect(newId, isNot(guest.profileId.value)); // a NEW id

    // Two profiles now exist; the guest's and the new bound one.
    final profiles = await store.listProfiles();
    expect(profiles.length, 2);
    // The new profile is active and bound; the guest is untouched + not bound.
    final active = await store.getActiveProfile();
    expect(active!.profileId.value, newId);
    expect(active.isBound, isTrue);
    // The guest's data is still there, under the guest's workspace (ID-002).
    final guestTasks = await db.searchTaskIds(guest.activeWorkspaceId.value, 'guest');
    expect(guestTasks, contains('task1'));
    // The new profile's workspace is a different id (isolation).
    final newWs = await store.getPersonalWorkspace(newId);
    expect(newWs!.workspaceId, isNot(guest.activeWorkspaceId));
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
    await auth.signIn('github');
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
    await auth.signIn('github');
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

  test('switch profile toggles the active one (profile chooser, OQ-S7)',
      () async {
    final a = await store.ensureFirstProfile(displayName: 'A');
    policy = OwnerPolicy(a.profileId.value);
    gw = DriftCommandGateway(db, policy);
    final auth = FakeAuthGateway();
    final s = await auth.signIn('github');
    // Create a second profile via a declined-move bind.
    final r = await gw.execute(
      c(a.profileId.value, 'bind', {
        'accountId': s.accountId, 'provider': s.provider,
        'hasData': true, 'moveData': false,
      }, expected: Version.initial),
      handler,
    );
    final bId = (r as CommandOk).entityId;
    expect((await store.getActiveProfile())!.profileId.value, bId);

    // Switch back to A.
    policy.ownerId = a.profileId.value;
    final aVersion = (await (db.select(db.profiles)
              ..where((p) => p.id.equals(a.profileId.value)))
            .getSingle())
        .version;
    final sw = await gw.execute(
      c(a.profileId.value, 'switch', const {}, expected: Version(aVersion)),
      handler,
    );
    expect(sw, isA<CommandOk>(), reason: '$sw');
    expect((await store.getActiveProfile())!.profileId, a.profileId);
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
