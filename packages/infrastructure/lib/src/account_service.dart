// P01 T6b: sign-in / bind / sign-out orchestration (ADR-0008, OQ-S7).
// The provider is reached only through AuthGateway; every local change goes
// through the command gateway (ADR-0011). Nothing here is on the data read
// path, so offline use never depends on it (LF-INV-SEC-002).
import 'package:application/application.dart';
import 'package:domain/domain.dart' show LocalProfile;
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'profile_command_handler.dart';
import 'profile_store.dart';

class DriftAccountService implements AccountService {
  DriftAccountService(this.db, this.gateway, this.auth) : _store = ProfileStore(db);

  final AppDatabase db;
  final CommandGateway gateway;
  final AuthGateway auth;
  final ProfileStore _store;
  final _handler = const ProfileCommandHandler();
  final _uuid = const Uuid();

  /// A signed-in session waiting for the move/new choice.
  AuthSession? _pending;

  @override
  bool get signInAvailable => auth.isConfigured;

  @override
  Future<SignInOutcome> signIn(SignInRequest request) async {
    if (!auth.isConfigured) {
      return const SignInFailed('Sign-in is not configured in this build.',
          kind: AuthFailureKind.notConfigured);
    }
    final AuthSession session;
    try {
      session = await auth.signIn(request);
    } on AuthFailure catch (f) {
      return SignInFailed(f.message, kind: f.kind);
    }

    final active = await _store.getActiveProfile();
    if (active == null) {
      await auth.signOut();
      return const SignInFailed('No local profile is open.');
    }

    // One account maps to one profile on this device: if it already owns a
    // profile, go there instead of binding it a second time.
    final owner = (await _store.listProfiles())
        .where((p) => p.binding?.accountId == session.accountId)
        .firstOrNull;
    if (owner != null) {
      if (owner.profileId != active.profileId) {
        final r = await _switch(owner);
        if (r is CommandFailure) return SignInFailed(_explain(r));
      }
      return SignedIn(await _activeView(), switchedProfile: owner.profileId != active.profileId);
    }

    // Already bound to a different account: that account keeps its profile and
    // this one signs in on a new profile (OQ-S7).
    if (active.isBound) {
      return _bind(active, session, hasData: true, moveData: false);
    }

    // Guest: an empty profile binds without asking (ADR-0008).
    if (!await _hasData(active)) {
      return _bind(active, session, hasData: false, moveData: true);
    }

    _pending = session;
    return NeedsBindChoice(provider: session.provider);
  }

  @override
  Future<SignInOutcome> completeBind({required bool moveData}) async {
    final session = _pending;
    if (session == null) {
      return const SignInFailed('There is no sign-in waiting for a choice.');
    }
    _pending = null;
    final active = await _store.getActiveProfile();
    if (active == null) return const SignInFailed('No local profile is open.');
    return _bind(active, session, hasData: true, moveData: moveData);
  }

  @override
  Future<void> cancelPendingBind() async {
    if (_pending == null) return;
    _pending = null;
    await auth.signOut();
  }

  @override
  Future<CommandResult> signOut() async {
    final active = await _store.getActiveProfile();
    if (active == null || !active.isBound) {
      return const CommandFailure(CommandFailureKind.validationFailed,
          reason: 'this profile is not signed in');
    }
    // Clear the provider session (tokens live only in secure storage), then
    // record the sign-out locally. Profiles and data stay (OQ-S7).
    await auth.signOut();
    return _run(active, 'SignOut', {'op': 'signOut', 'id': active.profileId.value});
  }

  // --- helpers --------------------------------------------------------------

  Future<SignInOutcome> _bind(LocalProfile profile, AuthSession session,
      {required bool hasData, required bool moveData}) async {
    final r = await _run(profile, 'BindAccount', {
      'op': 'bind',
      'id': profile.profileId.value,
      'accountId': session.accountId,
      'provider': session.provider,
      'hasData': hasData,
      'moveData': moveData,
    });
    if (r is CommandFailure) {
      // Do not leave a provider session that is bound to nothing.
      await auth.signOut();
      return SignInFailed(_explain(r));
    }
    final created = r is CommandOk && r.entityId != profile.profileId.value;
    return SignedIn(await _activeView(), switchedProfile: created);
  }

  Future<CommandResult> _switch(LocalProfile target) => _run(
      target, 'SwitchProfile', {'op': 'switch', 'id': target.profileId.value});

  Future<CommandResult> _run(
      LocalProfile profile, String type, Map<String, Object?> payload) async {
    final row = await (db.select(db.profiles)
          ..where((p) => p.id.equals(profile.profileId.value)))
        .getSingle();
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: type,
        payload: payload,
        expectedVersion: Version(row.version),
        issuedAt: Instant.now(),
      ),
      _handler,
    );
  }

  /// Any task in the profile's workspace, including trashed ones (they are
  /// still the user's data until purge).
  Future<bool> _hasData(LocalProfile p) async {
    final row = await (db.select(db.tasks)
          ..where((t) => t.workspaceId.equals(p.activeWorkspaceId.value))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<ProfileView> _activeView() async {
    final p = (await _store.getActiveProfile())!;
    return ProfileView(
      id: p.profileId.value,
      displayName: p.displayName,
      isActive: true,
      isBound: p.isBound,
      provider: p.binding?.provider.name,
    );
  }

  String _explain(CommandFailure f) =>
      f.reason == null ? 'The account could not be linked.' : 'The account could not be linked: ${f.reason}.';
}
