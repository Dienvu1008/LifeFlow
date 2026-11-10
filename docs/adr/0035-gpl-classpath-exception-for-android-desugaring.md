# ADR-0035: GPL-2.0 with the Classpath Exception for Android desugaring only

- Status: Accepted (owner decision, 2026-11-10; P02 exit-gate item L-1, option (a))
- Date: 2026-11-10
- Deciders: Project owner
- Amends: [ADR-0018](0018-dependency-license-policy.md) (adds rule 7)
- Related: [ADR-0034](0034-reminders.md), [p02-exit-gate.md](../testing/p02-exit-gate.md), verified-sources VS-35, risk R-LICENSE-SCAN

## Context
Reminders (P02 T7) use `flutter_local_notifications`. From version 10, it requires Android core-library desugaring, so the Android build includes `com.android.tools:desugar_jdk_libs`. Its code is compiled into the APK. The library is a subset of OpenJDK, licensed under **GPL-2.0 with the Classpath Exception** (google/desugar_jdk_libs: `LICENSE`, `ASSEMBLY_EXCEPTION`, `ADDITIONAL_LICENSE_INFO`; [OpenJDK GPLv2 + CE](https://openjdk.org/legal/gplv2+ce.html)).

ADR-0018 did not cover this license, and the library was merged in T7 before a decision; that was a process error, caught at the P02 exit gate. The owner asked whether this prevents a commercial, closed-source release in the stores. It does not: the Classpath Exception explicitly lets the library be linked with independent modules and the resulting executable be distributed under terms of the distributor's choice. Our code is an independent module, so it does not become GPL.

## Decision
1. **ADR-0018 rule 7:** GPL-2.0 with the Classpath Exception is accepted **only for `com.android.tools:desugar_jdk_libs`**, the Android toolchain's desugaring library. It is accepted on these conditions:
   - It is used unmodified, only as the Android build pulls it in.
   - None of its code is copied into LifeFlow files.
   - Its notices ship with the app: the `LICENSE`, `ASSEMBLY_EXCEPTION` and `ADDITIONAL_LICENSE_INFO` files, unchanged, with a link to its source at the pinned commit. They are shown under Settings → Open-source licenses.
   - Any other GPL-licensed dependency (with or without an exception) still needs its own owner decision.
2. **Notices:** `tools/licenses/fetch_desugar_notices.ps1` fetches the three files from google/desugar_jdk_libs at a pinned commit (`ec1741f`), checks their SHA-256 and stores them in `apps/lifeflow_app/assets/licenses/desugar_jdk_libs/`. The app adds them to Flutter's license registry at startup (`lib/licenses.dart`). Re-run the script, and review, when the library version changes.
3. **Enforcement (FF-ARCH-07, now in CI):** `tools/fitness/ff_arch_07_licenses.dart` checks every package in the app's `pubspec.lock` (hosted and git) and every Android library in the app's Gradle file against `tools/fitness/license_inventory.txt` (exact version + SPDX id). The scan fails in four cases:
   - a package or library is missing from the inventory;
   - its version changed without review;
   - its license is not in ADR-0018 rule 2 (MIT, Apache-2.0, BSD-2/3-Clause, MPL-2.0);
   - this exception is used by another entry, or its notice files are missing.

   Its rules have a self-test (`ff_arch_07_test.dart`).

## Consequences
- Pro: reminders keep working on Android with the standard toolchain path; a commercial closed-source release stays possible.
- Pro: every future dependency change is now reviewed before merge (closes the gap of R-LICENSE-SCAN).
- Con: a small, known GPL component ships in the Android build, with notice obligations. Modifying it, or copying its code, is not allowed under this decision.
- Con: the inventory must be updated on every package upgrade (by design; `--detect` suggests lines from the pub cache, a human reviews them).
- This is an engineering reading of the license, not legal advice. Before a large commercial release, a review by someone skilled in open-source licensing is advisable.

## Verification
- `dart run tools/fitness/ff_arch_07_licenses.dart`: 125 shipped packages and libraries, all accepted (one under this rule).
- `dart run tools/fitness/ff_arch_07_test.dart` (11 cases):
  - Rejections: AGPL, plain GPL, the exception used by another package, missing notice files, a package missing from the inventory, an upgrade without review.
  - Passes: accepted licenses, and the exception with its notices.
  - Parsing of `pubspec.lock` and Gradle, and the license guesses.
- `apps/lifeflow_app/test/licenses_test.dart`: the full notices are registered. `packages/ui/test/reminder_flow_test.dart`: Settings → Open-source licenses opens the license page.
