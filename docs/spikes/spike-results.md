# Spike Results

- Status: In progress (spike phase). One entry per spike, fixed format.
- Note: this file lives on each spike branch; S-03a's full entry is on `spike/s-03a`. This copy (branch `spike/s-01`) carries the S-03a outcome summary for context and the S-01 detail.
- Related: [spike-plan.md](spike-plan.md), [../FINAL-REPORT.md](../FINAL-REPORT.md) §19

Fixed entry format: **Question / Hypothesis / What was done / Measured result / Success or Failure / Decision / ADR update or Open+escalation / Human gate date.**

---

## S-03a — Auth + Windows flow + offline session (summary; full entry on `spike/s-03a`)
- **PASS on Windows (2026-11-04):** GitHub sign-in via SDK-managed PKCE (S256) + fixed loopback; session cached in secure storage survives an offline restart; no token in logs. Finding: Supabase owns PKCE/state, so use `getOAuthSignInUrl` + `exchangeCodeForSession` (not a self-made PKCE/state). Decision: Supabase Auth is the MVP auth provider (ADR-0003 auth half Accepted). Follow-up: Android + email baseline before P01 sign-in UI.

---

## S-01 — Flutter + Drift on Windows/Android
- Branch: `spike/s-01`. POC at `spikes/s-01-drift/` (throwaway). Time-box 1–2 pd.
- **Question:** Does Flutter + Drift `NativeDatabase` run cleanly on Windows and Android with bundled sqlite3 3.x (no manual native setup), supporting CRUD + an atomic transaction (+ rollback)?
- **Hypothesis:** drift 2.28 + sqlite3 3.x via `drift_flutter` bundles sqlite3 through build hooks on both platforms; a transaction commits atomically and rolls back fully on error (the ADR-0014 foundation).
- **What was done (agent, in this environment):** Wrote a disposable Flutter+Drift POC (two tables with a FK; `createDeckWithCards` in one transaction; a rollback test). Generated Windows + Android platforms. Drift codegen succeeds; `flutter analyze` = **No issues found**; `flutter test` on `NativeDatabase.memory()` = **2/2 passed** (CRUD+transaction, and full rollback). Wrote `RUNBOOK.md`. **Platform build/run not executed here** — owner verifies Windows + Android.
- **Measured result (owner run on Windows, 2026-11-04):**
  - Windows builds + runs: **PASS**.
  - CRUD + transaction: **PASS** — first session created decks/cards; a later session read `5 decks, 10 cards` (exact 1:2 ratio), proving the transaction wrote all rows and **data persisted to the on-disk SQLite file across restarts**.
  - Rollback: **PASS** — `rollback OK: tx-fail not persisted`.
  - No manual native sqlite setup: **PASS** — ran without adding any native config.
  - Android: **not run** (follow-up).
  - Note: the owner initially saw `UNIQUE constraint failed: decks.id` on Create — this was a POC bug (the id counter reset to 0 each launch and clashed with persisted data), which actually *confirmed* persistence. Fixed: ids now use a timestamp; added a "Reset DB" button. Headless tests remain 2/2.
- **Success or Failure:** **SUCCESS on Windows** (persistence + transaction + rollback proven on-device; headless 2/2). Android is a follow-up.
- **Finding (important):** the resolved stack is **sqlite3 2.9.4 + sqlite3_flutter_libs 0.5.42** (the older CMake-bundling mechanism), NOT sqlite3 3.x build hooks. Per the official sqlite3.dart issue #336 (2026-11), the 3.x build-hooks path "is not a smooth experience" on Flutter yet, so `drift_flutter` still resolves to 2.x. **Consequence for S-02/encryption:** the ADR-0016/VS-21 assumption (SQLite3MultipleCiphers via `sqlite3` 3.x build hooks) may not apply as-is on current Flutter; S-02 must verify the actual encryption path (likely the older `sqlcipher_flutter_libs` CMake mechanism, or a 3.x opt-in) and record which works. Raised as OQ-STACK-2.
- **Decision:** proceed. Confirms Drift/NativeDatabase on Windows; create `scaffold/p01-skeleton` (Task C); S-02 runs there and must resolve the encryption-mechanism question above.
- **ADR update or Open+escalation:** confirms Drift stack rows + ADR-0013. New open question **OQ-STACK-2** (encryption mechanism under current Flutter sqlite3 bundling) for S-02. Android run is a follow-up before P01.
- **Human gate date:** 2026-11-04 — passed for Windows; Android a follow-up.

---

## S-02 — Migrations + FTS5-under-encryption
- Branch: runs on `scaffold/p01-skeleton` after S-01 passes. Not started.
