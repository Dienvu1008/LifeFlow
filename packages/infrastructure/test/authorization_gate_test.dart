@Tags(['ff-arch-09'])
library;

// FF-ARCH-09 (LF-INV-GOV-002, GS-11): every mutation is authorized BEFORE the
// domain method runs. A spy handler proves a denied command never reaches the
// handler (not even its read), for every kind of denial, and that the check is
// made against the command's workspace and entity type.
import 'package:application/application.dart';
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

class _SpyHandler implements CommandHandler {
  final calls = <String>[];
  @override
  String get entityType => 'spy';
  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    calls.add('currentVersion');
    return null;
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version v) async {
    calls.add('apply');
    return HandlerOutcome(
        entityId: 'x', operationType: 'create', changeSet: const {}, events: const []);
  }
}

class _RecordingPolicy implements AuthorizationService {
  _RecordingPolicy(this.inner, this.log);
  final AuthorizationService inner;
  final List<String> log;
  @override
  Future<String?> denyReason(ActorRef a, String action, ResourceRef r) {
    log.add('authorize:$action:${r.entityType}@${r.workspaceId}');
    return inner.denyReason(a, action, r);
  }
}

void main() {
  late AppDatabase db;
  late String owner;
  late String ws;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final p = await ProfileStore(db).ensureFirstProfile();
    owner = p.profileId.value;
    ws = p.activeWorkspaceId.value;
  });
  tearDown(() => db.close());

  Command cmd(ActorRef actor, {String? workspace, String id = 'op'}) => Command(
        operationId: id,
        actor: actor,
        workspaceId: workspace ?? ws,
        type: 'DoThing',
        payload: const {'id': 'e1'},
        issuedAt: Instant.now(),
      );

  Future<int> written() async =>
      (await db.select(db.auditLog).get()).length +
      (await db.select(db.outbox).get()).length +
      (await db.select(db.opDedupe).get()).length;

  final denials = <String, ActorRef Function(String owner)>{
    'a different owner': (_) => const ActorRef(ActorKind.owner, 'intruder'),
    'the AI assistant, even with the owner id': (o) => ActorRef(ActorKind.aiAssistant, o),
    'a provider': (o) => ActorRef(ActorKind.provider, o),
    'the sync engine': (o) => ActorRef(ActorKind.sync, o),
  };

  for (final d in denials.entries) {
    test('${d.key} is denied before the handler runs; nothing is written',
        () async {
      final spy = _SpyHandler();
      final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
      final r = await gw.execute(cmd(d.value(owner)), spy);
      expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
      expect(spy.calls, isEmpty,
          reason: 'the handler was reached by an unauthorized command');
      expect(await written(), 0);
    });
  }

  test('an unknown workspace is denied before the handler runs', () async {
    final spy = _SpyHandler();
    final r = await DriftCommandGateway(db, WorkspaceOwnerAuthorization(db))
        .execute(cmd(ActorRef(ActorKind.owner, owner), workspace: 'nope'), spy);
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
    expect(spy.calls, isEmpty);
  });

  test("another profile's workspace is denied even for a real owner (GS-11)",
      () async {
    final other = await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
        id: 'ws-other', ownerId: 'someone-else', createdAt: DateTime.now().toUtc()));
    expect(other, isPositive);
    final spy = _SpyHandler();
    final r = await DriftCommandGateway(db, WorkspaceOwnerAuthorization(db))
        .execute(cmd(ActorRef(ActorKind.owner, owner), workspace: 'ws-other'), spy);
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
    expect(spy.calls, isEmpty);
  });

  test('authorization is checked first, then the handler, in that order',
      () async {
    final log = <String>[];
    final spy = _SpyHandler();
    final gw = DriftCommandGateway(
        db, _RecordingPolicy(WorkspaceOwnerAuthorization(db), log));
    final r = await gw.execute(cmd(ActorRef(ActorKind.owner, owner)), spy);
    expect(r, isA<CommandOk>(), reason: '$r');
    expect(log, ['authorize:DoThing:spy@$ws']);
    expect(spy.calls, ['currentVersion', 'apply']); // only after authorization
  });

  test('a denied duplicate of an already-applied operation is still denied',
      () async {
    // First apply legitimately, then replay the same operationId as an intruder.
    final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    final spy = _SpyHandler();
    expect(await gw.execute(cmd(ActorRef(ActorKind.owner, owner), id: 'same'), spy),
        isA<CommandOk>());
    final replay =
        await gw.execute(cmd(const ActorRef(ActorKind.owner, 'intruder'), id: 'same'), spy);
    expect(replay, isA<CommandFailure>());
    expect(spy.calls, ['currentVersion', 'apply']); // no extra call
  });
}
