// P04b T13 (ADR-0065; the owner's choice (b)): a member's name in a shared
// space, as a record of the space sealed with its key. Through the gateway
// like every change (FF-ARCH-06).
//
// Ops (payload['op']):
//   setName : id ('<space>:<account>'), accountId, name
//             the member themself, or the space's owner (who writes the
//             names of the people they approve, from the names sealed for
//             them; a viewer's device cannot write to the space)
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';

/// The longest name a member may have in a space.
const maxMemberNameLength = 60;

/// The id of [accountId]'s card in [spaceId].
String memberCardIdOf(String spaceId, String accountId) => '$spaceId:$accountId';

class MemberCardHandler implements CommandHandler {
  const MemberCardHandler();

  @override
  String get entityType => 'memberCard';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.memberCards)..where((c) => c.id.equals(cmd.payload['id'] as String))).getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    if (cmd.payload['op'] != 'setName') throw DomainRejection('unknown op: ${cmd.payload['op']}');
    final id = cmd.payload['id'] as String;
    final account = cmd.payload['accountId'] as String? ?? '';
    if (id != memberCardIdOf(cmd.workspaceId, account)) throw DomainRejection('a card is of one member of its space');
    final name = (cmd.payload['name'] as String? ?? '').trim();
    if (name.isEmpty || name.length > maxMemberNameLength) {
      throw DomainRejection('a name is 1 to $maxMemberNameLength characters');
    }
    if (cmd.actor.kind != ActorKind.member) throw DomainRejection('only a member names someone in a space');
    if (cmd.actor.id != account) {
      final me = await (db.select(db.spaceMembers)
            ..where((m) => m.workspaceId.equals(cmd.workspaceId) & m.accountId.equals(cmd.actor.id)))
          .getSingleOrNull();
      if (me?.role != 'owner') throw DomainRejection('only the owner names someone else');
    }
    final row = await (db.select(db.memberCards)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row?.displayName == name && row?.deletedAt == null) throw DomainRejection('already so');
    final now = DateTime.now().toUtc();
    await db.into(db.memberCards).insertOnConflictUpdate(MemberCardsCompanion.insert(
          id: id,
          workspaceId: cmd.workspaceId,
          ownerId: cmd.actor.id,
          createdAt: row?.createdAt ?? now,
          updatedAt: now,
          version: Value(newVersion.value),
          accountId: account,
          displayName: name,
          deletedAt: const Value(null),
        ));
    return HandlerOutcome(
      entityId: id,
      operationType: row == null ? 'create' : 'update',
      changeSet: {'id': id, 'name': true},
      events: [DomainEvent('MemberNamed', {'workspaceId': cmd.workspaceId})],
    );
  }
}

/// The names of [spaceId]'s members known here (their cards), by account.
Future<Map<String, String>> memberNamesOf(AppDatabase db, String spaceId) async => {
      for (final c in await (db.select(db.memberCards)
            ..where((c) => c.workspaceId.equals(spaceId) & c.deletedAt.isNull()))
          .get())
        c.accountId: c.displayName,
    };
