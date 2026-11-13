import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:application/application.dart';

import 'app_database.dart';
import 'command_gateway.dart';

/// Applies profile/account commands within the gateway transaction of ONE
/// profile store (T4, revised for SR-03 in T6c).
///
/// Since T6c each LocalProfile has its own database file (ADR-0023), so this
/// handler can only bind the profile that owns this store. When the guest-
/// first rule (ADR-0008) decides on a NEW profile ("new space"), the account
/// layer creates a separate store for it; a request that would put a second
/// profile into this store is rejected here, at the single mutation path.
///
/// Supported ops (payload['op']):
///   bind     : id (profileId), accountId, provider, moveData(bool), hasData(bool)
///   signOut  : id (profileId)            — keeps the binding, locks (ADR-0024)
///   resume   : id (profileId), accountId — unlock; only the owning account
///   setManualResults : id, value ('target' | 'tick') — P03 UX U6 (U-D13)
///
/// Switching profiles is a device-level registry change (ProfileDirectory),
/// not a mutation of profile data.
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
        return _signOut(db, row, newVersion);
      case 'resume':
        return _resume(db, cmd, row, newVersion);
      case 'setManualResults':
        final v = cmd.payload['value'];
        if (v != 'target' && v != 'tick') throw DomainRejection('unknown result policy');
        if (row.manualResults == v) throw DomainRejection('the result policy is already $v');
        await (db.update(db.profiles)..where((p) => p.id.equals(row.id)))
            .write(ProfilesCompanion(manualResults: Value(v as String), version: Value(newVersion.value)));
        return HandlerOutcome(
          entityId: row.id,
          operationType: 'update',
          changeSet: {'id': row.id, 'manualResults': v},
          events: [DomainEvent('ManualResultsChanged', {'profileId': row.id, 'value': v})],
        );
      default:
        throw DomainRejection('unknown op: $op');
    }
  }

  Future<HandlerOutcome> _bind(AppDatabase db, Command cmd, Profile row,
      Version newVersion, DateTime now) async {
    final binding = AccountBinding(
      accountId: cmd.payload['accountId'] as String,
      provider: AccountProvider.fromName(cmd.payload['provider'] as String),
      boundAt: Instant(now),
    );

    final BindDecision decision;
    try {
      decision = binder.decide(
        profile: _toDomain(row),
        hasData: cmd.payload['hasData'] as bool? ?? false,
        moveData: cmd.payload['moveData'] as bool? ?? false,
        binding: binding,
      );
    } on ArgumentError catch (e) {
      throw DomainRejection(e.message as String);
    }

    if (decision is! BindInPlace) {
      // SR-03: one profile per store. A new space must be its own store.
      throw DomainRejection('a new profile needs its own store (SR-03)');
    }

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
      },
      events: [
        DomainEvent('ProfileBoundToAccount',
            {'profileId': row.id, 'provider': binding.provider.name})
      ],
    );
  }

  Future<HandlerOutcome> _signOut(
      AppDatabase db, Profile row, Version newVersion) async {
    // ADR-0024: sign-out KEEPS the binding (the profile still belongs to its
    // account) and locks the profile until that account signs in again. Data
    // stays (OQ-S7). The cached session/token is cleared via
    // AuthGateway.signOut outside the transaction; tokens never touch the DB.
    if (row.accountId == null) {
      throw DomainRejection('this profile is not signed in');
    }
    if (row.signedOut) throw DomainRejection('this profile is already signed out');
    await (db.update(db.profiles)..where((p) => p.id.equals(row.id))).write(
      ProfilesCompanion(
        signedOut: const Value(true),
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

  /// ADR-0024: the account that owns a signed-out profile signed in again.
  Future<HandlerOutcome> _resume(AppDatabase db, Command cmd, Profile row,
      Version newVersion) async {
    final accountId = cmd.payload['accountId'] as String;
    if (!_toDomain(row).canResumeWith(accountId)) {
      throw DomainRejection(row.accountId == accountId
          ? 'this profile is not signed out'
          : 'this profile belongs to a different account');
    }
    await (db.update(db.profiles)..where((p) => p.id.equals(row.id))).write(
      ProfilesCompanion(
        signedOut: const Value(false),
        version: Value(newVersion.value),
      ),
    );
    return HandlerOutcome(
      entityId: row.id,
      operationType: 'update',
      changeSet: {'id': row.id, 'signedOut': false},
      events: [DomainEvent('SessionResumed', {'profileId': row.id})],
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
        signedOut: row.signedOut,
      );
}
