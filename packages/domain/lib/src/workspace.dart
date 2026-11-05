// Workspace & Access domain (P01, T4). Pure: LocalProfile / Workspace /
// AccountBinding value objects and the guest-first binding rule (ADR-0008).
// No Flutter, no database, no auth SDK (FF-ARCH-01). The persistence shapes
// live in infrastructure/schema.dart; the auth port lives in application.
import 'package:foundation/foundation.dart';

/// Which identity provider an account binding came from (ADR-0003 / S-03a).
/// MVP supports email + GitHub; the string value is what we persist.
enum AccountProvider {
  email,
  github;

  static AccountProvider fromName(String v) =>
      AccountProvider.values.byName(v);
}

/// A LocalProfile may be bound to at most one cloud account (ADR-0008).
/// Binding carries identity only — never any secret (tokens stay in secure
/// storage, LF-INV-SEC-001). The [accountId] is the opaque provider id.
class AccountBinding {
  const AccountBinding({
    required this.accountId,
    required this.provider,
    required this.boundAt,
  });

  final String accountId; // opaque, from the auth provider
  final AccountProvider provider;
  final Instant boundAt;

  @override
  bool operator ==(Object other) =>
      other is AccountBinding &&
      other.accountId == accountId &&
      other.provider == provider;

  @override
  int get hashCode => Object.hash(accountId, provider);
}

/// The single Personal Workspace a profile owns in the MVP (LF-INV-WA-001).
/// [ownerId] is the owning profile's id; it is never re-keyed (LF-INV-ID-001).
class Workspace {
  const Workspace({
    required this.workspaceId,
    required this.ownerId,
    this.kind = 'personal',
  });

  final EntityId workspaceId;
  final String ownerId;
  final String kind; // 'personal' in MVP; 'shared' in P04

  @override
  bool operator ==(Object other) =>
      other is Workspace &&
      other.workspaceId == workspaceId &&
      other.ownerId == ownerId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(workspaceId, ownerId, kind);
}

/// A device-local profile. Exists from first launch with a stable [profileId]
/// and exactly one active Personal Workspace (LF-INV-WA-001). It may later be
/// bound to one account; binding does not change any id (LF-INV-ID-001).
class LocalProfile {
  const LocalProfile({
    required this.profileId,
    required this.activeWorkspaceId,
    this.displayName = '',
    this.binding,
  });

  final EntityId profileId;
  final EntityId activeWorkspaceId;
  final String displayName;
  final AccountBinding? binding;

  bool get isBound => binding != null;

  /// Bind an account to THIS profile without re-keying anything
  /// (LF-INV-ID-001). Returns a copy with the binding set; ids are preserved.
  LocalProfile boundTo(AccountBinding b) => LocalProfile(
        profileId: profileId, // unchanged
        activeWorkspaceId: activeWorkspaceId, // unchanged
        displayName: displayName,
        binding: b,
      );

  @override
  bool operator ==(Object other) =>
      other is LocalProfile &&
      other.profileId == profileId &&
      other.activeWorkspaceId == activeWorkspaceId &&
      other.displayName == displayName &&
      other.binding == binding;

  @override
  int get hashCode =>
      Object.hash(profileId, activeWorkspaceId, displayName, binding);
}

/// What to do when an account signs in from a given profile.
sealed class BindDecision {
  const BindDecision();
}

/// Bind the current profile in place. No id is copied or re-keyed
/// (ADR-0008 "Yes, move my data"; LF-INV-ID-001). Used when the profile is
/// empty (auto) or the user chose "move".
class BindInPlace extends BindDecision {
  const BindInPlace(this.binding);
  final AccountBinding binding;
}

/// Create a new, isolated profile+workspace for the account; the previous
/// profile and its data stay on the device untouched (ADR-0008 "No, new
/// session"). The new space has fresh ids so profiles stay isolated
/// (LF-INV-ID-002).
class CreateNewBoundProfile extends BindDecision {
  const CreateNewBoundProfile({
    required this.newProfileId,
    required this.newWorkspaceId,
    required this.binding,
  });
  final EntityId newProfileId;
  final EntityId newWorkspaceId;
  final AccountBinding binding;
}

/// Applies the guest-first bind-or-new rule (ADR-0008). This is the pure
/// decision; the command handler persists the result transactionally.
class ProfileBinder {
  const ProfileBinder();

  /// Decide how to bind [binding] to [profile].
  ///
  /// - Empty profile (no data): bind in place without asking (ADR-0008).
  /// - Profile with data: the UI must have asked the user; [moveData] carries
  ///   the answer. true -> bind in place (keep every id); false -> a new
  ///   isolated profile, generating [newProfileId]/[newWorkspaceId].
  ///
  /// Throws [ArgumentError] if a profile is already bound (at most one account
  /// per profile, ADR-0008) — the caller should start a new profile instead.
  BindDecision decide({
    required LocalProfile profile,
    required bool hasData,
    required bool moveData,
    required AccountBinding binding,
    EntityId? newProfileId,
    EntityId? newWorkspaceId,
  }) {
    if (profile.isBound) {
      throw ArgumentError('profile already bound to an account');
    }
    if (!hasData || moveData) {
      return BindInPlace(binding);
    }
    return CreateNewBoundProfile(
      newProfileId: newProfileId ?? EntityId.generate(),
      newWorkspaceId: newWorkspaceId ?? EntityId.generate(),
      binding: binding,
    );
  }
}
