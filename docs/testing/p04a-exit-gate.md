# P04a exit-gate evidence (sync of one account's devices)

Maps each line of the P04a exit gate ([p04-plan.md §1](../roadmap/p04-plan.md)) and the P04 anchors of the definition of done ([definition-of-done.md](definition-of-done.md)) to the tests and checks that prove it. Status: **signed off by the owner, 2026-11-16**.

How to reproduce:
- `dart test` in `packages/foundation|time_kernel|domain|application|infrastructure`.
- `flutter test` in `packages/ui` and `apps/lifeflow_app`.
- `dart run tools/fitness/<script>.dart` for each fitness script.
- The server:
  - `supabase db start`, then `supabase test db` (pgTAP).
  - `dart test test/remote_contract_test.dart` in `packages/infrastructure` with `LIFEFLOW_TEST_SUPABASE_URL` and `LIFEFLOW_TEST_SUPABASE_ANON_KEY` set to a local stack.
- CI runs all of this on every push (`.github/workflows/ci.yml`; job `supabase-db` for the server).

Branch at T7: `p04/t6-t7-exit-gate`, on `main` at `26ac6b4` (T5 with the T6 findings merged).

## Exit gate (p04-plan.md §1)

| Line | Proof |
|---|---|
| Offline changes survive sync, with an idempotent replay (GS-17, SYNC-001, OUTBOX-001) | `infrastructure/test/sync_engine_test.dart`: "GS-17: offline changes on both devices arrive; a lost answer is retried and stored once"; "offline or signed out: nothing is lost; the next sync sends it"; "a page that cannot be applied is not half-applied, and the cursor stays"; "property: random edits and syncs on three devices converge, no record and no completion lost" (8 seeds × 40 steps). Server: `remote_contract_test.dart` "a replay is accepted once …" on the in-memory server and on local Supabase. Every written record has its own outbox row (`atomic_set_test.dart`, `sync_contract_test.dart`). |
| A delete syncs as a tombstone; a purge after retention propagates (GS-14, SYNC-004) | `sync_engine_test.dart` "GS-14: a delete syncs as a tombstone; a purge after retention reaches every device"; `remote_contract_test.dart` "a delete is a tombstone; nothing is purged within the retention" and "in memory: after the retention a purge drops the content and keeps the tombstone (GS-14)"; pgTAP `sync_records.test.sql` (a purge keeps the tombstone; another account cannot purge). |
| Conflicts detected by version, never by time (SYNC-002) | The server checks each record's base version in `push_records` (pgTAP; `remote_contract_test.dart` "… a stale base is a conflict naming the server's version"). The device merges against the last synced copy (`sync_base`); time only breaks a tie between two changes that both happened (`domain/test/sync_merge_test.dart` "the same field: the newer side (version, then time, then device) …"). |
| Resolved per data type, never by a global last-writer-wins (SYNC-003; GS-08's rule on P04a's own types, D9) | `domain/test/sync_merge_test.dart`: different fields both kept, a task's status never goes down, notes and schedules as one value with a review, delete beats edit with the edit kept (D7), occurrence ticks and measurements never undone or mixed, and a property that either device merging gives the same record. `sync_engine_test.dart`: "SYNC-003 …", "notes and schedules changed on both …", "D7 …", "measurements are append-only …". Changes to review in the UI: `sync_review_test.dart` and `ui/test/sync_flow_test.dart`. |
| Nothing leaves a device unencrypted; a second device opens the data only with the account's key (D12, D15) | `sync_engine_test.dart` "the server sees no content: ids are opaque, records are sealed"; `sync_keys_test.dart` (sealing refuses another key, id, version or changed byte; server ids say nothing; the recovery key and passphrase unlock, wrong ones are refused; "end to end: A turns sync on, B joins with the 24 words; the server holds nothing readable"); `sync_setup_test.dart` (a wrong key, a mistyped word or a new key on the account is refused or noticed). |
| The data backend is decided (ADR-0003 data half) | [ADR-0052](../adr/0052-sync-backend-and-end-to-end-encryption.md) after spikes S-03 (RLS), S-04 (sync harness) and S-15 (encryption); the owner's D2, D3, D12 and D15. |
| Restricted data never syncs; the egress checks the classification (D4, PRIV-001/003; FF-ARCH-08 prepared) | [ADR-0059](../adr/0059-sync-egress-classification.md): `domain/test/data_classification_test.dart`; `sync_review_test.dart` group "egress" (every kind is classified, an unknown one is Restricted; a health-sourced measurement is never sealed or sent, while a typed one syncs). |

## Invariants

| Invariant | Proof |
|---|---|
| LF-INV-SYNC-001 idempotent replay | GS-17 above (a lost answer: the retry is the same operation ids, stored once); operation ids are UUID v5 of device, kind, id and version |
| LF-INV-SYNC-002 version-based detection | see the exit-gate row above |
| LF-INV-SYNC-003 per-type resolution | see the exit-gate row above |
| LF-INV-SYNC-004 tombstones, purge after retention | GS-14 above |
| LF-INV-OUTBOX-001 every change in the outbox | `atomic_set_test.dart` (every operation of every handler, the sync apply, setup and review commands included: each written record has an outbox row of its own) |
| LF-INV-GOV-001 one gateway | pulled pages are one `ApplySyncChanges` command of actor `sync` (`sync_engine_test.dart` "pulled changes go through the gateway as actor sync, which may do nothing else"); setup and review are commands too (`sync_setup_test.dart`, `atomic_set_test.dart`) |
| LF-INV-ID-001 ids never change | joining keeps every id (`sync_setup_test.dart` "join and merge: both devices' records, with their ids …"); app integration test "P04 T5: …" |
| LF-INV-PRIV-001/003 default-deny egress, checked at the egress | ADR-0059 tests above (sync egress; the AI egress is P06) |
| LF-INV-SEC-001 secrets only in secure storage | `sync_keys_test.dart` "a setup is kept only when the user confirms it; the key is in secure storage only"; the app integration test checks the key slot; the access token never leaves the auth gateway (ADR-0058 §7) |

The matrix rows are in [invariant-test-matrix.md](../invariants/invariant-test-matrix.md) (P04a status).

## Server (Supabase)

| Check | Proof |
|---|---|
| An account sees and changes only its own workspaces (RLS, R-PERMISSION) | pgTAP `supabase/tests/database/*.test.sql`: 37 tests, allow and deny, also through the functions; `remote_contract_test.dart` "another account sees and changes nothing of the workspace" and "without a session nothing is reachable" |
| Two devices end to end on Supabase (the owner's steps 1, 3 and 4) | `sync_supabase_e2e_test.dart`: 4 tests on local Supabase in CI (real-size notes, a moved and done occurrence, notes conflict and "Take the other", delete against rename); it fails if the base64 fix is undone | `remote_contract_test.dart`: 20 tests, the same cases on both, with local Supabase in CI. A 5000-byte record comes back exactly (T6 finding 2). |
| Migrations applied to the owner's project | `20261114000001`–`03` pushed by the owner (`supabase db push --remote`, 2026-11-16) |

## Fitness functions and governance

| FF / rule | How it is checked |
|---|---|
| FF-ARCH-01 pure domain | the merge and the classification are pure Dart in `domain` |
| FF-ARCH-04 UI isolation | the UI talks only to `SyncService` (no key, no server) |
| FF-ARCH-06 atomic set for the new handlers | `atomic_set_test.dart`, with fault injection: `SyncApplyHandler`, `SyncSetupHandler` (turn on, turn off, join, undo) and `SyncReviewHandler` (keep, take the other); all in the registry `ff_arch_06_09.dart` checks |
| FF-ARCH-07 licenses | 134 shipped packages and libraries; new in P04: `cryptography` (VS-42), the BIP-39 word list (VS-43), the zxcvbn list (VS-44), `unorm_dart` (VS-45), `qr_flutter` and `qr` (VS-46) |
| FF-ARCH-08 prepared | ADR-0059 (the sync egress); GS-16 itself is P06 |
| FF-ARCH-09 authorize before domain | `ff_arch_06_09.dart`; the `sync` actor may run only `ApplySyncChanges`, only on a workspace this device syncs, under its own device id |
| FF-ARCH-10 no raw UI strings | 44 left in 9 files, none above the baseline; the sync screens have none |
| Store upgrades (v9 → v12) | `profile_directory_test.dart`: every version from v2 to v11 upgrades with every column of every table checked; v9 → v10 moves the result policy; v11 → v12 keeps the outbox rows under the new key |

## Universal DoD

| Line | Status |
|---|---|
| Builds on Windows and Android; analyze clean | The owner ran both platforms from the T5 branch during T6. `dart analyze` / `flutter analyze` are clean in every package. |
| All phase tests pass | foundation 13, time_kernel 92, domain 82, application 3, infrastructure 428 (with the local Supabase groups: contract 20, end to end 4), ui 301, app 33; pgTAP 37 (local, 2026-11-16) |
| Mutation checks on the new logic | T4 14/14, T5 24/24, T6 fixes 2/2, ADR-0059 5/5 killed (sequential runs, recorded in the ADRs) |
| ADRs | 0052 (backend + end-to-end encryption), 0053 (schema v10 sync contract), 0054 (keys), 0055 (server port and contract), 0056 (engine, v11), 0057 (joining and leaving), 0058 (UI, scheduler; T6 findings, v12), 0059 (egress classification) |

## T6 findings (on the owner's two devices)
1. **The outbox key without the kind** refused any pulled page holding an occurrence's exception and its completion, which share one id. Fixed with schema v12 (ADR-0058).
2. **Base64 line breaks from the server**: no real-size record could be pulled. Fixed in the HTTP gateway; a contract test with a 5000-byte record now guards it (ADR-0058).
3. **The task page kept old notes** when notes arrived from the other device while its notes field had the focus. Fixed: leaving the field rebuilds the page (ADR-0058).

Both had passed the headless tests, which used small records and no habit occurrences on both devices. After the fixes the owner reported that sync works between Windows and Android (2026-11-16).

## Device checks (T6, the owner)
- [x] Windows turns sync on with a recovery key; Android joins with the 24 words and merges; after Sync now each device shows the other's tasks (owner, 2026-11-16, after the two fixes).
- [x] An edit on one device shows on the other after a return to the app or Sync now (owner, 2026-11-16).
- [x] Offline on Android: the status says so; the changes go once back online; nothing lost (owner, 2026-11-16).
- [x] Notes changed on both devices offline: a "Changes to review" item appeared (owner, 2026-11-16). After "Take the other" the owner saw each device with its own note. Checked by the agent on the real stack (two devices, local Supabase with the project's migrations, the real HTTP gateway, real-size records: `sync_supabase_e2e_test.dart`): after Sync now on both, the notes are the same; before its next sync the other device still shows the kept note (D8). The task page also kept showing old notes when its field had the focus as they arrived; fixed (T6 finding 3, ADR-0058).
- [x] Deleted on one device, renamed on the other: in the trash with the new name, and a review item (owner, 2026-11-16).
- [x] "Only when I tap Sync now" on Android: nothing arrives until Sync now (owner, 2026-11-16).
- [x] Speed (D8): Sync now on Android takes about 1 s, at most 2–3 s (owner, 2026-11-16).
- [x] Sign out on Android: the data stays (owner, 2026-11-16). Signing out in the middle of a sync could not be timed by hand, since a sync takes about a second; that case is covered headless (`sync_engine_test.dart` "offline or signed out: nothing is lost; the next sync sends it").

## Known limits carried out of P04a
- No QR scanner (owner decision 2026-11-16): the second device types or pastes the 24 words.
- No device name or device list (D9 item left for P04b).
- No sync while the app is closed (D8); the automatic schedule runs only while it is open.
- Restricted data has no consent path yet (P08).
- "Take the other" on a whole value (a schedule, a reminder) replaces the whole value, not single fields.
- Undo of a join does not take back what a merge already uploaded (ADR-0057).
- Sharing with other people, members and roles: P04b.

## Risks
- R-OFFLINE-SYNC: per-type merges are pure and property-tested; the T6 findings showed that real data finds what synthetic data does not, so the device checks stay part of the gate; register updated.
- R-DATA-LOSS: nothing is overwritten without a three-way check; delete against edit keeps the edit; a failed page leaves the cursor in place; register updated.
- R-PERMISSION: RLS from the first table, pgTAP allow/deny in CI; P04b extends it per role.
- R-KEY-LOSS (new in P04): a lost recovery key or passphrase with no device left makes the server copy unreadable. Mitigated by the two-word confirmation, saving to a file, a full local copy on every device, and "Delete my data from the server" to start again; added to the register.
- R-LICENSE-SCAN: every new package recorded before its merge (VS-42–46).

## Owner sign-off
- [x] Device checks above (owner, 2026-11-16; step 3 checked by the agent on the real stack, at the owner's request).
- [x] CI green on the T7 branch head.
- [x] Owner approves P04a as done (2026-11-16).
