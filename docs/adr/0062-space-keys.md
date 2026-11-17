# ADR-0062: Keys of shared spaces

- Status: Accepted (P04b task T10, 2026-11-18)
- Date: 2026-11-18
- Deciders: Implementation, within the owner's decisions B5, B6, B7 and B8 of [p04b-plan.md](../roadmap/p04b-plan.md)
- Related: [ADR-0052](0052-sync-backend-and-end-to-end-encryption.md) §5, [ADR-0054](0054-sync-keys-recovery-key-and-passphrase.md) (workspace keys), [ADR-0057](0057-joining-and-leaving-sync.md) (key ids), [ADR-0061](0061-shared-spaces-on-the-server.md), spike S-16

## Context
A shared space's records are sealed like a personal workspace's (`RecordSealer`), with the space's own key. That key must reach every member and every device of each member, and never the server in the clear. After a removal it must change, so the removed member cannot open anything sealed afterwards (B8, LF-INV-SHARE-004). S-16 proved the cryptography in a throwaway test. T10 makes it code.

## Decision
1. **Primitives (`sync/space_keys.dart`)**, using `cryptography` 2.9.0 as in S-16. Every wrapping starts with format byte 1.
   - **Account key pair:** X25519. The private key is sealed with a key derived (HKDF) from the account's **personal workspace key**, bound to the account id. Every device of the account that syncs opens it (B5: sync must be on).
   - **Member wrap:** a fresh X25519 sender key per wrap, HKDF over the shared secret (both public keys as salt, the space id in the info), then AES-256-GCM with the space id as associated data. 93 bytes. It opens for that member only, in that space only.
   - **"Join at once" wrap:** AES-256-GCM under HKDF of the invitation code, with the space id bound in. The server keeps only `SHA-256('lifeflow invite v1:' + code)`.
   - **Codes:** 26 letters from a 32-letter alphabet without O, 0, I and 1 (130 bits). They are shown grouped in fives and as a `lifeflow://join/<code>` link (B6). `parseInvitation` reads a typed, pasted or linked code in any case, with spaces or dashes. It does not guess look-alike letters.
2. **`SpaceKeyService`** (`sync/space_key_service.dart`) does the device's side over `SpaceGateway`:
   - **Account keys** (`ensureAccountKeys`), with four outcomes:
     - `published`: the server has none, so the device makes and publishes them;
     - `opened`: the server's private key opens with the personal key, and its public key matches;
     - `resealed`: the personal key was reset (P04a). The device still holding the pair seals it again, with the same public key, so nothing needs wrapping again;
     - `replaced`: the pair cannot be opened anywhere, so a new pair is made. Keys wrapped for the old one need wrapping again by each space's owner (T12/T13).

     The pair is kept in secure storage (`lifeflow.account.key.<account>`), never in the database.
   - **Space keys** live in the `WorkspaceKeyring` slot of the space's workspace id, like a personal key. The keyring gains `keepKey`, `previousKeyOf` and `forgetPrevious`.
     - `createSpace` makes the key and wraps it for the owner's own account.
     - `openSpaceKey` opens the key wrapped for this account and checks that its key id is the one the server names; otherwise the key is not used (`keyMismatch`). A newer key keeps the older one as the previous key. A device that holds the current key, while the server's wrapping for its account does not open, wraps the key again. This covers a "join at once" whose second step did not reach the server.
   - **Invitations:** `invite` with "approve" (code only) or "join at once" (the code also opens the key).
     - `accept`, for "join at once": opens the key with the code, checks its key id, keeps it, and wraps it again for the account (`setMyWrappedKey`). The account's other devices then open it with the account key.
     - `approve`: wraps the current key for the waiting member's public key.
   - **Rotation (B8)**, in four steps:
     1. `rotate` makes a new key, wraps it for exactly the active members (all their public keys are needed, else `noMemberKey` and nothing changes), and keeps the old key as the previous one.
     2. The server refuses any push to the space that does not name the current key (below). Nothing can be sealed with the old key after the rotation.
     3. The space sync (T11) seals the records again with the new key and pushes them. Server ids are keyed, so the ids are new.
     4. `finishRotation` (the owner) drops the old key's rows from the server and the previous key from the device.
3. **Migration `20261118000001_record_key_id.sql`:**
   - `sync_records.key_id` stores which key a row is sealed with.
   - `push_records` takes `p_key_id` (default `''`). In a space it must be the current key, or the push is refused with `lifeflow:staleKey`. A personal workspace stores what it is given and checks nothing: its key changes only by a reset, which uploads again (ADR-0057).
   - `pull_records` returns `key_id`, so during a rotation a device skips rows of a key it does not hold.
   - `drop_old_key_records` is for the owner only.
   - Ports:
     - `RemoteGateway.push(..., {keyId})`;
     - `SealedRecord.keyId`;
     - `SpaceGateway.dropOldKeyRecords`.
   - The HTTP gateway sends `p_key_id` only when it is set. A P04a push therefore still reaches a server without this migration, and the owner's devices keep syncing until he pushes it.

## Consequences
- Every part of the plan's exit check for T10 is covered by a test. Only a member opens the space (`space_key_service_test`: approve, join at once, the account's other device, a stranger). A removed member's key opens nothing sealed after the removal, and old-key pushes are refused (`space_key_service_test` rotation, contract and pgTAP `space_rotation.test.sql`).
- **Not done here:** step 3 of a rotation and skipping rows of an unknown key belong to the space sync engine (T11). Calling `rotate` after a removal, and `ensureAccountKeys` when sync turns on or the personal key is reset, are the sharing commands' job (T12).
- Known limit: re-uploading a rotated space also has to carry the tombstones of deleted records. Otherwise a device that has not pulled a delete never learns it after the old rows are dropped. This is for T11's re-upload.
- The spike's `spike_s16_keys_test.dart` is replaced by `space_keys_test.dart` (6 tests) and `space_key_service_test.dart` (10).
- Tests:
  - pgTAP: 188 (`space_rotation.test.sql` 17 new).
  - Contract: one case more (rotation and key ids) on memory and local Supabase.
  - Not changed: P04a's sync, contract and end-to-end tests on local Supabase.
- Mutations: 18 run one at a time, 17 killed.
  - Three needed new tests: a pull's key id over HTTP; a published public key that is not the sealed private key's; a "join at once" key that is not the named one.
  - The one survivor is equivalent: the public-key length check in `wrapForMember`, which the library already enforces with the same error.
