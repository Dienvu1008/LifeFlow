# P04b exit-gate evidence (sharing with other people)

Maps each line of the P04b exit gate ([p04b-plan.md §1](../roadmap/p04b-plan.md)), the invariants and scenarios it proposed (§7) and the P04 anchors of the definition of done ([definition-of-done.md](definition-of-done.md)) to the tests and checks that prove them. Status: **waiting for the owner's review**.

How to reproduce:
- `dart test` in `packages/foundation|time_kernel|domain|application|infrastructure`.
- `flutter test` in `packages/ui` and `apps/lifeflow_app`.
- `dart run tools/fitness/<script>.dart` for each fitness script.
- The server, on a clean local database:
  - `supabase start`, then `supabase db reset`, then `supabase test db` (pgTAP). The pgTAP files assume a fresh database: run right after the e2e tests below without a reset, they fail on the accounts and spaces those tests left (seen on 2026-11-04; 195/195 after the reset).
  - In `packages/infrastructure`, with `LIFEFLOW_TEST_SUPABASE_URL` and `LIFEFLOW_TEST_SUPABASE_ANON_KEY` set to the local stack: `dart test test/remote_contract_test.dart test/remote_spaces_contract_test.dart test/sync_supabase_e2e_test.dart test/space_sync_supabase_e2e_test.dart`.
- CI runs all of this on every push (`.github/workflows/ci.yml`; job `supabase-db` for the server).

Branch at T15: `p04b/t15-exit-gate`, on `main` at `171ce9e` (T14 merged).

## Exit gate (p04b-plan.md §1)

| Line | Proof |
|---|---|
| A member cannot read or write a space they are not in, or write beyond their role, even with crafted requests (R-PERMISSION, OQ-V5) | **Server.** pgTAP `spaces.test.sql` (130 assertions, from spike S-16's cases): reads and writes for the owner, an editor, a viewer, someone waiting, someone who joined at once, a removed member, a stranger and anon, also as crafted direct table writes; owner-only functions refused to everyone else. `space_rotation.test.sql` (17) and `member_names.test.sql` (7). `remote_spaces_contract_test.dart`, run on the in-memory server and on local Supabase: "a stranger reaches nothing; deleting the space deletes everything in it", "owner-only actions are refused to others; roles change; the owner hands over", "\"approve\": the invitee sees the rules first, waits, and is let in by the owner; a code works once" (someone waiting cannot push or pull), "\"join at once\": in at once with the key the code carried, which the server then forgets" (a viewer reads, and cannot push or purge), "removal: no access at once; the new key goes to exactly the active members", "limits: 10 members a space, counting those waiting; 10 spaces an account (B13)". **Device.** `WorkspaceOwnerAuthorization` acts on the member's cached role (`app_service_impl.dart`): `space_sync_test.dart` "a viewer pulls and never pushes; the server refuses a viewer's push too (SHARE-002)", "a member cannot put a personal kind into the space, nor overwrite another workspace's record (B2)"; `sharing_test.dart` "assign to an owner or an editor (B9); a viewer assigns nothing", "removed: no access, a new key; …" (a demoted owner cannot rename). Speed of the set-based RLS: `spaces_speed.test.sql` (20 000 records, 10 members; a page of 1000 in about 1.5 ms). |
| Nothing personal becomes shared implicitly (PRIV-002/003); an item enters a space only by an explicit action that shows what becomes visible; Restricted data never does | `sharing_test.dart` "move into a space: asked first; reminders stay personal; the member sees it; changed since shown: nothing moves" (the preview lists the titles, counts, notes and dates; a change after the preview moves nothing), "what never moves: a tracked task, a subtask alone, into a space one is not in", "move back out: …". UI: `spaces_flow_test.dart` "\"Move to a space…\": what becomes visible is shown, then it moves (B3, PRIV-002)" and "a move that cannot happen says why, and nothing moves". **Restricted:** the move set refuses any record whose class does not allow the cloud (`moveSetOf` in `space_move_handler.dart`), and the space's sync withholds it like the personal sync does (ADR-0059). Today no record a move takes can be Restricted: only a health-sourced measurement is, and measurements are never in a space (B2). So the guard has no separate test; it is there for kinds classified later. |
| A removed member gets nothing new: no access on the server, and a new space key they do not have | `space_sync_test.dart` "rotation: the owner seals everything again; an editor offline meanwhile catches up; the removed member stops" (the key the removed member had opens nothing sealed after the removal); `space_key_service_test.dart` "rotation: a removed member opens nothing sealed afterwards (SHARE-004); old rows and the old key go at the end"; `space_keys_test.dart` "rotation: the old key opens nothing sealed with the new one, and cannot find the records"; contract "removal: …" and "rotation: a push names the current key; the old key's rows go only when the owner drops them"; pgTAP `space_rotation.test.sql`; e2e "rotate: a member removed; the owner seals everything again; the others catch up; the removed one stops". Device check: T14 steps 15 and 18. |
| The server still sees no content (D12); keys reach a member only wrapped for that member | Records, the space's name and members' names are sealed: `sharing_test.dart` "create: a named space, …; the name reaches members sealed; …" and "T13 names (ADR-0065): who waits is named for the owner only; members' names are sealed records" check every row the server holds; the app integration test "P04b T13: a space made, an invitation, a request let in, a task shared" checks that the server holds no title or name. Wrapping: `space_keys_test.dart` "a space key wrapped for one member opens for that member only, in that space only", "an account's private key opens only with the personal key it was sealed with, for that account", "\"join at once\": the code opens the key; the hash the server keeps does not", "T13: a name sealed for the owner opens for the owner only, for that space and that sender"; `space_key_service_test.dart` (a public key that does not match the sealed private key, or a key that does not match its id, is not used). |
| P04a's GS-14, GS-17 and SYNC-001…004 hold in a shared space with two people editing | `space_sync_test.dart` "two people: changes made offline on both arrive, fields merge, and \"changed by\" says who (GS-17, SYNC-003)", "T14 finding 2: notes changed by both people offline: a review in the space, then \"Take the other\" (SYNC-003)", "a delete reaches everyone; after the retention the purge does too (GS-14)" (and the purge after a rotation in the rotation test). On the real stack: `space_sync_supabase_e2e_test.dart` "T14 step 10: notes changed by both, one offline: the later device has a review; \"Take the other\" syncs" and "share: …; edits reach the others; a viewer pushes nothing". SYNC-002: the server checks the base version on a space's push as on a personal one (`push_records`), and the second push of step 10 is a conflict that the pull merges. SYNC-001: a space runs P04a's engine in a space mode with the same operation ids (UUID v5 of device, kind, id and version); the replay test itself is P04a's (`remote_contract_test.dart`), not repeated per space. Device check: T14 steps 7–10. |

Fitness functions: FF-ARCH-06/09 for every new handler, FF-ARCH-07 for any new package, and ADR-0059's classification on the share action (below).

## Invariants (p04b-plan.md §7)

| Invariant | Proof |
|---|---|
| LF-INV-SHARE-001: an item enters or leaves a shared space only by an explicit command the user confirmed; Restricted data never enters | the second exit-gate row: one `MoveIntoSpace` / `MoveOutOfSpace` command per move, confirmed by the preview's fingerprint (changed since shown: nothing moves); ids kept (ID-001) |
| LF-INV-SHARE-002: a write to a shared space is accepted only from its owner or an editor, on the device and on the server | the first exit-gate row (device: the role policy; server: `push_records` and the role-checked functions, pgTAP and the contract) |
| LF-INV-SHARE-003: membership, roles and invitations change only on the server, through owner-checked functions; devices only cache them | contract "owner-only actions are refused to others; …", "an invitation can be cancelled, by the owner only", "\"approve\": …" (an editor cannot approve); `sharing_test.dart` "invitations: the rules first (SHARE-005), …" (an editor cannot approve); pgTAP `spaces.test.sql` (crafted direct writes to the membership tables refused). The device's cache is written only by the space sync's refresh from the server (`space_sync_service.dart`), and leaving or removal is applied from it (`sharing_test.dart` "leaving rules (B8): …") |
| LF-INV-SHARE-004: after a member is removed, nothing sealed afterwards can be opened with a key that member had | the third exit-gate row |
| LF-INV-SHARE-005: a space's rules are shown before joining, change only by the owner, and every change is shown to every member | contract "rules: the owner sets them; members see them and when they changed; the same rules are no change" and "\"approve\": the invitee sees the rules first, …"; `sharing_test.dart` "invitations: the rules first (SHARE-005), …", "leaving rules (B8): …" (a change is a notice; the same rules are none), "export by the export rule (B14); …" (notice, then seen); UI: `spaces_flow_test.dart` "join with a code: the role and the rules first, then join (SHARE-005)" and "rules: the owner sets them; the change notice is seen once (SHARE-005)". Device check: T14 step 14. Limit: a change between asking to join and being let in shows no notice (ADR-0064) |

Also held in a space: LF-INV-OUTBOX-001 and GOV-001 (every sharing command through the gateway, each written record with its own outbox row: `atomic_set_test.dart`); ID-001 (moves keep ids); WA-001 as refined by ADR-0060 (`spaces_store_test.dart`). The catalog entries are in [invariant-catalog.md](../invariants/invariant-catalog.md) §10a and the matrix rows in [invariant-test-matrix.md](../invariants/invariant-test-matrix.md) (P04b status).

## Golden scenarios (new: GS-23…GS-26)

| Scenario | Proof |
|---|---|
| GS-23 a stranger and a removed member read and write nothing, even with crafted requests | pgTAP `spaces.test.sql` (S and R); contract "a stranger reaches nothing; …" and "removal: no access at once; …" |
| GS-24 a viewer cannot write | `space_sync_test.dart` "a viewer pulls and never pushes; …"; contract "\"join at once\": …" (viewer push and purge refused); `spaces_flow_test.dart` "a viewer: \"View only\", and nothing to add (B4)"; T14 step 12 |
| GS-25 a move into a space shows what becomes visible, and nothing else moves | `sharing_test.dart` "move into a space: asked first; …" and "what never moves: …"; `spaces_flow_test.dart` "\"Move to a space…\": …"; T14 step 7 |
| GS-26 two people edit one task offline: P04a's merge rules hold | `space_sync_test.dart` "two people: …" and "T14 finding 2: …"; e2e "T14 step 10: …"; T14 step 10 |

## Server (Supabase)

| Check | Proof |
|---|---|
| Membership and roles enforced by RLS and the functions | pgTAP: 6 files, 195 assertions (P04a's `sync_records` 29 and `pull_records` 8; P04b's `spaces` 130, `spaces_speed` 4, `space_rotation` 17, `member_names` 7), local, 2026-11-04 |
| One contract for the in-memory server and Supabase | `remote_spaces_contract_test.dart` (each case on both servers, plus one in memory: an invitation expires); with `remote_contract_test.dart` and the two e2e files, 55 tests on local Supabase (2026-11-04) |
| People sharing a space end to end on Supabase | `space_sync_supabase_e2e_test.dart`: 4 tests (share, T12 named space and move, T14 step 10, rotate) with real accounts, the real HTTP gateway and the project's migrations |
| Migrations on the owner's project | `20261117000001_spaces.sql`, `20261118000001_record_key_id.sql` and `20261120000001_member_names.sql`, pushed by the owner (`supabase db push --remote`); the agent checked the columns and functions on the hosted project |

## Fitness functions and governance

| FF / rule | How it is checked |
|---|---|
| FF-ARCH-01 pure domain | green; the merges a space uses are P04a's pure ones in `domain` |
| FF-ARCH-04 UI isolation | the UI talks to `SpaceService`, `SharingService` and `SpaceSyncRunner` (no key, no server) |
| FF-ARCH-06 atomic set for the new handlers | `atomic_set_test.dart` steps `profile.switchSpace`, `task.create(member)`, `spaceSettings.create`, `task.assign`, `space.moveIn`, `space.moveOut`, `memberCard.create`, `profile.switchSpace(back)`, with fault injection; `ff_arch_06_09.dart` finds every `CommandHandler` there |
| FF-ARCH-07 licenses | no new package in P04b: X25519 and HKDF come from `cryptography` (VS-42); the inventory is unchanged at 134 |
| FF-ARCH-09 authorize before domain | `ff_arch_06_09.dart`; the member actor is checked against its cached role before the handler; the `sync` actor may apply pulled changes in any workspace the device syncs |
| FF-ARCH-10 no raw UI strings | 44 left in 9 files, none above the baseline (unchanged in P04b); the sharing UI has none |
| Share egress classification (ADR-0059) | see the second exit-gate row |
| Store upgrades (v12 → v13 → v14 → v15) | `profile_directory_test.dart` "an existing v$from profile store upgrades to the latest schema, data intact (…)" for every version from v2 to v14; `spaces_store_test.dart` "upgrade v12 -> v13: the last synced copies belong to the workspace that was synced" |

## Universal DoD

| Line | Status |
|---|---|
| Builds on Windows and Android; analyze clean | the owner ran both platforms in T14 (`p04b/t14-two-person-run`); `dart analyze` / `flutter analyze` are clean in every package |
| All phase tests pass | foundation 13, time_kernel 92, domain 83, application 3, infrastructure 486 (plus the local Supabase groups: 55), ui 315, app 34; pgTAP 195 (local, 2026-11-04); CI green on `main` at T14's merge |
| Mutation checks on the new logic | run one at a time per task: T8 16/16, T9 17/17, T10 17/18, T11 15/19, T12 23/24, T13 12/13, T14 finding 1 8/8, finding 2 12/12. The ones not killed are recorded with the reason in their ADR (mostly equivalent: for example a viewer's device skipping its own card, whose write would be refused anyway) |
| ADRs | 0060 (spaces in one store, v13), 0061 (server), 0062 (keys), 0063 (space sync), 0064 (sharing commands, v14), 0065 (UI and members' names, v15; amendments for T14 findings 1 and 2) |

## T14 findings (the owner's two-person run)
1. **A member's name was empty at joining**: the name sealed for the owner was the profile's display name, which profiles do not have in practice. Fixed: "Join a space" asks for the name (ADR-0065 amendment).
2. **A shared space's "Changes to review" were never shown**: the merge wrote them, but only the personal sync's list existed. Fixed: the space bar and the space page show and close them (ADR-0065 amendment 2).

The headless tests had passed in both cases: the first because the tests set the profile's name, the second because they read the review rows directly. Details: [p04b-two-person-run.md](p04b-two-person-run.md).

## Device checks (T14, the owner, 2026-11-04)
All 19 steps of [p04b-two-person-run.md](p04b-two-person-run.md) as expected, with account A on Windows and account B on Android against the hosted project: create, invite (both kinds), join, let in, names, move in, edit both ways, a conflict with "Take the other", assign and "Assigned to me", viewer and back, a rules notice, removal under both leaving rules, a used code refused, and back to A's own profile. Times (B12): the space on B after approval under 1 s; changes 10–45 s; "Sync now" on one side shows the other side's changes at once. **The owner's decision: the 1-minute delay is acceptable; Realtime is left for later.**

## Known limits carried out of P04b
- The `lifeflow://join/` link and the QR do not open the app; the code or the link is pasted (no scanner, as in P04a).
- Not every edit control is hidden from a viewer; the main "+" buttons and moves are, and other edits are refused with a message.
- The owner's list of members is read when the space page opens or on its "Sync now".
- Others see a change within a minute while the space is shown (B12); a "Sync now" does not tell the other device. No sync while the app is closed (D8).
- A record changed on one device while another moves it ends up where the change was made (ADR-0064). Goal links are not moved and may point across workspaces.
- A rules change between asking to join and being let in shows no notice (ADR-0064).
- A hostile editor can overwrite another member's name card (a shown name, nothing else) (ADR-0065).
- Assignment is not shown on the event or calendar views.
- A new account key from another device makes the old wrapped keys unusable until an owner wraps them again (ADR-0061).
- The app has no account deletion; deleting an owner's account on the server would delete their spaces (ADR-0061).
- Left out by B11: comments, an activity feed, email invitations, Realtime, event attendees, mixed personal and shared views, public links, moving part of a guest profile.

## Risks
- **R-PERMISSION** (main risk): enforced on the server first (RLS and role-checked functions), 158 pgTAP assertions for P04b with crafted requests and every role, one contract on both servers, and the role on the device; register updated.
- **R-KEY-LOSS / R-KEY-LEAK**: one construction (X25519, HKDF, AES-GCM) from a licensed library; keys wrapped per member; a rotation on every removal, tested with the removed member's old key; register updated.
- **R-DATA-LOSS**: one command per move with ids kept and a confirmation fingerprint; the rotation drops the old rows only after everything is sealed again; leaving follows the space's rule, with export first where it allows; register updated.
- **R-OFFLINE-SYNC**: the two-person run again found what synthetic tests did not (the empty name, the unseen review); both fixed with regression tests; register updated.
- **R-SCOPE**: B11 kept the scope; the owner's T14 decision leaves Realtime for later.
- **R-CLOUD-COST**: B13's limits are checked on the server; still the free plan.
- **R-CI-FLAKE** (new): the app job failed once in CI on a commit with no app change and passed on re-run; the log was not read. If it happens again, read the log before re-running; added to the register.

## Owner sign-off
- [x] Device checks above (owner, 2026-11-04).
- [ ] CI green on the T15 branch head.
- [ ] Owner approves P04b as done.
