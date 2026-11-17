// P04b T10 (ADR-0062): the keys of shared spaces on a device, between the
// account's secure storage and the server (SpaceGateway).
//   account keys  published once per account; opened on its other devices
//                 with the personal workspace key; sealed again after that
//                 key is reset; a new pair only when the old one is lost
//   create        a new space key, wrapped for the owner's own account
//   open          the key wrapped for this account; a new one after a
//                 rotation, keeping the one before
//   invite        "approve" (the code only) or "join at once" (the code
//                 also opens the key); the server keeps the code's hash
//   accept        joins; at once, the device wraps the key again for its
//                 own account so the account's other devices open it
//   approve       the owner wraps the current key for someone waiting
//   rotate        after a removal: a new key for exactly the active members
//                 (B8, LF-INV-SHARE-004); the space's records are sealed
//                 again by the space sync (T11), then finishRotation drops
//                 the old key's rows
// Keys never leave the device unwrapped, and are never logged.
import 'dart:convert';

import 'package:application/application.dart';
import 'package:cryptography/cryptography.dart';

import '../local_store.dart' show DatabaseKeyStore;
import 'sealing.dart';
import 'space_keys.dart';
import 'workspace_keyring.dart';

/// What a device cannot do with the keys it has. Safe to show and log.
enum SpaceKeyProblem {
  /// The account has no key pair on this device yet (sync is not on here).
  noAccountKey,

  /// This device has no key for the space (not opened yet).
  noSpaceKey,

  /// A member has not published a public key the device can see.
  noMemberKey,

  /// The key opened, but is not the key the server names (a changed or
  /// mixed-up wrapping): it is not used.
  keyMismatch,

  /// Waiting for the owner's approval: no key yet.
  waiting,
}

class SpaceKeyException implements Exception {
  const SpaceKeyException(this.problem, [this.detail = '']);
  final SpaceKeyProblem problem;
  final String detail;
  @override
  String toString() => 'SpaceKeyException(${problem.name}) $detail';
}

enum AccountKeysOutcome {
  /// No keys on the server: a pair was made (or this device's) and published.
  published,

  /// The server's keys opened with the personal key.
  opened,

  /// The personal key was reset: the same pair, sealed again with the new one.
  resealed,

  /// The old private key could not be opened anywhere: a new pair. Keys
  /// wrapped for the old one need wrapping again by their owners.
  replaced,
}

/// An invitation to give to someone (B6): the code, also as a link.
class SpaceInvitationCode {
  const SpaceInvitationCode(this.code, this.kind);
  final String code;
  final InviteKind kind;
  String get link => invitationLink(code);
  String get grouped => formatInvitationCode(code);
}

class SpaceKeyService {
  SpaceKeyService({
    required SpaceGateway server,
    required WorkspaceKeyring keyring,
    required DatabaseKeyStore Function(String name) slots,
  })  : _server = server,
        _keyring = keyring,
        _slots = slots;

  final SpaceGateway _server;
  final WorkspaceKeyring _keyring;
  final DatabaseKeyStore Function(String name) _slots;

  DatabaseKeyStore _accountSlot(String accountId) => _slots('lifeflow.account.key.$accountId');

  /// This device's copy of the account's key pair, or null.
  Future<AccountKeyPair?> accountKeyPair(String accountId) async {
    final s = await _accountSlot(accountId).read();
    return s == null ? null : AccountKeyPair.fromSeed(base64Decode(s));
  }

  Future<void> _keepPair(String accountId, AccountKeyPair pair) =>
      _accountSlot(accountId).write(base64Encode(pair.seed));

  Future<AccountKeyPair> _pair(String accountId) async =>
      await accountKeyPair(accountId) ?? (throw const SpaceKeyException(SpaceKeyProblem.noAccountKey));

  /// Makes sure the account has keys on the server and this device holds
  /// them. [personalKey] is the account's personal workspace key (sync is on,
  /// B5). Call again after the personal key is reset.
  Future<AccountKeysOutcome> ensureAccountKeys(String accountId, SecretKey personalKey) async {
    final there = await _server.myKeys();
    final here = await accountKeyPair(accountId);
    Future<void> publish(AccountKeyPair pair) async {
      await _server.setMyKeys(
          AccountKeys(publicKey: pair.publicKey, sealedPrivate: await sealAccountPrivate(pair, personalKey, accountId)));
      await _keepPair(accountId, pair);
    }

    if (there == null) {
      await publish(here ?? await AccountKeyPair.generate());
      return AccountKeysOutcome.published;
    }
    try {
      final opened = await openAccountPrivate(there.sealedPrivate, personalKey, accountId);
      if (!_same(opened.publicKey, there.publicKey)) {
        throw const SealBroken('the private key is not the published one');
      }
      await _keepPair(accountId, opened);
      return AccountKeysOutcome.opened;
    } on SealBroken {
      if (here != null && _same(here.publicKey, there.publicKey)) {
        await publish(here);
        return AccountKeysOutcome.resealed;
      }
      await publish(await AccountKeyPair.generate());
      return AccountKeysOutcome.replaced;
    }
  }

  Future<String> _keyIdOf(SecretKey key) async => (await RecordSealer.of(key)).keyId;

  Future<SecretKey> _spaceKey(String spaceId) async =>
      await _keyring.keyOf(spaceId) ?? (throw const SpaceKeyException(SpaceKeyProblem.noSpaceKey));

  /// A new space owned by the account; returns its key id.
  Future<String> createSpace(String accountId, String spaceId) async {
    final pair = await _pair(accountId);
    final key = await newWorkspaceKey();
    final keyId = await _keyIdOf(key);
    await _server.createSpace(spaceId, await wrapForMember(key, pair.publicKey, spaceId), keyId);
    await _keyring.keepKey(spaceId, key);
    return keyId;
  }

  /// The space's current key on this device, opened from what the server
  /// wrapped for the account when this device does not hold it yet (or holds
  /// an older one: the older one is kept as the previous key). When this
  /// device holds the current key but the server's wrapping does not open
  /// (a "join at once" whose re-wrap did not reach the server), it wraps the
  /// key for the account again.
  Future<SecretKey> openSpaceKey(String accountId, RemoteSpace space) async {
    final spaceId = space.workspaceId;
    final wrapped = space.wrappedKey;
    if (space.status == MemberStatus.pending || wrapped == null) {
      throw const SpaceKeyException(SpaceKeyProblem.waiting);
    }
    final held = await _keyring.keyOf(spaceId);
    if (held != null && await _keyIdOf(held) == space.keyId) {
      final pair = await accountKeyPair(accountId);
      if (pair != null) {
        try {
          await openForMember(wrapped, pair, spaceId);
        } on SealBroken {
          await _server.setMyWrappedKey(spaceId, await wrapForMember(held, pair.publicKey, spaceId), space.keyId);
        }
      }
      return held;
    }
    final pair = await _pair(accountId);
    final key = await openForMember(wrapped, pair, spaceId);
    if (await _keyIdOf(key) != space.keyId) throw const SpaceKeyException(SpaceKeyProblem.keyMismatch);
    await _keyring.keepKey(spaceId, key, keepPrevious: held != null);
    return key;
  }

  /// A new invitation to [spaceId] (the owner's device). "Join at once"
  /// carries the current key, wrapped with a key made from the code.
  Future<SpaceInvitationCode> invite(String spaceId, SpaceRole role, InviteKind kind, {int days = 7}) async {
    final code = newInvitationCode();
    final hash = await invitationHash(code);
    if (kind == InviteKind.joinAtOnce) {
      final key = await _spaceKey(spaceId);
      await _server.invite(spaceId, hash, role, kind,
          wrappedKey: await wrapForCode(key, code, spaceId), keyId: await _keyIdOf(key), days: days);
    } else {
      await _server.invite(spaceId, hash, role, kind, days: days);
    }
    return SpaceInvitationCode(code, kind);
  }

  /// What [code] is an invitation to, before accepting (SHARE-005).
  Future<InvitationPreview> peek(String code) async => _server.peekInvitation(await invitationHash(code));

  /// Accepts [code]. "Join at once": the key is opened with the code,
  /// checked against the key id, wrapped again for the account and kept.
  Future<AcceptedInvitation> accept(String accountId, String code) async {
    final pair = await _pair(accountId);
    final accepted = await _server.acceptInvitation(await invitationHash(code));
    final wrapped = accepted.wrappedKey;
    if (accepted.preview.kind == InviteKind.joinAtOnce && wrapped != null) {
      final spaceId = accepted.preview.workspaceId;
      final key = await openWithCode(wrapped, code, spaceId);
      if (await _keyIdOf(key) != accepted.keyId) throw const SpaceKeyException(SpaceKeyProblem.keyMismatch);
      await _keyring.keepKey(spaceId, key);
      await _server.setMyWrappedKey(spaceId, await wrapForMember(key, pair.publicKey, spaceId), accepted.keyId);
    }
    return accepted;
  }

  /// Lets [memberAccountId] in, with the current key wrapped for them.
  Future<void> approve(String spaceId, String memberAccountId) async {
    final key = await _spaceKey(spaceId);
    final theirs = (await _server.publicKeys([memberAccountId]))[memberAccountId];
    if (theirs == null) throw SpaceKeyException(SpaceKeyProblem.noMemberKey, memberAccountId);
    await _server.approveMember(spaceId, memberAccountId, await wrapForMember(key, theirs, spaceId), await _keyIdOf(key));
  }

  /// A new key for exactly the active members (after a removal, B8). The
  /// key before it stays on this device until [finishRotation]. Returns the
  /// new key id.
  Future<String> rotate(String spaceId) async {
    final active = [
      for (final m in await _server.members(spaceId))
        if (m.status == MemberStatus.active) m.accountId,
    ];
    final keys = await _server.publicKeys(active);
    final missing = active.where((a) => !keys.containsKey(a)).toList();
    if (missing.isNotEmpty) throw SpaceKeyException(SpaceKeyProblem.noMemberKey, missing.join(','));
    final key = await newWorkspaceKey();
    final keyId = await _keyIdOf(key);
    await _server.rotateKey(spaceId, keyId, {for (final a in active) a: await wrapForMember(key, keys[a]!, spaceId)});
    await _keyring.keepKey(spaceId, key, keepPrevious: true);
    return keyId;
  }

  /// Once the space's records are sealed again with the current key: drops
  /// the old key's rows from the server and the old key from this device.
  Future<int> finishRotation(String spaceId) async {
    final n = await _server.dropOldKeyRecords(spaceId);
    await _keyring.forgetPrevious(spaceId);
    return n;
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
