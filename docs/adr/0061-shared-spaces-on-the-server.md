# ADR-0061: Shared spaces on the server

- Status: Accepted (P04b task T9, 2026-11-17)
- Date: 2026-11-17
- Deciders: Implementation, within the owner's decisions B4–B8, B13 and B14 of [p04b-plan.md](../roadmap/p04b-plan.md)
- Related: [ADR-0055](0055-sync-server-port-and-contract.md) (the sync server port and its contract), [ADR-0057](0057-joining-and-leaving-sync.md) (key ids), [ADR-0060](0060-shared-spaces-in-one-store.md), spike S-16 ([spike-results.md](../spikes/spike-results.md))

## Context
S-16 proved the server side of shared spaces inside a rolled-back test: tables, set-based row-level security, role-checked functions, and X25519 key wrapping. T9 makes it real: a migration the owner pushes to the hosted project, a device-side port, and the same contract on the in-memory server and on Supabase.

## Decision
1. **Migration `20261117000001_spaces.sql`.**
   - A shared space is a row of `account_workspaces` with `unlock_kind = 'space'`. Its `account_id` is the current owner, so P04a's delete policy lets only the owner delete it, and the cascade removes its records, members, invitations and rules.
   - New tables, each with row-level security:
     - `spaces`: the rules (leaving B8, export B14, the default invitation kind B7) and when they last changed;
     - `space_members`: role, status (`pending`/`active`), the space key wrapped for that member and which key it is;
     - `space_invitations`: a SHA-256 hash of the code, never the code; a "join at once" invitation also holds the key wrapped with a key made from the code, and that copy is erased once it is used;
     - `account_public_keys` and `account_private_keys`: each account's X25519 public key, and its private key sealed with its personal workspace key.
   - Reads are **by set**: `workspace_id in (select private.my_workspace_ids())`. A function per row is not used (S-16 part 2). The helper functions live in a `private` schema, which the REST API does not expose. `private.must_own` is a real function now; in the spike it was a `pg_temp` function.
   - **Writes go only through functions.** The tables have no insert, update or delete grants:
     - `set_account_keys` (publish, or seal again after a reset);
     - `create_space`, `invite`, `cancel_invitation` (new), `peek_invitation`, `accept_invitation`, `approve_member`, `set_my_wrapped_key`;
     - `remove_member`, `leave_space` (also withdraws a request), `set_role`, `hand_over`, `set_space_rules`, `rotate_space_key`;
     - `my_spaces` (new), a read through the policies: the caller's spaces with their key and the rules, and no rules while the caller is waiting.
   - `push_records` and `purge_records` accept an owner or an editor of a space, or the owner of a personal workspace (`private.role_in`). `pull_records` is unchanged; the new policy lets every active member read.
   - The P04a workspace policy is split by action. A device inserts and updates only personal rows (`unlock_kind <> 'space'`), so nobody turns a space into a personal workspace or makes one by hand.
   - Changes from the spike:
     - `approve_member` and `set_my_wrapped_key` take only the current key id (`staleKey`);
     - "approve" invitations carry no key id;
     - `rotate_space_key` also stores the owner's new wrapping on the workspace row and locks the space;
     - `accept_invitation` locks the space, so two people cannot take the tenth seat together;
     - `set_space_rules` changes nothing, and does not move `rules_changed_at`, when the rules are the same;
     - the owner leaving gives `ownerMustHandOver` rather than a permission error.
2. **Refusals the app explains.** A refusal the user should understand carries a hint `lifeflow:<reason>`. The reasons are `noPublicKey`, `noSuchInvitation` (unknown, used, cancelled and expired look the same), `alreadyMember`, `spaceFull`, `tooManySpaces`, `nobodyWaiting`, `notAMember`, `ownerMustHandOver`, `staleKey` and `wrongMembers`. The HTTP gateway turns the hint into `SpaceFailure(reason)`. That is a `RemoteFailure` of kind `refused`, so existing code that knows only the four kinds keeps working. Owner checks still raise `42501`, which becomes `notYours`.
3. **A separate port, `SpaceGateway`** (`application/lib/src/remote_spaces.dart`), next to `RemoteGateway`:
   - keys: `myKeys`, `setMyKeys`, `publicKeys`;
   - spaces: `spaces`, `createSpace`, `deleteSpace`;
   - membership: `members`, `invitations`, `invite`, `cancelInvitation`, `peekInvitation`, `acceptInvitation`, `approveMember`, `setMyWrappedKey`, `removeMember`, `leaveSpace`, `setRole`, `handOver`, `setRules`, `rotateKey`.

   A space's records still go through `RemoteGateway.push`, `pull` and `purge`. The port is separate so the P04a test doubles that wrap a `RemoteGateway` stay as they are. `MemoryRemoteGateway` and `HttpRemoteGateway` implement both ports.
4. **`RemoteGateway.workspaces()` lists personal workspaces only.** A space the account owns is in `spaces()`. P04a's sync setup takes the first listed workspace, so it would otherwise pick up a space.
5. **One contract, two servers.** `remote_spaces_contract_test.dart` runs 11 cases on the in-memory server and on local Supabase (CI job `supabase-db`), and adds an in-memory expiry case. pgTAP `spaces.test.sql` covers the server cases one by one, and `spaces_speed.test.sql` keeps S-16's load check against the real policy. The spike's test files are removed.
6. **Local stack only:** `supabase/config.toml` raises `sign_in_sign_ups` to 200 per 5 minutes, because one run of the contract tests signs up about 30 accounts. The hosted project keeps its own setting.

## Consequences
- The hosted project needs `npx --yes supabase@3.1.0 db push --remote` before anything uses spaces (at the latest before T14). The migration changes no P04a behaviour: P04a's 37 pgTAP tests, its contract test and its end-to-end test on local Supabase pass unchanged.
- A new public key from `set_account_keys` leaves the space keys wrapped with the old one unusable until an owner wraps them again. T10 decides when a device may make a new key pair (only when the old private key cannot be opened).
- Deleting an owner's account deletes their spaces for everyone (cascade from `auth.users`). P04b has no account deletion in the app, so this is noted, not handled.
- Members see each other's wrapped keys (`space_members.wrapped_key`). Each one opens only with its member's private key.
- Tests:
  - pgTAP: 171 (P04a's 37, `spaces.test.sql` 130, `spaces_speed.test.sql` 4). Locally: a page of 1000 in 1.5 ms and a count of 22 222 rows in 4.2 ms.
  - Contract: 11 cases × 2 servers, plus 1 in memory.
- Mutations: 17 of 17 killed (9 in SQL, 8 in the Dart gateways), run one at a time against pgTAP and the contract on local Supabase:
  - SQL: a viewer writing; a pending member reading; the member limit; "join at once" invitations kept after a rotation; approving with an old key; turning a space into a personal row; public keys shown to someone waiting; unchanged rules moving the change time; the old owner keeping the owner role.
  - Dart: memory pull, write, member-limit and listing checks, and the public-key rule; the HTTP personal-only filter, the hint mapping and the open-invitations filter.
