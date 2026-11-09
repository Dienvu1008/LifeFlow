# Definition of Done (per phase)

- Status: Draft (Batch 4)
- Date: 2026-11-04
- Related: [test-strategy.md](test-strategy.md), [../invariants/invariant-test-matrix.md](../invariants/invariant-test-matrix.md), [architecture-fitness-functions.md](architecture-fitness-functions.md)

A phase is done only when all its DoD items hold. Phases beyond P03 use the template at the end.

## Universal DoD (every phase)
- Build passes on Windows and Android; `dart analyze`/`flutter analyze` clean (no new errors).
- Static fitness functions green: FF-ARCH-01, 02, 03, 04, 05, 07.
- All tests for the phase pass (unit, property, state-machine, integration, plus crash/sync where relevant).
- Every invariant the phase introduces or enforces has a passing verification row in the matrix.
- New dependencies have a verified license (ADR-0018) recorded in verified-sources; no AGPL/unknown.
- ADRs updated for any decision with trade-offs; docs/labels consistent.

## P00 — Product & Architecture Foundation
- Status: this is the current design work (Batches 1–5). Exit gate: product scope, domain model, governance, invariants catalog, test strategy, fitness-function IDs, roadmap and spikes exist and are internally consistent; the owner has confirmed the MVP boundary and the key ADRs. (Done when Batch 5 completes.)

## P01 — Core Foundation & Personal Workspace
- Evidence: see [p01-exit-gate.md](p01-exit-gate.md) (per-line proof; sign-off pending).
- Scope: guest-first LocalProfile + Workspace, Task + hierarchy + lists, measurable target capability, local Drift store, outbox/event-log/audit/dedupe atomic set, command gateway, basic adaptive UI, optional sign-in (auth provider from spike S-03a).
- **Encryption-at-rest (LF-INV-SEC-011) is an explicit P01 task, not assumed done** (spike S-02 found it does not build cleanly on Flutter Windows; risk R-ENCRYPTION-WINDOWS). P01 must either confirm a Windows-clean encryption path or ship Windows on a plain DB as a tracked exception with encryption on Android; the choice is a P01 exit-gate decision.
- Invariants enforced-and-tested by exit: LF-INV-ID-001/002, WA-001, TASK-001/002/003/004/010/011, GOV-001/002/003, OUTBOX-001/002, AUDIT-001, VER-001, SEC-001/002/010/011, SYNC-004 (tombstone write).
- Golden scenarios passing: GS-06, GS-07, GS-11, GS-12, GS-18, GS-19, GS-20, GS-22.
- Fitness functions: all static + FF-ARCH-06 (atomic set) + FF-ARCH-09 (authorize-before-domain).
- Exit gate: the atomic-set crash/concurrency scenarios (GS-06/07/12) pass; encryption at rest verified (GS-19); export/restore round-trips (GS-20); guest→account binding keeps IDs and works offline (GS-22).

## P02 — Planning & Calendar
- Scope: ScheduleSpec, RecurrenceRule, OccurrenceException, Time Kernel queries, Event/Calendar, conflict detection, reminders, DST.
- Invariants: PLAN-004/010/011/012/013, CAL-001/002.
- Golden scenarios: GS-03, GS-04.
- Exit gate: recurrence is bounded/deterministic with no duplicates (GS-03); DST correctness across at least two zones (GS-04); conflict detection deterministic.

## P03 — Execution, Goals & Focus
- Scope: FocusSession state machine + recovery, ExecutionRecord, Measurement + aggregation, Goals/Projects/Milestones, habit evaluation.
- Invariants: EXEC-001/002/003/004, HEALTH-002/004 (manual path), TASK-010 (measurable), GOAL-001/002/003.
- Golden scenarios: GS-01, GS-02, GS-05 (manual path), GS-13, GS-21.
- Exit gate: focus recovery within 1s and one record per session (GS-13); goal progress derived with no write-back (GS-21); measurable habit completes correctly (GS-01).

## Template (P04–P10)
For each later phase record:
- Scope (capabilities delivered).
- Invariants enforced-and-tested by exit (from the catalog).
- Golden scenarios that must pass.
- Fitness functions that must be green (add FF-ARCH-08 at P06 for AI egress).
- Spikes that must have succeeded first (from the spike plan, Batch 5).
- Exit gate (the specific behavioral proofs).

Known later anchors (filled in the roadmap batch):
- P04 (Collaboration & Sync): SYNC-001/002/003, per-type conflict; GS-08, GS-14, GS-17; FF-ARCH-08 preparation; auth/data backend decided (ADR-0003).
- P05 (Documents): DOC-001..005; GS-08; editor spike S-07 done.
- P06 (AI): AI-001/002, PRIV-001/002/003; GS-15, GS-16; FF-ARCH-08 green.
- P07 (Dictionary/Vocabulary): DICT-*, VOCAB-*; GS-09; spike S-10 (sources/licenses) done.
- P08 (Health): HEALTH-001/003/005/006; GS-05, GS-10; spike S-13 done.

## Self-check
- [x] Universal DoD lists build, static FFs, tests, invariant coverage, license, ADRs.
- [x] P01–P03 list concrete invariants, golden scenarios, fitness functions and an exit gate.
- [x] Later phases have a template and anchors tied to the catalog and spikes.
