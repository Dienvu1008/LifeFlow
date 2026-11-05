# LifeFlow

Local-first, modular-monolith Personal & Collaborative Life OS (Flutter, Windows + Android first).

- **Design corpus:** [docs/](docs/) — start at [docs/FINAL-REPORT.md](docs/FINAL-REPORT.md) and [docs/README.md](docs/README.md). The design phase (Batches 1–5) is complete.
- **Status:** pre-P01. MVP-blocking spikes done: S-03a (auth) PASS, S-01 (Drift) PASS; S-02 (migrations + FTS5 + encryption) in progress on this scaffold.

## Repository layout (scaffold skeleton, P01)
Per [docs/architecture/repository-structure.md](docs/architecture/repository-structure.md):
```
packages/
  foundation/      pure-Dart primitives (ids, time, result)
  time_kernel/     stateless schedule/recurrence/DST rules (ADR-0013)
  domain/          bounded-context models/commands/ports
  infrastructure/  Drift database, adapters (hosts the S-02 spike)
  ui/              Riverpod + go_router shells (ADR-0019)
  testing/         shared test utilities
tools/fitness/     architecture fitness functions (FF-ARCH-01..09)
.github/workflows/ CI stage order
docs/              the full design corpus
spikes/            throwaway spike POCs (not app code)
```
The packages are **skeletons** (empty-but-compiling) that P01 fills in. Dependency direction and the fitness functions (FF-ARCH-01..09) enforce the boundaries in the design.

## Branches
- `main` — design docs.
- `spike/s-03a`, `spike/s-01` — throwaway spike POCs (do not merge as features).
- `scaffold/p01-skeleton` — this skeleton + the S-02 spike. Not merged to `main` until reviewed.
