# Architecture Fitness Functions (scaffold stubs)

Canonical definitions: [../../docs/testing/architecture-fitness-functions.md](../../docs/testing/architecture-fitness-functions.md) (FF-ARCH-01..09).

Status in the scaffold:
- **FF-ARCH-01** (pure domain: no Flutter/Drift/platform imports in foundation/time_kernel/domain) — a runnable minimal import scan: `dart run tools/fitness/ff_arch_01_pure_domain.dart`.
- FF-ARCH-02..09 — **stubs**, implemented in P01 as the packages gain content:
  - 02 no cross-context internal imports (published API allowlist)
  - 03 no repository write outside a command handler
  - 04 ui does not import infrastructure/Drift
  - 05 no cyclic package dependency
  - 06 atomic command side-effects (test-based; LF-INV-GOV-003)
  - 07 no AGPL/unknown-license dependency (license scan; ADR-0018)
  - 08 no Restricted item toward cloud AI (test-based; LF-INV-PRIV-002)
  - 09 authorize-before-domain (test-based; LF-INV-GOV-002)

These are the pacing checks for P01's Definition of Done (static FFs green).
