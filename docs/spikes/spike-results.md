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
  - The same reservations cover **127.0.0.1:53682, the fixed loopback port of Windows sign-in (S-03a)**: binding it fails on the development PC now. Escalated to the owner (a fix: let the system pick a free loopback port, RFC 8252 §7.3, with a matching redirect pattern in Supabase).
- **Human gate:** owner review with the other P04 spikes.
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
