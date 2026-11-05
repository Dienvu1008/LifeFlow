import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:application/application.dart';

import 'app_database.dart';
import 'command_gateway.dart';

/// Applies profile/account commands within the gateway transaction (T4).
/// Enforces the guest-first bind-or-new rule (ADR-0008) via [ProfileBinder]
/// so binding never re-keys an entity (LF-INV-ID-001) and a declined move
/// yields an isolated new profile (LF-INV-ID-002).
///
/// Supported ops (payload['op']):
///   bind     : id (profileId), accountId, provider, moveData(bool), hasData(bool)
///   signOut  : id (profileId)
///   switch   : id (profileId to activate)
///
/// CreateLocalProfile is a pre-account bootstrap handled by ProfileStore, not
/// here (no actor/authorization exists at first launch).
class ProfileCommandHandler implements CommandHandler {
  const ProfileCommandHandler({this.binder = const ProfileBinder()});

  final ProfileBinder binder;

  @override
  String get entityType => 'profile';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final id = cmd.payload['id'] as String;
    final row = await (db.select(db.profiles)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(
      TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = DateTime.now().toUtc();

    final row = await (db.select(db.profiles)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw DomainRejection('profile not found: $id');

    switch (op) {
      case 'bind':
        return _bind(db, cmd, row, newVersion, now);
      case 'signOut':
        return _signOut(db, cmd, row, newVersion, now);
      case 'switch':
        return _switch(db, cmd, row, newVersion, now);
      default:
        throw DomainRejection('unknown op: $op');
    }
  }

  Future<HandlerOutcome> _bind(AppDatabase db, Command cmd, Profile row,
      Version newVersion, DateTime now) async {
    final profile = _toDomain(row);
    final binding = AccountBinding(
      accountId: cmd.payload['accountId'] as String,
      provider: AccountProvider.fromName(cmd.payload['provider'] as String),
      boundAt: Instant(now),
    );
    final hasData = cmd.payload['hasData'] as bool? ?? false;
    final moveData = cmd.payload['moveData'] as bool? ?? false;

    final BindDecision decision;
    try {
      decision = binder.decide(
        profile: profile,
        hasData: hasData,
        moveData: moveData,
        binding: binding,
      );
    } on ArgumentError catch (e) {
      throw DomainRejection(e.message as String);
    }

    switch (decision) {
      case BindInPlace(:final binding):
        // Bind the current profile WITHOUT changing any id (LF-INV-ID-001).
        await (db.update(db.profiles)..where((p) => p.id.equals(row.id))).write(
          ProfilesCompanion(
            accountId: Value(binding.accountId),
            accountProvider: Value(binding.provider.name),
            version: Value(newVersion.value),
          ),
        );
        return HandlerOutcome(
          entityId: row.id, // same id
          operationType: 'update',
          changeSet: {
            'id': row.id,
            'accountId': binding.accountId,
            'provider': binding.provider.name,
            'moveData': true,
          },
          events: [
            DomainEvent('ProfileBoundToAccount',
                {'profileId': row.id, 'provider': binding.provider.name})
          ],
        );

      case CreateNewBoundProfile(
          :final newProfileId,
          :final newWorkspaceId,
          :final binding
        ):
        // Declined move: a fresh, isolated profile+workspace is bound; the
        // original profile and its data stay untouched (LF-INV-ID-002).
        await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
              id: newWorkspaceId.value,
              ownerId: newProfileId.value,
              createdAt: now,
            ));
        // The new bound profile becomes active; the old one is deactivated.
        await db.update(db.profiles).write(
            const ProfilesCompanion(isActive: Value(false)));
        await db.into(db.profiles).insert(ProfilesCompanion.insert(
              id: newProfileId.value,
              activeWorkspaceId: newWorkspaceId.value,
              accountId: Value(binding.accountId),
              accountProvider: Value(binding.provider.name),
              isActive: const Value(true),
              createdAt: now,
            ));
        return HandlerOutcome(
          entityId: newProfileId.value, // a NEW id — original is untouched
          operationType: 'create',
          changeSet: {
            'id': newProfileId.value,
            'workspaceId': newWorkspaceId.value,
            'accountId': binding.accountId,
            'provider': binding.provider.name,
            'moveData': false,
          },
          events: [
            DomainEvent('ProfileCreated', {'profileId': newProfileId.value}),
            DomainEvent('ProfileBoundToAccount', {
              'profileId': newProfileId.value,
              'provider': binding.provider.name
            }),
          ],
        );
    }
  }

  Future<HandlerOutcome> _signOut(AppDatabase db, Command cmd, Profile row,
      Version newVersion, DateTime now) async {
    // OQ-S7: sign-out clears the binding reference on the profile; data stays.
    // (The cached session/token is cleared via AuthGateway.signOut outside the
    // transaction — tokens live in secure storage, never the DB.)
    await (db.update(db.profiles)..where((p) => p.id.equals(row.id))).write(
      ProfilesCompanion(
        accountId: const Value(null),
        accountProvider: const Value(null),
        version: Value(newVersion.value),
      ),
    );
    return HandlerOutcome(
      entityId: row.id,
      operationType: 'update',
      changeSet: {'id': row.id, 'signedOut': true},
      events: [DomainEvent('SignedOut', {'profileId': row.id})],
    );
  }

  Future<HandlerOutcome> _switch(AppDatabase db, Command cmd, Profile row,
      Version newVersion, DateTime now) async {
    await db.update(db.profiles).write(
        const ProfilesCompanion(isActive: Value(false)));
    await (db.update(db.profiles)..where((p) => p.id.equals(row.id))).write(
      ProfilesCompanion(
        isActive: const Value(true),
        version: Value(newVersion.value),
      ),
    );
    return HandlerOutcome(
      entityId: row.id,
      operationType: 'update',
      changeSet: {'id': row.id, 'active': true},
      events: const [],
    );
  }

  LocalProfile _toDomain(Profile row) => LocalProfile(
        profileId: EntityId(row.id),
        activeWorkspaceId: EntityId(row.activeWorkspaceId),
        displayName: row.displayName,
        binding: (row.accountId != null && row.accountProvider != null)
            ? AccountBinding(
                accountId: row.accountId!,
                provider: AccountProvider.fromName(row.accountProvider!),
                boundAt: Instant(row.createdAt),
              )
            : null,
      );
}
