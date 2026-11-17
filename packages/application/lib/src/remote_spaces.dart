// P04b T9 (ADR-0061): shared spaces on the sync server, as a device sees
// them. Only wrapped keys, public keys, hashes of invitation codes and plain
// rules cross this port; a space's records go through RemoteGateway's push,
// pull and purge like a personal workspace's, and the server checks the
// caller's role there (LF-INV-SHARE-002). The implementations live in
// infrastructure (Supabase over HTTP, and one in memory with the same
// semantics); remote_contract_test.dart runs the same cases against both.
import 'dart:typed_data';

import 'remote.dart';
import 'spaces.dart' show SpaceRole;

/// What happens to a member's copy when they leave or are removed (B8).
enum LeaveRule { disappear, disappearWithExport, keepReadOnly }

/// Who may export a space's data (B14).
enum ExportRule { ownerOnly, everyMember }

/// How an invitation lets someone in (B7).
enum InviteKind {
  /// The owner approves the person after they accept.
  approve,

  /// The code carries the space key; the person is in at once.
  joinAtOnce,
}

enum MemberStatus { pending, active }

class SpaceRules {
  const SpaceRules({
    this.leave = LeaveRule.disappear,
    this.export = ExportRule.ownerOnly,
    this.inviteDefault = InviteKind.approve,
  });
  final LeaveRule leave;
  final ExportRule export;
  final InviteKind inviteDefault;

  @override
  bool operator ==(Object other) =>
      other is SpaceRules && other.leave == leave && other.export == export && other.inviteDefault == inviteDefault;
  @override
  int get hashCode => Object.hash(leave, export, inviteDefault);
}

/// The signed-in account's own keys: the X25519 public key (32 bytes) and
/// the private key sealed with the account's personal workspace key.
class AccountKeys {
  const AccountKeys({required this.publicKey, required this.sealedPrivate});
  final Uint8List publicKey;
  final Uint8List sealedPrivate;
}

/// A shared space the signed-in account belongs to (or waits to join).
class RemoteSpace {
  const RemoteSpace({
    required this.workspaceId,
    required this.role,
    required this.status,
    required this.wrappedKey,
    required this.keyId,
    this.rules,
    this.rulesChangedAt,
  });
  final String workspaceId;
  final SpaceRole role;
  final MemberStatus status;

  /// The space key wrapped for this account; null while waiting.
  final Uint8List? wrappedKey;

  /// Which space key [wrappedKey] is ('' while waiting).
  final String keyId;

  /// Null while waiting: the rules are read once a member.
  final SpaceRules? rules;
  final DateTime? rulesChangedAt;
}

class RemoteMember {
  const RemoteMember({
    required this.accountId,
    required this.role,
    required this.status,
    required this.keyId,
    required this.joinedAt,
    this.sealedName,
  });
  final String accountId;
  final SpaceRole role;
  final MemberStatus status;
  final String keyId;
  final DateTime joinedAt;

  /// P04b T13 (ADR-0065): the name of someone who asked to join, sealed for
  /// the owner (only the owner's devices open it); null if none was given.
  final Uint8List? sealedName;
}

/// An open invitation, as its space's owner sees it (never the code).
class RemoteInvitation {
  const RemoteInvitation({
    required this.codeHash,
    required this.role,
    required this.kind,
    required this.expiresAt,
  });
  final String codeHash;
  final SpaceRole role;
  final InviteKind kind;
  final DateTime expiresAt;
}

/// What an invitation is for, before accepting it (LF-INV-SHARE-005).
class InvitationPreview {
  const InvitationPreview({
    required this.workspaceId,
    required this.role,
    required this.kind,
    required this.leave,
    required this.export,
    this.expiresAt,
    this.ownerPublicKey,
  });
  final String workspaceId;
  final SpaceRole role;
  final InviteKind kind;
  final LeaveRule leave;
  final ExportRule export;
  final DateTime? expiresAt;

  /// P04b T13: the owner's public key, to seal one's name to (ADR-0065).
  final Uint8List? ownerPublicKey;
}

/// An accepted invitation: for "join at once", the space key wrapped with a
/// key made from the code.
class AcceptedInvitation {
  const AcceptedInvitation({required this.preview, this.wrappedKey, this.keyId = ''});
  final InvitationPreview preview;
  final Uint8List? wrappedKey;
  final String keyId;
}

/// Why the server turned a space request down, so the app can say it.
enum SpaceRefusal {
  /// The account has not published its public key (sync is not on).
  noPublicKey,

  /// The code is unknown, used, cancelled or expired (all look the same).
  noSuchInvitation,
  alreadyMember,

  /// The space has 10 members (B13), counting those waiting.
  spaceFull,

  /// The account is in 10 spaces (B13).
  tooManySpaces,
  nobodyWaiting,
  notAMember,
  ownerMustHandOver,

  /// The key named is not the space's current key (it was rotated).
  staleKey,

  /// A new key was not wrapped for exactly the active members.
  wrongMembers,
}

/// A space request the server refused for a reason the app explains. Its
/// [kind] is [RemoteFailureKind.refused], so code that only knows
/// RemoteFailure treats it as before.
class SpaceFailure extends RemoteFailure {
  const SpaceFailure(this.reason, [String detail = '']) : super(RemoteFailureKind.refused, detail);
  final SpaceRefusal reason;
  @override
  String toString() => 'SpaceFailure(${reason.name}) $detail';
}

abstract interface class SpaceGateway {
  /// The signed-in account's keys, or null before they are published.
  Future<AccountKeys?> myKeys();

  /// Publishes the public key and keeps the sealed private key; again with
  /// a new sealing after the personal key is reset.
  Future<void> setMyKeys(AccountKeys keys);

  /// The public keys of [accountIds] that the caller may see (their own and
  /// those of people in a space with them).
  Future<Map<String, Uint8List>> publicKeys(List<String> accountIds);

  /// The spaces the account is in or waits to join.
  Future<List<RemoteSpace>> spaces();

  /// A new space owned by the account, with its key wrapped for the owner.
  Future<void> createSpace(String workspaceId, Uint8List wrappedForMe, String keyId);

  /// Deletes the space and everything in it (the owner only).
  Future<void> deleteSpace(String workspaceId);

  Future<List<RemoteMember>> members(String workspaceId);

  /// The owner's open invitations.
  Future<List<RemoteInvitation>> invitations(String workspaceId);

  /// An invitation lasting [days] (1 to 7); "join at once" carries the key
  /// wrapped with a key made from the code.
  Future<void> invite(String workspaceId, String codeHash, SpaceRole role, InviteKind kind,
      {Uint8List? wrappedKey, String keyId = '', int days = 7});
  Future<void> cancelInvitation(String codeHash);
  Future<InvitationPreview> peekInvitation(String codeHash);
  /// [sealedName]: the joiner's name sealed for the owner (ADR-0065).
  Future<AcceptedInvitation> acceptInvitation(String codeHash, {Uint8List? sealedName});

  /// Lets someone waiting in, with the current key wrapped for them.
  Future<void> approveMember(String workspaceId, String accountId, Uint8List wrappedKey, String keyId);

  /// The member's own wrapping of the current key (after joining at once).
  Future<void> setMyWrappedKey(String workspaceId, Uint8List wrappedKey, String keyId);

  /// Removes a member, or turns down someone waiting.
  Future<void> removeMember(String workspaceId, String accountId);

  /// Leaves the space, or withdraws a request to join.
  Future<void> leaveSpace(String workspaceId);
  Future<void> setRole(String workspaceId, String accountId, SpaceRole role);
  Future<void> handOver(String workspaceId, String accountId);
  Future<void> setRules(String workspaceId, SpaceRules rules);

  /// A new space key, wrapped for exactly the active members.
  Future<void> rotateKey(String workspaceId, String keyId, Map<String, Uint8List> wrappedFor);

  /// After a rotation, once the records are sealed again with the current
  /// key: drops the rows of any other key (the owner only). Returns how many.
  Future<int> dropOldKeyRecords(String workspaceId);
}

/// The most members of one space and the most spaces of one account (B13).
const maxSpaceMembers = 10;
const maxSpacesPerAccount = 10;
