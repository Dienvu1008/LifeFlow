# Spike Results

- Status: S-05 PASS on Windows and Android (2026-11-09, P02 T0). MVP-blocking spikes complete (S-03a PASS, S-01 PASS, S-02 plain PASS; encryption-at-rest resolved in P01 task T5 via ADR-0021 — Android encrypted, Windows MVP plain + tracked exception). This is the canonical results record on `main`; the throwaway POC code lives on the `spike/*` and `scaffold/p01-skeleton` branches (not merged to `main`).
- Related: [spike-plan.md](spike-plan.md), [../FINAL-REPORT.md](../FINAL-REPORT.md) §19

Fixed entry format: **Question / Hypothesis / What was done / Measured result / Success or Failure / Decision / ADR update or Open+escalation / Human gate date.**

---

## S-03a — Auth
**PASS on Windows (2026-11-04):** GitHub sign-in via SDK-managed PKCE (S256) + fixed loopback; session in secure storage survives offline restart; no token in logs. Decision: Supabase Auth is the MVP auth provider (ADR-0003 auth half Accepted). Follow-up: Android + email baseline.

## S-03 — Supabase RLS for synced, end-to-end encrypted records
**PASS (2026-11-14, local Supabase 17.11 in Docker; branch `p04/s03-rls`).**
- **Question:** Does Supabase row-level security keep one account's synced records away from every other caller, also through the write functions, with acceptable complexity and speed? (p04-plan.md S-03; R-PERMISSION.)
- **Hypothesis:** one table of opaque, sealed records per workspace (D12) with an owner check is enough for P04a; RLS policies stay small because the server never reads content.
- **What was done:** migration `supabase/migrations/20261114000001_sync_records.sql`:
  - `account_workspaces` (the wrapped workspace key, the unlock kind of D15, the last change number);
  - `sync_records` (opaque 64-hex id, version, per-workspace change number `seq`, deleted flag, sealed bytes);
  - RLS: select only within the caller's workspaces; no direct writes of records;
  - `push_records` (version check per record, replay of an accepted operation is a no-op, change numbers from a row lock per workspace so they commit in order) and `purge_records` (only after 90 days; the tombstone stays and gets a new number). Both are security definer and check `auth.uid()` owns the workspace first.

  pgTAP suite `supabase/tests/database/sync_records.test.sql`, 29 assertions: A's own reads and pushes, replay, conflicts by version, a version that must go up, opaque ids only, batch limit, no direct writes, B reads and writes nothing of A (also through both functions), B cannot make a workspace for A, anon has no rights at all, purge after retention, deleting the workspace deletes its records. CI job `supabase-db` runs it on every push.
- **Measured result:** 29/29 pass. SQL mutations 9/9 killed: the owner check, the select policy, the replay check, the retention, a direct-write grant, the workspace policy, the version check, and anon execute rights (killed after adding a privilege assertion). Speed on the development PC: 10 000 records of 300 bytes pushed in 20 batches in 2.7 s; pulling all 10 000 in 8 ms; pulling the last 50 in under 1 ms.
- **Success.** Membership roles for sharing (P04b) extend the same policies; they are not part of this spike.
- **Decision:** feeds ADR-0052 (data half of ADR-0003) with S-04 and S-15.
- **Findings:**
  - On Windows, Hyper-V/WSL reserve port ranges (`netsh int ipv4 show excludedportrange protocol=tcp`). The default local Supabase ports 54320–54329 fell inside one, so the local stack uses 55320–55329 (`supabase/config.toml`).
  - The same reservations cover **127.0.0.1:53682, the fixed loopback port of Windows sign-in (S-03a)**: binding it fails on the development PC now. Fixed on the owner's go-ahead (branch `p04/fix-loopback-port`): the system picks a free loopback port for each sign-in (RFC 8252 §7.3) and the Supabase project allows `http://127.0.0.1:*/callback` (ADR-0003 update 2026-11-14).
- **Human gate:** owner review with the other P04 spikes.
## S-04 — Two-replica sync harness with deliberate conflicts
**PASS (2026-11-14; branch `p04/s04-sync-harness`).**
- **Question:** Can outbox/inbox sync reconcile deliberate offline conflicts per type (ADR-0015, p04-plan.md D6/D7) without data loss, with an idempotent replay? (p04-plan.md S-04; R-OFFLINE-SYNC.)
- **Hypothesis:** the P01–P03 outbox, versions and tombstones are enough: push what pending outbox rows touched with the last synced version as base; pull in change-number order; merge per type only when this device also changed the record.
- **What was done** (the prototype was replaced by the sync engine in P04 T3, ADR-0056, and removed): a prototype in `packages/infrastructure/test/sync_spike/`:
  - `fake_server.dart`: the semantics of the S-03 SQL functions (version check, replay accepted once, change numbers, purge keeps the tombstone), plus a dropped connection and a lost answer;
  - `replica.dart`: push and pull over a real profile store, the last synced copy per record, deterministic operation ids per (device, record, version), local purge;
  - `resolve.dart`: the per-type rules as one pure function of (last synced, this device, server).

  `sync_spike_test.dart` runs two or three real stores of one workspace (copies of one file, as after joining), 11 tests: GS-17 with a lost answer and a dropped connection; different fields of one task both kept; the same field converges; a completion never lost to an edit; notes on both devices (one kept, the other for review); delete against edit (deleted, the edit kept in the trash, a review); a schedule as one value with a review; measurements append-only; pure rules for occurrence ticks and status; GS-14 (tombstone, then a purge reaching both devices, the tombstone kept on the server); a property test of 12 seeds × 40 random edits and syncs on three devices (always converged, no task and no completion lost).
- **Measured result:** 11/11 pass; the property run takes about 10 s. Mutations 10/10 killed (status precedence, completion rule, notes review, delete rule, whole-value review, field choice, the take-remote rule, deterministic operation ids, local purge, the server's version check). An eleventh (a set of merged records) survived and showed the set was redundant: a merged record keeps its outbox row pending. It was removed.
- **Success.** Conflicts are found by version only (SYNC-002) and resolved per type (SYNC-003); a replay is accepted once (SYNC-001).
- **Findings for T1/T3:**
  - **An ended focus session writes its execution record without an outbox row of its own**, so that record would never be pushed. A guard test pins it (`missing == ['executionRecord']`); T1 makes every written record carry an outbox row and the guard expects none.
  - Profile settings that sync (D4, for example the manual-results setting) are not a record kind yet: T1 adds them.
  - The prototype reads and writes rows through the record registry; T3 applies pulled rows as commands of actor `sync` through the gateway (GOV-001) and keeps the last synced copies in a `sync_base` table.
  - Ties (same version on both devices) fall back to the later update, then the device name, so every device picks the same value.
- **Decision:** feeds ADR-0052 with S-03 and S-15.
- **Human gate:** owner review with the other P04 spikes.
## S-15 — End-to-end encryption of synced records
**PASS (2026-11-14, Windows; branch `p04/s15-e2e`). Android speed still to measure on the device (T6).**
- **Question:** Can every synced record be sealed on the device so the server and its operator read nothing (p04-plan.md D12), with a key a second device gets from a recovery key or a passphrase (D15), fast enough for 10 000 records?
- **Hypothesis:** AES-256-GCM per record with the server id and version as associated data, a workspace key wrapped by an unlock key, and Argon2id for passphrases, from the `cryptography` package (Apache-2.0, VS-42).
- **What was done:** prototype `packages/infrastructure/test/sync_spike/e2e.dart`:
  - `RecordSealer`: keys for sealing and for server ids derived from the workspace key with HKDF-SHA-256; server id = HMAC-SHA-256 of kind and local id (64 hex, the S-03 format); seal = AES-256-GCM with a fresh 96-bit nonce and `serverId:version` as associated data;
  - the workspace key wrapped by an unlock key (AES-256-GCM, the workspace id as associated data);
  - unlock from a recovery key (256 random bits as 24 BIP-39 words with an 8-bit checksum, VS-43) or from a passphrase (Argon2id, 19 MiB, 2 passes, 1 lane: OWASP's minimum);
  - the S-04 replica seals on push and opens on pull when given a sealer.

  `sync_e2e_spike_test.dart`, 7 tests: round trip with a fresh nonce; another key, id, version or a changed byte refused; server ids reveal nothing and cannot be computed without the key; 24 words round trip, a wrong word refused, about 255 of 256 swapped words caught by the checksum; recovery key and passphrase both unwrap, switching re-wraps only (old records still open); end to end (A turns sync on, B joins with the words, an edit goes both ways, and no title, note, local id, kind or workspace id is readable in the server's rows); speed.
- **Measured result (development PC, Dart VM, pure-Dart AES-GCM):** 10 000 records sealed in 0.51 s and opened in 0.37 s; a sealed record of about 300 bytes of content is 350 bytes; one Argon2id derivation 106 ms. Mutations 6/6 killed (associated data on seal and on open, the checksum, a fixed nonce, the workspace binding of the wrapped key, the kind in the id hash).
- **Success** on Windows. Android: the same code runs there (pure Dart); `cryptography_flutter` can switch to the platform's AES if T6 finds it slow.
- **Decision:** feeds ADR-0052.
- **Findings for T1b:** the passphrase check (D15 "minimum strength") is still to be chosen (a length rule plus a list of common passwords is the proposal); the recovery key must be confirmed by the user (for example by typing two of the words) before sync starts; the BIP-39 list ships as a Dart constant with its MIT notice.
- **Human gate:** owner review with the other P04 spikes.

## S-16 — Members of a shared space on the server, and their keys (P04b)
**PASS (2026-11-16, local Supabase in Docker; branch `p04b/s16-members-spike`).**
- **Question:** Can the server let the members of a shared space read it, let only owners and editors write, keep membership, roles, invitations and rules changeable by the owner only, even against crafted requests (R-PERMISSION, OQ-V5), at a speed fit for pulls? Can the space key reach each member, and only them, with the library already in use (p04b-plan.md B5, B7, B8)?
- **Hypothesis:**
  - Server: a `space_members` table, a security-definer helper for the caller's role, RLS for reads, owner- or role-checked security-definer functions for every write, and no direct write grants.
  - Keys: X25519 + HKDF-SHA-256 + AES-256-GCM per member from `cryptography` 2.9.0 (VS-42).
- **What was done:**
  - **`supabase/tests/database/s16_spaces_spike.test.sql`** builds the spike's schema inside the test's transaction and rolls it back, so the migrations are untouched. (T9 replaced both spike files with the migration `20261117000001_spaces.sql` and `spaces.test.sql` / `spaces_speed.test.sql`; see ADR-0061. They remain in the git history at `84a5eb3`.)
    - Tables: `account_public_keys`, `account_private_keys`, `spaces` (with the leaving, export and invitation rules), `space_members`, `space_invitations` (a hash of the code only).
    - Functions: `create_space`, `invite`, `peek_invitation`, `accept_invitation`, `approve_member`, `set_my_wrapped_key`, `remove_member`, `leave_space`, `set_role`, `hand_over`, `set_space_rules`, `rotate_space_key`. `push_records` and `purge_records` were extended to check the role.
    - 79 assertions over the owner, an editor, a viewer, someone waiting for approval, someone who joined at once, a removed member, a stranger and a caller without a session:
      - reads and writes by role, including a viewer's push refused by the server;
      - crafted direct table writes refused (making oneself owner, adding a member, changing the rules, deleting invitations, deleting the space);
      - owner-only actions refused to an editor;
      - rules seen before joining and after a change;
      - a code used once, its wrapped key erased on use;
      - removal and a rotation wrapped for exactly the active members;
      - leaving, handing over the owner role (one owner at a time);
      - the 10-member limit;
      - deleting the space removes everything of it;
      - a P04a personal workspace unchanged.
  - **`s16_spaces_speed_spike.test.sql`**: 20 000 records in the space plus 20 000 of other accounts, 10 members; a page of 1000 and a full count timed under two read policies.
  - **`packages/infrastructure/test/spike_s16_keys_test.dart`** (T10 replaced it with `space_keys.dart` and its tests; see ADR-0062), 5 tests:
    - the private key sealed with the personal workspace key opens only with that key and for that account;
    - the space key wrapped for one member opens for that member only, in that space only, and a changed byte is refused;
    - a "join at once" code opens the key, and its hash (what the server keeps) does not;
    - after a rotation, the removed member's old key opens nothing new and cannot even compute the new server ids;
    - speed.
- **Measured result:**
  - The read policy must be **by set** (`workspace_id in (select my_workspace_ids())`, the function runs once per query), not **per row** (`space_role(workspace_id) is not null`). On 22 222 visible rows, a page of 1000 took 1.0 ms against 10.9 ms, and a full count 5.5 ms against 400–460 ms.
  - Keys (development PC, pure Dart): wrapping the space key for 10 members took 15 ms; opening it 10 times took 8 ms. A wrapped key is 93 bytes.
  - Mutations 7 of 7 killed on the server side: a viewer allowed to push, private keys readable by others, an editor passing the owner check, a rotation not wrapped for every member, a waiting member counted as active (in the role helper and in the set policy), an invitation code usable twice.
- **Success:** PASS. OQ-V5 is answered: membership RLS on Supabase works, and is fast with a set-based policy.
- **Findings for T9 and T10:**
  1. **T9:** make the spike's functions real migrations. `must_own` becomes a private schema function, since the spike used `pg_temp`. Use the set-based read policy. `account_workspaces.account_id` follows the owner when the space is handed over. Add `unlock_kind` `space`.
  2. **T10:** a member's private key is sealed with their personal workspace key. Resetting personal sync (a new personal key, ADR-0054), or deleting the personal server copy, must seal it again or keep it. Turning personal sync off leaves the shared spaces unreachable, which matches B5 ("sync must be on").
  3. **T10:** a rotation also changes every server id (the id HMAC comes from the space key). The owner's device uploads the space again under the new key. The old rows go only after the new copy is complete (R-DATA-LOSS).
  4. With end-to-end encryption, the server checks roles only at the level of "owner or editor may write". Finer rules stay in the app (as planned, p04b-plan.md §4).
  5. The older pgTAP files count every row, so locally they need `supabase db reset` before `supabase test db` once other tests have left accounts behind. CI always starts from a fresh database.
- **Decision:** feeds the P04b ADRs of T9 and T10.
- **Human gate:** owner review.

## S-07 — Block editor for documents (P05)
**PASS with flutter_quill (2026-11-04, the owner on Windows and Android; branch `spike/s07-editor`, `0b4e623`). super_editor fails on Android speed. The owner confirms the pick (human gate).**
- **Question:** Which MIT/BSD editor fits P05a's documents (ADR-0020): our block format in and out exactly, the block types of p05-plan.md, the `[[` link, a custom attachment block, undo/redo, Vietnamese typing, a 50-page document, on Windows and Android?
- **Hypothesis:** super_editor (ADR-0020's lead candidate, a block model) fits best; flutter_quill (a Delta model) is the fallback.
- **What was done:**
  - `spikes/s07_common`: LifeFlow's own block format (paragraph, heading 1–2, bullet, numbered, to-do, image; runs with bold, italic and a `[[…]]` link; one JSON body, deterministic: fixed key order, sorted marks, merged runs), a Vietnamese sample and a 50-page document (550 blocks, 184 000 characters).
  - Two probe apps, one per editor (they cannot share one app: super_editor 0.3.0-dev.52 needs `dart_quill_delta` ^9.4.1, flutter_quill 11.6.0 needs ^10.0.0), each with an adapter to and from the format, a toolbar, undo/redo, the `[[` picker, an "attachment on another device" block, autosave after 10 s, and a round-trip check.
  - Headless: the format and both adapters round-trip exactly (sample and 50 pages), two adjacent links stay two; 50 pages through each adapter in 30 ms (super_editor) and 37–47 ms (flutter_quill).
  - The owner ran both on Windows and Android, 12 steps each, twice (debug, then profile after the probes were fixed).
  - Round 2 fixed the probes, not the libraries: super_editor's to-do builder is not in its default builders (it needs the editor), which caused the "not a DocumentComponent" error; its default spacing (18 px text, 24 px above each paragraph) was tightened. flutter_quill's B and I buttons set the mark instead of toggling it; links were styled (blue, semi-bold, no underline); a page width of 680 px was set; a text line is added after an inserted image.
- **Measured result (owner, profile builds):**

| | super_editor 0.3.0-dev.52 | flutter_quill 11.6.0 |
|---|---|---|
| 50 pages, first frame | Windows 293 ms (debug); Android 421 ms | Windows 136 ms (debug); Android 458 ms |
| Scrolling and typing on Android | still lagging, "uncomfortable for daily use" | smooth, "usable every day" |
| Scrolling on Windows | text shakes while scrolling, dizzying | smooth |
| To-do on Android | ticks, but the box and the text are misaligned | correct |
| Links | blue, Wikipedia-like (default) | the same after styling |
| B / I twice | removes the mark | removes it (after the probe fix) |
| Cursor after an image | shown | shown only after Enter or an arrow key |
| Page width on a wide screen | 640 px by default | 680 px after setting it |
| Block ids | kept by the library | none: the adapter keeps them by line position, so a line inserted above shifts the ids below |
| Releases | only developer releases since 0.2.7 (2024); Windows "unverified" in its README | 11.6.0, September 2026, regular releases |
| Android build | needs a workaround (super_keyboard compiles against API 34; compileSdk 36 forced) | builds as is |
| New packages against the app | 46, including test and code-generation packages (`mockito`, `analyzer`, `golden_toolkit`) | 28 |
| Licenses of everything it brings | MIT, BSD-3-Clause, Apache-2.0 | MIT, BSD-3-Clause, Apache-2.0 |

- **Success or failure:** flutter_quill meets every criterion of ADR-0020 that matters for daily use. super_editor fails the "Windows + Android, acceptable performance" criterion on Android, and shows two display faults (scrolling shake on Windows, the to-do misaligned on Android).
- **Decision:** **flutter_quill 11.6.0**, pinned, behind LifeFlow's editor port. Consequences for P05a:
  - The stored format stays ours (`s07_common`'s shape becomes T1's), never the Delta, so a later switch does not touch stored documents.
  - Block ids: kept by the adapter by line position since the last load. P05a needs no block-level links, so a shifted id loses nothing; they are not promised to be stable (ADR at T1).
  - Cursor after an image: an image is always followed by a text line (the adapter adds one), so there is always a place to type.
  - The link style, the page width and B/I toggling are set in our wrapper (as in round 2).
  - The 28 new packages get their inventory lines and a verified-sources row before T8's merge (FF-ARCH-07).
- **ADR update:** ADR-0020 amended: flutter_quill instead of the lead candidate super_editor, with the measurements above.
- **Human gate:** the owner ran both editors (2026-11-04, two rounds) and judged flutter_quill fit for daily use; pick confirmed by the owner on review of this entry (2026-11-04).

## S-01 — Flutter + Drift
**PASS on Windows (2026-11-04):** CRUD + transaction + persistence across restart + rollback, proven on-device; headless 2/2. Finding → **OQ-STACK-2**: resolved stack is sqlite3 2.9.4 + sqlite3_flutter_libs 0.5.42 (CMake bundling), not sqlite3 3.x build hooks (3.x path not smooth on Flutter yet). Android a follow-up.

**Update (P01 T6a, 2026-11-06):** the real app (`apps/lifeflow_app`, Flutter 3.47.2) now resolves `drift_flutter 0.3.1` → **sqlite3 3.5.2 via build hooks**; `sqlite3_flutter_libs 0.6.0+eol` and `sqlcipher_flutter_libs 0.7.0+eol` are empty end-of-life stubs. The **plain** Windows debug build succeeds on this path (`flutter build windows --debug`), and the app runs. So the S-01 finding is superseded for the plain build. What still failed in S-02 is specifically the `sqlite3mc` source on the hook; that is what T6b must test for Android encryption.

---

## S-02 — Migrations + FTS5-under-encryption
- Branch: `scaffold/p01-skeleton`. Harness in `packages/infrastructure/` (on the skeleton). Time-box 1–3 pd.
- **Question:** Do Drift guided migrations work, and is FTS5 available (incl. MATCH) — and does FTS5 work under the **encrypted** build (OQ-V10), given the stack is sqlite3 2.x (OQ-STACK-2)?
- **Hypothesis:** FTS5 is compiled into Drift's bundled sqlite3; a v1->v2 migration preserves data; encryption on current Flutter uses the SQLCipher CMake path (`sqlcipher_flutter_libs`), which includes FTS5.
- **What was done (agent, headless, this environment):** Built the `infrastructure` Drift database (notes + FTS5 virtual table + a v2 `tags` table + a v1->v2 migration). Wrote `s02_fts_migration_test.dart`. `dart analyze` clean; `dart test` = **3/3 passed**: (1) `ENABLE_FTS5` present in `PRAGMA compile_options`; (2) FTS5 `MATCH` returns the right row, non-match empty; (3) v1->v2 migration adds `tags` with v1 data preserved. This resolves OQ-V10 for the **plain** build. Wrote `RUNBOOK_S02.md` for the encrypted-build check.
- **Measured result (plain build, agent):**
  - FTS5 compiled in (ENABLE_FTS5): **PASS**
  - FTS5 MATCH works: **PASS**
  - Guided migration v1->v2 preserves data: **PASS**
- **Encrypted-build attempt 1 (SQLCipher via `sqlcipher_flutter_libs`) — FAILED on Windows (2026-11-04):** `flutter run -d windows` failed at CMake with `Could NOT find OpenSSL (OPENSSL_ROOT_DIR...)`. Finding: SQLCipher's CMake build needs system OpenSSL on Windows (Android bundles it). This is real build friction for the MVP's primary desktop platform.
- **Pivot to direction B (owner decision):** use **SQLite3MultipleCiphers** (MIT, VS-25) — self-contained, no OpenSSL — via the official `sqlite3` 3.x build hook (`source: sqlite3mc`, per sqlite3.dart UPGRADING_TO_V3). This is also what ADR-0016/VS-21 actually specified (the `sqlcipher_flutter_libs` attempt was a detour). Rejected the experimental third-party `sqlite3mc_flutter_libs` (not on pub.dev, license unverified → ADR-0018 default-reject). The wrapper now uses `sqlite3 ^3.0.0` + the hook; `flutter config --enable-native-assets` enabled.
- **Encrypted-build attempt 2 (SQLite3MultipleCiphers via sqlite3 3.x build hook `source: sqlite3mc`) — FAILED on Windows (2026-11-04):** `flutter config --enable-native-assets` + `flutter run -d windows` failed at the CMake `INSTALL.vcxproj` step (`error MSB3073 ... cmake_install.cmake ... exited with code 1`). The 3.x build-hooks path for bundling sqlite3mc does not build cleanly on Flutter Windows in this environment — consistent with the drift author's note that the 3.x-on-Flutter path "is not a smooth experience yet" (OQ-STACK-2).
- **Outcome: encryption-at-rest on Windows is Open (escalated).** Two mechanisms were tried within the S-02 time-box and both hit Windows build-toolchain friction: SQLCipher (`sqlcipher_flutter_libs`) needs system OpenSSL; SQLite3MultipleCiphers via sqlite3 3.x build hooks fails at the INSTALL step. Per the escalate-as-Open rule, the spike stops here rather than extending into a build-debugging feature.
- **Measured result:**
  - Plain build — migrations + FTS5 + MATCH (headless `dart test`): **PASS (3/3)** → OQ-V10 resolved for the plain build.
  - Encrypted build on Windows — attempt A (SQLCipher/OpenSSL): **FAIL (build)**. Attempt B (sqlite3mc/3.x hooks): **FAIL (build)**.
  - Android encrypted build: **not attempted** (Windows is the blocker and the MVP's harder desktop target).
- **Success or Failure:** **Partial.** FTS5 + migrations PASS; encryption-at-rest on Windows is unresolved within the time-box (Open + escalated).
- **Decision:** Do NOT block the MVP-blocking spike gate on this. Encryption-at-rest becomes an explicit early **P01 task** (not an assumed-done item), with a documented fallback: the MVP can ship search via FTS5 on a **plain** (unencrypted) local DB first, and add encryption-at-rest when a Windows-clean mechanism is confirmed (either the 3.x sqlite3mc hook matures, or accept OpenSSL for SQLCipher on Windows, or encrypt at the OS/file level). Android encryption (sqlite3mc/SQLCipher bundle) is expected to work and is verified in P01.
- **ADR update or Open+escalation:** **OQ-STACK-2 stays Open** and is promoted to a P01 blocker-task + a risk (R-ENCRYPTION-WINDOWS). Update needed: `data-architecture.md §4`, ADR-0016 and VS-21 must drop the claim that SQLite3MultipleCiphers-via-build-hooks works as-is on Flutter Windows today, and record the two failed mechanisms + the fallback. LF-INV-SEC-011 (encryption at rest) remains a target but its MVP timing shifts to "as soon as a Windows-clean path is confirmed in P01".
- **Human gate date:** 2026-11-04 — S-02 closed as: FTS5/migrations PASS; encryption-at-rest Windows Open+escalated to P01. No further spike extension.

### S-02 final conclusion (P01 task T5, 2026-11-04)
T5 resolved the encryption-at-rest escalation with **ADR-0021** (owner decision): **option B baseline** — encryption is an injectable executor; **Android encrypted** (SQLite3MultipleCiphers, `PRAGMA cipher` asserted at startup), **Windows MVP plain + tracked exception** (non-silent: startup `StorageSecurity.evaluate` emits a warning and records `atRestEncrypted=false`/`trackedException=true` in diagnostics). **Option A** (a Windows-clean encrypted build) is a time-boxed stretch attempted **after** B merges, never blocking it; if A fails it stays Open and B stands, if A passes a follow-up ADR makes A primary with B as a controlled fallback. **Option C** (system OpenSSL on every Windows build) rejected for the MVP. Mitigations recorded in security-requirements §1a (BitLocker, Restricted-data warning) and data-classification §2a (Restricted not encrypted at rest on Windows MVP). LF-INV-SEC-011 is now verified on Android and tracked-exception on Windows. Headless tests (`storage_security_test.dart`) assert the non-silent warning/flag logic on both postures. **S-02 is fully closed.**

### S-02 follow-up (P01 task T6b, 2026-11-06)
With `sqlite3` 3.5.2 (resolved by the T6a app), the build hook's `source: sqlite3mc` **downloads prebuilt, hash-pinned SQLite3MultipleCiphers binaries** for Windows and Android instead of compiling, so the S-02 attempt-B failure (CMake `INSTALL`, `MSB3073`) no longer applies. Measured on Windows: `dart test` with the real `sqlite3mc` binary encrypts the file (no plain header, no plaintext), rejects a wrong key, and **FTS5 + MATCH work under encryption** (OQ-V10 resolved for the encrypted build); `flutter build windows --debug` with sqlite3mc + flutter_secure_storage + supabase_flutter succeeds and the app runs. **Finding:** `PRAGMA cipher` returns the configured cipher even without a key, so it cannot detect encryption; detection now reads the file header (ADR-0021 update, SR-01e). Android device verification of the encrypted build is part of the T6b gate. Windows remains plain per ADR-0021 until the owner decides on option A.

---

## S-05 — Local notifications on Windows and Android (P02 task T0)
- Branch: `spike/s05-notifications` (throwaway probe app `spikes/s05_notifications`, not merged). Time-box 1–3 pd; used about 0.5 pd.
- **Question:** Do scheduled local notifications fire on both platforms at the minute, with the app open, in the background and **closed**? Can a pending one be cancelled? Can many be pending? Does the device report an IANA zone the kernel knows? (Answers owner decision D8.)
- **Hypothesis:** `flutter_local_notifications` schedules through the OS on both platforms (Android AlarmManager, Windows scheduled toasts), so notifications fire with the app closed.
- **What was done (agent, on the owner's devices, 2026-11-09):** A probe app with `flutter_local_notifications` 22.3.3, `flutter_timezone` 5.1.1 and `timezone` 0.11.2: show now; schedule at +1 and +2 minutes; schedule then cancel at once; 60 pending then cancel all; zone check. Android (Samsung SM-N975F, Android 12) driven over `adb`, evidence from logcat and `dumpsys notification`. Windows 11 driven by a scripted run that exits by itself; evidence from the app log and screenshots of the toast corner (deleted afterwards).
- **Measured result:**

| Check | Android | Windows |
|---|---|---|
| Show now | PASS | PASS once the window has settled (8 s and 15 s after start); a `show` 2 s after start did not appear |
| Scheduled, app open | PASS | PASS (+1 min) |
| Scheduled, app in background | PASS: fired at 16:57:44.003 and 16:58:45.003, both to the second, while a phone call had the screen | — |
| Scheduled, app **closed** | PASS: process killed (`am kill`, no pid); at 17:05:59.002 the system started the process and posted it | PASS: app exited at 17:10:22; the +3 min toast showed at 17:12:02 |
| Cancel a pending one | PASS (never posted, pending 3 → 2) | PASS (never shown, pending 2 → 1) |
| 60 pending, then cancel all | PASS (60 → 0) | PASS (61 → 0) |
| Device zone | `Asia/Ho_Chi_Minh`, known | `Asia/Saigon` (legacy alias), known; resolves like `Asia/Ho_Chi_Minh` |
| Permissions | notifications and exact alarms granted (Android 12) | none needed |

- **Other findings:**
  1. `flutter_local_notifications` **23.0.0** (2 days old) fails to build: it needs Android compileSdk 37, and the installed `android-37.0` platform is not found by the current Android Gradle Plugin. **22.3.3** builds and works. Revisit 23.x with a newer AGP.
  2. Both 22.x and 23.x need **`timezone ^0.11.0`**, so `time_kernel` moves from 0.9.4 to **0.11.2** (done in T0: one API change, `offset` is now a `Duration`; all 72 kernel tests including the GS-04 DST table pass on the new data).
  3. Windows reports **legacy zone aliases** (`Asia/Saigon`). The database resolves them identically; the UI should show a canonical name (T6).
  4. Not measured: behaviour after a **reboot** (Android uses a boot receiver to re-schedule; the app also re-schedules on start, P02 plan §4), Android 14+ exact-alarm default (fallback to inexact is in the probe), and the user's "Force stop" on Android, which by design cancels an app's alarms until it is opened again.
- **Success or Failure:** **PASS** on both platforms.
- **Decision:** D8 resolved: **Windows reminders work with the app closed**, so no foreground-only fallback is needed. Adopt `flutter_local_notifications` **22.3.3** and `flutter_timezone` **5.1.1** (pinned) for T7, behind the `ReminderScheduler` port. Do not rely on an immediate `show` right after app start on Windows; reminders are scheduled ahead. The app re-schedules its rolling horizon on start, which also covers reboots and force-stops.
- **ADR update:** ADR-0028 (timezone 0.11.2); verified-sources VS-32 to VS-34; P02 plan D8.
- **Human gate date:** pending owner review (2026-11-09).
- **Correction (2026-11-10, P02 T8, found by the owner on Windows):** the Windows "app closed" PASS held only because the probe had **shown** a toast before scheduling. In the real app no toast had ever been shown for its app id (`LifeFlow.App`):
  - Windows accepted the scheduled toast, but at delivery its push-notification log said "A local notification failed to be submitted to threadpool: Element not found".
  - Windows had no notification-settings entry for the app id (`HKCU\...\Notifications\Settings\LifeFlow.App`), where the probe's id had one.
  - After one shown toast, the entry exists and a toast scheduled with no LifeFlow process running was delivered at the minute (log: source "Scheduled", "delivered").
  - Fix (ADR-0034): the Windows adapter registers the app id by showing one "Reminders are on" notification when reminders are first turned on or first scheduled, and reports "turned off in Windows settings" when the user did that. Verified end to end: entry removed, real app run once, window closed, reminder delivered at 15:34:00.

## S-08 — PDF viewing (P05b)
**PASS on the owner's Windows and Android (2026-11-04): opening, scrolling, zoom, find, selection and extracted text as expected. D10 (licenses) still to answer.**
- **Question:** Can pdfrx show a PDF kept in a document on Windows and Android, from memory (the file stays encrypted, ADR-0072), with zoom, find, selection and Vietnamese text, under licenses ADR-0018 accepts?
- **What was done:** one probe app, `spikes/p05b_probe` (tabs PDF, DOCX, Voices), with pdfrx 3.0.0 (the newest for Flutter 3.47.2; 3.1.0 needs 3.50). The PDF tab opens a file **from bytes**, and has find with highlights, next and previous, zoom, selection with the selected text shown, and "Extract all text". A headless test makes a 300-page Vietnamese PDF (Be Vietnam Pro) and reads it back.
- **Measured so far:**
  - **Vietnamese text comes back right and in NFC** ("chú" is `c h ú`, U+00FA), so it fits the search as is (LF-INV-SEARCH-001). 300 pages (533 KB): opened in 0.17 s, all text in 0.6 s (428 592 characters).
  - **Builds:** Windows release built: `pdfium.dll` 7.2 MB. The Android APK built: `libpdfium.so` 6.3 MB (arm64), 4.1 MB (armv7), 6.6 MB (x86_64); about 17 MB for a fat APK, about 6 MB per device with split APKs or an app bundle.
  - **The PDFium binary is downloaded at build time** by `pdfium_dart`'s build hook, from `github.com/bblanchon/pdfium-binaries`, release `chromium/8125`, **checked against pinned SHA-256 hashes**. A CI or offline build needs that download (or a cache).
  - **pdfrx brings `image` 4.11.0**, which needs `archive` newer than LifeFlow's pin (4.0.9 fails to compile: `ZLibDecoder.decodeLazy`). LifeFlow moves to archive 4.7.1 (MIT, same package).
- **Licenses in the PDFium binary** (its `licenses/` folder, read 2026-11-04). PDFium itself is BSD-3-Clause. Bundled, all permissive, none copyleft:
  - Apache-2.0: abseil, highway;
  - Apache-2.0 WITH LLVM-exception: llvm-libc;
  - dragonbox: Apache-2.0 WITH LLVM-exception or BSL-1.0, the choice is ours;
  - MIT: fast_float, simdutf, Little CMS;
  - "Old MIT": HarfBuzz;
  - BSD-2-Clause: OpenJPEG;
  - **outside ADR-0018's list**:
    - FreeType Project License (FTL; FreeType is FTL or GPL-2.0, the choice is ours);
    - IJG and BSD-3-Clause for libjpeg-turbo;
    - libpng License v2;
    - zlib License;
    - Unicode License v3 (ICU);
    - Anti-Grain Geometry 2.3 (a short permissive notice).

  FTL and IJG ask for a credit line in the documentation. **D10 asks the owner** to accept these permissive licenses, shown on the licenses page with their texts, as P02's L-1 did.

## S-09 — DOCX (P05b)
**FAIL for approach (b) (the owner, 2026-11-04): only the text came through; formatting, tables and alignment were all lost.**
- **Question:** Can a DOCX be turned into LifeFlow's block format well enough to read it in LifeFlow's view (D1)?
- **What was done:** the probe's DOCX tab and `readDocx` (archive and `xml`, MIT). It reads headings by style id ("Heading1") or by outline level (localized names, such as the Vietnamese "Tiêu đề 2"), list items with their level, tables as rows, pictures as placeholders, and the accepted text of tracked changes (deleted text is not read). It counts what is not kept: comments, tracked changes, text colour. A headless test builds a file shaped as Word writes it.
- **The owner's sample** (a Vietnamese tax form, 29 KB): 152 paragraphs; **6 tables** (19 rows, 103 cells; 13 cells spanning columns, 2 merged down), including the two-column national heading and an 11-column table of amounts; 106 alignments (90 centered, 13 justified, 3 right); 261 font sizes (9–14 pt); 111 bold runs; tab stops for dotted fill lines; a drawn line; one section with its margins.
- **Why (b) cannot work for such files:** LifeFlow's block format has no tables, no alignment, no font sizes and no page layout, by design (ADR-0066). A form like this *is* its layout, so turning it into blocks loses what matters, however good the reader. (b) suits text-like DOCX files, not forms.
- **Faithful candidates found (2026-11-04), for an S-09b:**
  - `docx-preview` 0.4.1 (Apache-2.0; with `jszip`, MIT or GPL-3.0, so MIT is our choice) renders a DOCX into HTML in the page layout (tables, merged cells, alignment, fonts, sizes, margins). It would run in a WebView: `flutter_inappwebview` 6.1.5 (Apache-2.0; Android, and Windows through WebView2, which Windows 10 and 11 ship). The scripts would be bundled; the file passed in memory; no network.
  - `mammoth` (BSD-2) gives plain semantic HTML, so it loses the layout too (not a fit).
  - LibreOffice (MPL-2.0) converts faithfully, but it is far too large and not on Android.

## S-12 — Reading aloud (P05b)
**English voices PASS on the owner's Windows and Android (2026-11-04).** Vietnamese not tried yet: this Windows PC has no Vietnamese voice installed.
- **Question:** Can flutter_tts read Vietnamese and English with the device's voices on both platforms, with speed, stop and the sentence followed?
- **What was done:** the probe's Voices tab. It lists the voices (Vietnamese picked first), sets the speed, and has read, pause and stop. It reads **one sentence at a time** and starts the next when one ends, so the sentence read is highlighted on both platforms. A log shows every event.
- **Found in the plugin's source (4.2.5):**
  - **The Windows build needs `nuget.exe`**, and downloads Microsoft.Windows.CppWinRT 2.0.210503.1 (MIT) from NuGet at build time. The first build failed without it; the agent fetched nuget.exe from dist.nuget.org into a temporary folder. CI will need it too.
  - **Windows sends no word progress events** (start, end, pause, continue and cancel only), so the highlight follows sentence by sentence, as built. Android has word progress.
  - Windows uses WinRT (OneCore voices).
- **This Windows PC has no Vietnamese voice:** only David, Zira and Mark (English). To install one: Settings → Time & language → Speech → Add voices → Vietnamese ("Microsoft An").
## S-17 — A local model inside the app (P06)
**Result (2026-11-04): PASS on Windows; works on Android but too slow to recommend.** The agent measured on its Windows PC; the owner then ran the probe on his Windows PC (all 4 models) and on his Android phone (Qwen 3.5 0.8 B).
- **Question:** Can a small model run inside LifeFlow on Windows and Android, offline, well enough in Vietnamese, with output the app can check?
- **What was done:** a throwaway probe app (`spikes/p06_probe`, branch `spike/s17-local-model`) with `llamadart` 0.20.6 (MIT; llama.cpp for Dart and Flutter, Flutter ≥ 3.38.6, works on our 3.47.2). Fixed prompts: a question and a summary on a Vietnamese meeting note, an English summary, and a day plan as strict JSON (5 tasks, 2 fixed events, 08:00–18:00), checked by code (it parses, uses only given ids, no overlap, within hours). The app has a headless mode (`p06_probe.exe smoke <model> <file>`) that the agent ran on this PC.
- **Models** (GGUF, Q4_K_M, from Hugging Face `unsloth/…`, tagged Apache-2.0 there; to verify in the model files before any is offered): Qwen 3.5 0.8 B (508 MB), 2 B (1.2 GB), 4 B (2.6 GB); Gemma 4 E2B (3.0 GB).
- **Results on this Windows PC** (llama.cpp runtime with Vulkan; load times after the first download and first run):

| Model | Load | App memory | Speed | Vietnamese question and summary | Day plan (JSON) |
|---|---|---|---|---|---|
| Qwen 3.5 0.8 B | 0.8–2 s | ~0.7 GB | ~250 tok/s | right (date, person, amount); summary right, a little wordy | valid JSON; 7 time overlaps |
| Qwen 3.5 2 B | 4 s | ~1.4 GB | 80–170 tok/s | right, concise | valid; 1 overlap, 1 task left out |
| Qwen 3.5 4 B | 9 s | ~2.8 GB | ~90 tok/s | right, the most precise summary | valid; 1 overlap |
| Gemma 4 E2B | slow first load | ~1.7 GB | ~120 tok/s | right, natural | valid; 1 overlap, 1 task after hours |

- **Found:**
  - **Vietnamese reading and writing is good** even at 0.8 B: answers about a Vietnamese text were all correct.
  - **Small models cannot be trusted with times**: every model overlapped at least one task with a fixed event. So the design's determinism boundary is needed, not optional. The model proposes an order and what goes where; LifeFlow's own code checks the times and moves or flags what does not fit before the person sees the proposal.
  - **Structured JSON needs thinking off** (`enableThinking: false`): with thinking on, every model spent its budget thinking and the JSON was cut off.
  - The first ever run waits about 20 s before the first word (the GPU backend prepares itself); later runs answer in under a second.
  - **App size:** the runtime adds a lot. The Windows release folder is 170 MB (Vulkan backend 32 MB, LiteRT-LM 26 MB, WebGPU about 24 MB, …); the Android arm64 APK is 116 MB. LiteRT-LM and WebGPU may not be needed for GGUF: to trim in T4 (llamadart's native runtime configuration).
  - The native libraries are downloaded by llamadart's build hook (`leehack/llamadart-native` v1.0.0-4), as PDFium is: their licenses (llama.cpp and ggml MIT; LiteRT-LM, Dawn and others) must be read and their notices shipped (T4, like ADR-0075).
  - Models are cached in `%LOCALAPPDATA%\llamadart\models` by default; LifeFlow would keep them in its own folder.
- **The owner's runs** (the logs sent are of Qwen 3.5 0.8 B):

| | Load | App memory | Free answer | Vietnamese summary / question, English summary | Day plan (JSON) |
|---|---|---|---|---|---|
| Android phone | 121 s | ~1.5 GB | 34 s, 7.9 tok/s, first word 0.7 s | 40–80 s each, 1.1–2.8 tok/s, first word 3.4–10.9 s | 291 s; 6 overlaps |
| Windows PC | 2.2 s | 0.73–0.87 GB | 1.5–2 s, 186–222 tok/s | 0.2–0.9 s each, 146–243 tok/s, first word 20–140 ms | 25.6–27.8 s in 4 runs, 7 overlaps each; 1 run in 5 failed: malformed JSON (unterminated string) |

  The owner's judgement: Vietnamese quality is not the problem. Speed and the quality of the answers are. On Windows, small local models are acceptable for the app's scope, although the day plan is slow with all 4 models. On Android, everything is slow: if local AI is offered there, the app must say clearly that it is slow and not recommended.
- **Found in the owner's runs:**
  - The day plan is the slow task everywhere: about 26 s on Windows against under 1 s for a summary. Its JSON output is long and the structured (grammar-checked) output costs time. The plan the model writes should be small: the order and the slot of each task by id, with LifeFlow's code computing and checking the times (T6).
  - Structured output can still fail (1 run in 5). The orchestrator must check it, retry once, and otherwise tell the person, never apply a broken plan (T6).
  - On the phone, loading takes 2 minutes and a reply takes tens of seconds to minutes, with 1.5 GB of memory for the smallest model.
- **Recommendation (for T4):**
  - **Runtime (D3): `llamadart` (llama.cpp) embedded, on Windows and Android.** No need for Ollama: the embedded runtime is fast enough on Windows.
  - **Windows model list (D4):** Qwen 3.5 2 B as the default (the best balance in the agent's runs: concise answers, 1 overlap and 1 task left out against 7 overlaps for 0.8 B), Qwen 3.5 4 B as the larger one, Qwen 3.5 0.8 B as the light one for weak PCs. Gemma 4 E2B is left out: its license is the Gemma terms, not Apache, and it brought nothing the Qwen models did not.
  - **Android:** Qwen 3.5 0.8 B only, behind a clear warning before the download ("slow on phones; not recommended; a cloud model with your own key works better here"). Cloud (D2 (b), S-18) is the real option on phones.
  - **In every case:** a stop button, the answer streamed as it comes, the deterministic time check of every plan (already required by the first run), and one retry of a broken JSON plan.
  - Before T4 offers a model: verify its license in the model files, pin its SHA-256, trim the native libraries LifeFlow does not need (LiteRT-LM, WebGPU), and ship the runtime's notices.

## S-18 — Cloud models with the person's own key (P06)
**Result (2026-11-04): PASS for Groq and Gemini; OpenAI and Anthropic not run (no key yet).**
- **Question:** Does the cloud engine of T5 (ADR-0085) work against the real services, and how do the providers compare on the S-17 prompts (a Vietnamese question and summary, an English summary, a day plan as strict JSON)?
- **What was done:** `packages/infrastructure/tool/s18_probe.dart` ran the S-17 prompts through the real `CloudAiEngine` with the owner's keys. The keys came from the environment and were never written or printed. Each key first listed its models (Gemini 49, Groq 11), then two models per provider ran.
- **Results** (times from this PC, the day of the run; the tokens are what the provider counted):

| Model | Vietnamese question | Vietnamese summary | English summary | Day plan (JSON, checked) |
|---|---|---|---|---|
| Groq `openai/gpt-oss-20b` | 0.8 s, right, but **words run together** ("ngày30tháng11, nộp chochịLan") | 1.2 s, right; invents a year ("2/11/2023") | 0.9 s, right | 2.0 s, 1 838 tokens, valid, **no overlap** |
| Groq `qwen/qwen3.8-27b` | 0.4 s, right, clean | 1.1 s, right, clean | 0.5 s, right | 1.3 s, 766 tokens, valid, **no overlap** |
| Gemini `gemini-flash-lite-latest` | 0.9 s, right | 1.0 s, right, concise | 1.0 s, right | 1.9 s, 664 tokens, valid, 1 overlap |
| Gemini `gemini-3.8-flash` | HTTP 503 "high demand" on every request, twice a minute apart | | | |

- **Found:**
  - **The wire works.** On Groq (OpenAI's format), answers stream, the tokens are counted and JSON comes back strict. On Gemini (generateContent), answers stream with the key in a header and `responseJsonSchema` is accepted. Model lists come from the keys.
  - **The cloud is 10–20 times faster** for a day plan than the local model on the owner's PC (1–2 s against about 26 s; minutes on the phone), and better: two of three plans had no overlap. The code's time check (`fitDayPlan`) is still needed: Gemini Flash-Lite overlapped one task.
  - **Vietnamese:** Qwen 3.8 27B on Groq and Gemini Flash-Lite write clean Vietnamese. GPT-OSS 20B runs words together and invents details, so it is not recommended for Vietnamese.
  - **A busy model returns HTTP 503** (Gemini "high demand"; Anthropic uses 529 "overloaded"). The engine showed it as a general failure. **Fixed:** 503 and 529 now count as "the provider asks to wait", like 429, with a test (mutation killed).
  - Reasoning models count their thinking in the tokens (GPT-OSS: 513 tokens for a one-line answer). The monthly cap counts what the provider bills.
- **Recommendation:**
  - The settings list the provider's own models, so no default is pinned.
  - The help text suggests **Groq `qwen/qwen3.8-27b`** or **Gemini Flash-Lite** for Vietnamese and fast plans.
  - OpenAI and Anthropic are wired the same way and tested against their formats. They run when the owner adds keys (`LIFEFLOW_S18_OPENAI_KEY`, `LIFEFLOW_S18_ANTHROPIC_KEY`).
  - **The provider terms** (training on API data, retention) remain the owner's reading before publishing. The settings screen should link each provider's terms (T8/T9 follow-up).
