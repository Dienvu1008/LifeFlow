# S-01 Runbook (Flutter + Drift NativeDatabase on Windows and Android)

- Status: Spike POC (throwaway). Branch `spike/s-01`. Do not merge to `main` as a feature.
- Time-box: 1–2 person-days.

## 0. What this proves (success criteria)
1. The app builds and runs on **Windows** and **Android** with Drift's `NativeDatabase` and **bundled sqlite3 3.x** — no `sqlite3_flutter_libs`, no manual native setup.
2. CRUD works; a multi-table **transaction** commits atomically.
3. A failing transaction **rolls back** entirely (no partial state) — the governance-kernel atomicity foundation (ADR-0014) rests on this.

If a platform build/runtime blocker appears → record Open + escalate (reconsider the local store).

## 1. Already verified by the agent (headless, in this environment)
- `flutter analyze` = No issues found.
- `flutter test` (in-memory `NativeDatabase.memory()`): **2/2 passed** — CRUD+transaction, and rollback. See `test/db_test.dart`.
- Drift codegen (`dart run build_runner build`) succeeds; `database.g.dart` is generated.
These prove the Drift logic. The **platform build/run** below is what you verify.

## 2. Prerequisites
- Flutter stable (3.47.x present). Windows desktop enabled; an Android device/emulator for the Android run.

## 3. Run
From `spikes/s-01-drift`:

Windows:
```
flutter run -d windows
```
Android (device/emulator attached):
```
flutter devices
flutter run -d <android-device-id>
```

In the app:
- Tap **Create (tx)** a few times → each adds 1 deck + 2 cards in one transaction; the log shows the running counts.
- Tap **Read** → shows deck/card counts (persisted; reopen the app to confirm persistence).
- Tap **Rollback test** → attempts a duplicate-key insert inside a transaction; the log must say `rollback OK: tx-fail not persisted` (never `ROLLBACK FAILED`).

## 4. Report
- Windows: builds? runs? Create/Read/Rollback behave as above?
- Android: same?
- Any native build error (e.g. sqlite not found, NDK, CMake) — paste it.
- If both platforms pass the three success criteria → S-01 PASS. Fill the S-01 entry in `../spike-results.md`.

## 5. Note on sqlite3 bundling
With drift 2.28 + sqlite3 3.x (via `drift_flutter`), sqlite3 is bundled through build hooks; `sqlite3_flutter_libs`/`sqlcipher_flutter_libs` are not needed (confirms the stack decision and ADR-0002/VS-03). S-02 later swaps the plain sqlite3 for SQLite3MultipleCiphers (encryption) on the scaffold branch.
