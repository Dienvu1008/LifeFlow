# Spike Results

- Status: MVP-blocking spikes complete (S-03a PASS, S-01 PASS, S-02 plain PASS; encryption-at-rest resolved in P01 task T5 via ADR-0021 — Android encrypted, Windows MVP plain + tracked exception). This is the canonical results record on `main`; the throwaway POC code lives on the `spike/*` and `scaffold/p01-skeleton` branches (not merged to `main`).
- Related: [spike-plan.md](spike-plan.md), [../FINAL-REPORT.md](../FINAL-REPORT.md) §19

Fixed entry format: **Question / Hypothesis / What was done / Measured result / Success or Failure / Decision / ADR update or Open+escalation / Human gate date.**

---

## S-03a — Auth
**PASS on Windows (2026-11-04):** GitHub sign-in via SDK-managed PKCE (S256) + fixed loopback; session in secure storage survives offline restart; no token in logs. Decision: Supabase Auth is the MVP auth provider (ADR-0003 auth half Accepted). Follow-up: Android + email baseline.

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
