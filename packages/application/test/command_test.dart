import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

void main() {
  test('Command envelope carries idempotency + concurrency fields', () {
    final c = Command(
      operationId: 'op1',
      actor: const ActorRef(ActorKind.owner, 'owner1'),
      workspaceId: 'ws1',
      type: 'CreateTask',
      payload: const {'id': 't1', 'title': 'x'},
      expectedVersion: Version.initial,
      issuedAt: Instant.now(),
    );
    expect(c.operationId, 'op1');
    expect(c.actor.kind, ActorKind.owner);
    expect(c.expectedVersion, Version.initial);
  });

  test('CommandResult is a sealed Ok/Failure hierarchy', () {
    const ok = CommandOk('t1', Version.initial, []);
    const fail = CommandFailure(CommandFailureKind.versionConflict,
        currentVersion: Version(3));
    expect(ok, isA<CommandResult>());
    expect(fail.kind, CommandFailureKind.versionConflict);
    expect(fail.currentVersion, const Version(3));
  });

  test('Version increments monotonically', () {
    expect(Version.initial.value, 1);
    expect(Version.initial.next.value, 2);
    expect(Version.initial.next.next.value, 3);
  });
}
