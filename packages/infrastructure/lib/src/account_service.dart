// P01 T6b/T6c: sign-in / bind / sign-out orchestration (ADR-0008, OQ-S7,
// ADR-0024) over per-profile stores (SR-03, ADR-0023).
//
// The provider is reached only through AuthGateway; every change to profile
// data goes through the command gateway of THAT profile's store (ADR-0011).
// Cross-store steps follow the ADR-0023 order: registry intent -> store
// commit -> registry sync. Nothing here is on the data read path
// (LF-INV-SEC-002).
import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart' hide Workspace;
import 'app_service_impl.dart' show WorkspaceOwnerAuthorization;
import 'command_gateway.dart';
import 'profile_command_handler.dart';
import 'profile_directory.dart';
import 'profile_store.dart';

/// Switches the running app to another profile: closes the current store and
/// opens the target's (the app shell implements this). After [activate]
/// returns, services bound to the previous store must not be used again.
abstract interface class ProfileHost {
  /// [showProfiles] opens the profile chooser instead of the task list
  /// (after a sign-out, OQ-S7).
  Future<void> activate(String profileId, {bool showProfiles = false});
}

ProfileView profileViewOf(ProfileEntry e, {bool? active}) => ProfileView(
      id: e.id,
      displayName: e.displayName,
      isActive: active ?? e.isActive,
      isBound: e.isBound,
      provider: e.provider,
      isSignedOut: e.signedOut,
    );

/// Profile chooser over the device registry (OQ-S7).
class DirectoryProfileService implements ProfileService {
  DirectoryProfileService(this.directory, this.host);
  final ProfileDirectory directory;
  final ProfileHost host;

  @override
  Future<ProfileView?> active() async {
    final e = await directory.active();
    return e == null ? null : profileViewOf(e);
  }

  @override
  Future<List<ProfileView>> list() async =>
      [for (final e in await directory.list()) profileViewOf(e)];

  @override
  Future<CommandResult> switchTo(String profileId) async {
    final all = await directory.list();
    final target = all.where((e) => e.id == profileId).firstOrNull;
    if (target == null) {
      return const CommandFailure(CommandFailureKind.notFound,
          reason: 'profile not found');
    }
    if (target.isLocked) {
      // ADR-0024: only its account signing in again may open it.
      return const CommandFailure(CommandFailureKind.policyDenied,
          reason: 'sign in with this account to open it');
    }
    if (!target.isActive) {
      await directory.setActive(profileId);
      await host.activate(profileId);
    }
    return CommandOk(profileId, Version.initial, const []);
  }
}

class DriftAccountService implements AccountService {
  /// [db]/[gateway] belong to the ACTIVE profile's store.
  DriftAccountService({
    required this.db,
    required this.gateway,
    required this.auth,
    required this.directory,
    required this.host,
  }) : _store = ProfileStore(db);

  final AppDatabase db;
  final CommandGateway gateway;
  final AuthGateway auth;
  final ProfileDirectory directory;
  final ProfileHost host;
  final ProfileStore _store;
  final _handler = const ProfileCommandHandler();
  final _binder = const ProfileBinder();
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

    // One account maps to one profile on this device. If it already owns a
    // profile, go back to it (unlocking it if it was signed out, ADR-0024)
    // instead of binding the account a second time.
    final owner = await directory.findByAccount(session.accountId);
    if (owner != null) {
      if (owner.id == active.profileId.value) {
        return SignedIn(profileViewOf(owner, active: true));
      }
      if (owner.isLocked) {
        final r = await _resume(owner.id, session.accountId);
        if (r is CommandFailure) {
          await auth.signOut();
          return SignInFailed(_explain(r));
        }
      }
      return _activate(owner.id);
    }

    // Bound to a different (signed-in) account: that account keeps its
    // profile and this one signs in on a new profile (OQ-S7).
    if (active.isBound) return _newSpace(active, session);

    // Guest: an empty profile binds without asking (ADR-0008).
    if (!await _hasData(active)) {
      return _bindHere(active, session, hasData: false);
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
    return moveData
        ? _bindHere(active, session, hasData: true)
        : _newSpace(active, session);
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
    if (active == null || !active.isBound || active.isLocked) {
      return const CommandFailure(CommandFailureKind.validationFailed,
          reason: 'this profile is not signed in');
    }
    // Clear the provider session (tokens live only in secure storage), then
    // lock the profile in its own store, then leave it.
    await auth.signOut();
    return _lockAndLeave(active);
  }

  /// The provider ended the session on its own while online (ADR-0024).
  /// Locks the active profile like a sign-out. No-op for a guest.
  Future<void> handleSessionRevoked() async {
    final active = await _store.getActiveProfile();
    if (active == null || !active.isBound || active.isLocked) return;
    await _lockAndLeave(active);
  }

  // --- helpers --------------------------------------------------------------

  /// ADR-0024: keep the binding, lock the profile, move to a guest profile and
  /// the profile chooser. Data stays (OQ-S7).
  Future<CommandResult> _lockAndLeave(LocalProfile active) async {
    final id = active.profileId.value;
    await directory.beginStoreChange(id);
    final r = await _run(db, gateway, active, 'SignOut', {'op': 'signOut', 'id': id});
    await directory.syncFromStore(id, db);
    if (r is CommandFailure) return r;
    final guest = await directory.activateGuest();
    // This service's store is closed after this call.
    await host.activate(guest.id, showProfiles: true);
    return r;
  }

  /// Unlocks a signed-out profile in ITS store (not the active one).
  Future<CommandResult> _resume(String profileId, String accountId) async {
    final opened = await directory.openProfile(profileId);
    final ownerDb = opened.db;
    try {
      final owner = (await ProfileStore(ownerDb).getActiveProfile())!;
      await directory.beginStoreChange(profileId);
      final r = await _run(
        ownerDb,
        DriftCommandGateway(ownerDb, WorkspaceOwnerAuthorization(ownerDb)),
        owner,
        'ResumeSession',
        {'op': 'resume', 'id': profileId, 'accountId': accountId},
      );
      await directory.syncFromStore(profileId, ownerDb);
      return r;
    } finally {
      await ownerDb.close();
    }
  }

  /// "Move my data" (or an empty guest): bind THIS profile, no id changes.
  Future<SignInOutcome> _bindHere(LocalProfile profile, AuthSession session,
      {required bool hasData}) async {
    final id = profile.profileId.value;
    await directory.beginStoreChange(id);
    final r = await _run(db, gateway, profile, 'BindAccount', {
      'op': 'bind',
      'id': id,
      'accountId': session.accountId,
      'provider': session.provider,
      'hasData': hasData,
      'moveData': true,
    });
    await directory.syncFromStore(id, db);
    if (r is CommandFailure) {
      await auth.signOut(); // never leave a session bound to nothing
      return SignInFailed(_explain(r));
    }
    final entry = (await directory.active())!;
    return SignedIn(profileViewOf(entry));
  }

  /// "New space": a NEW profile in its OWN store (SR-03), bound to the
  /// account; the current profile and its data stay untouched (LF-INV-ID-002).
  Future<SignInOutcome> _newSpace(LocalProfile current, AuthSession session) async {
    final binding = AccountBinding(
      accountId: session.accountId,
      provider: AccountProvider.fromName(session.provider),
      boundAt: Instant.now(),
    );
    final decision = _binder.decide(
        profile: current, hasData: true, moveData: false, binding: binding);
    if (decision is! CreateNewBoundProfile) {
      await auth.signOut();
      return const SignInFailed('The account could not be linked.');
    }

    final entry = await directory.createProfile(
        profileId: decision.newProfileId, workspaceId: decision.newWorkspaceId);
    final opened = await directory.openProfile(entry.id);
    final newDb = opened.db;
    try {
      final created = (await ProfileStore(newDb).getActiveProfile())!;
      await directory.beginStoreChange(entry.id);
      final r = await _run(
        newDb,
        DriftCommandGateway(newDb, WorkspaceOwnerAuthorization(newDb)),
        created,
        'BindAccount',
        {
          'op': 'bind',
          'id': entry.id,
          'accountId': session.accountId,
          'provider': session.provider,
          'hasData': false,
          'moveData': true,
        },
      );
      await directory.syncFromStore(entry.id, newDb);
      if (r is CommandFailure) {
        await auth.signOut();
        return SignInFailed(_explain(r));
      }
    } finally {
      await newDb.close();
    }
    return _activate(entry.id);
  }

  Future<SignInOutcome> _activate(String profileId) async {
    await directory.setActive(profileId);
    final entry = (await directory.active())!;
    await host.activate(profileId); // this service's store is closed after this
    return SignedIn(profileViewOf(entry), switchedProfile: true);
  }

  Future<CommandResult> _run(AppDatabase store, CommandGateway gw,
      LocalProfile profile, String type, Map<String, Object?> payload) async {
    final row = await (store.select(store.profiles)
          ..where((p) => p.id.equals(profile.profileId.value)))
        .getSingle();
    return gw.execute(
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

  String _explain(CommandFailure f) => f.reason == null
      ? 'The account could not be linked.'
      : 'The account could not be linked: ${f.reason}.';
}
