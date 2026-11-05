# Phase Breakdown

- Status: Draft (Batch 5)
- Date: 2026-11-04
- Related: [master-roadmap.md](master-roadmap.md), [dependency-map.md](dependency-map.md), [../testing/definition-of-done.md](../testing/definition-of-done.md), [../invariants/invariant-test-matrix.md](../invariants/invariant-test-matrix.md), [effort-estimation.md](effort-estimation.md), [risk-register.md](risk-register.md)

Per-phase detail. Exit gates and invariant/golden-scenario coverage are **referenced** from the Definition of Done and the test matrix, not restated. Estimates (person-day ranges, dev + agent) are in [effort-estimation.md](effort-estimation.md).

## P00 — Product & Architecture Foundation
- Objective: a complete, consistent design corpus an agent can implement from.
- Scope: Batches 1–5 (this documentation set). Out: any application code.
- Prerequisites: none.
- Deliverables: product/vision/scope/use-cases/requirements, assessment, bounded contexts/context map, domain model + per-context docs, governance, data/sync/security, specialized domains, AI/UI/repo/stack, invariant catalog + matrix + golden scenarios + fitness functions + DoD, roadmap/spikes/estimation/risks, FINAL-REPORT.
- Exit gate: DoD §P00 — corpus internally consistent, owner has confirmed the MVP boundary and key ADRs. **Done when Batch 5 completes.**

## P01 — Core Foundation & Personal Workspace
- Objective: a usable offline personal task app with the governance spine.
- In scope: guest-first LocalProfile + Personal Workspace (ADR-0008); Task + Subtask hierarchy + lists + measurable target capability; local encrypted Drift store (ADR-0009/0014, SQLite3MultipleCiphers); command gateway with the atomic set (outbox/event-log/audit/dedupe); basic adaptive UI (Riverpod + go_router); optional sign-in (provider from S-03a); local export/restore.
- Out of scope: recurrence/calendar (P02), execution/focus (P03), sync draining (P04).
- Prerequisites: spikes S-01, S-02 (FTS caveat), S-03a (before sign-in); S-05 if reminders start here.
- Deliverables: the packages in [repository-structure.md](../architecture/repository-structure.md) for workspace/task + foundation + infrastructure + minimal ui; migrations; the gateway; export.
- Milestones (ordinal): M1 foundation+DB; M2 task CRUD+hierarchy via gateway; M3 atomic set + crash/concurrency tests; M4 encryption + export; M5 sign-in + binding; M6 adaptive shell.
- Exit gate: DoD §P01. Invariant coverage: the P01 set in DoD (matrix rows for ID/WA/TASK/GOV/OUTBOX/AUDIT/VER/SEC/SYNC-tombstone). Golden scenarios: GS-06, GS-07, GS-11, GS-12, GS-18, GS-19, GS-20, GS-22. Fitness: all static + FF-ARCH-06, 09.
- Risks: R-OFFLINE-SYNC-SEED, R-SCOPE, R-FLUTTER-PLUGIN (see register).

## P02 — Planning & Calendar
- Objective: scheduling, recurrence and calendar on the P01 core.
- In scope: ScheduleSpec, RecurrenceRule, OccurrenceException, Time Kernel queries, Event/Calendar, deterministic conflict detection, reminders, DST.
- Out: AI scheduling, external calendar sync.
- Prerequisites: P01 exit; S-05 (reminders) if not done.
- Milestones: M1 Time Kernel + schedule; M2 recurrence + exceptions (windowed); M3 calendar/event + conflict; M4 reminders + DST tests.
- Exit gate: DoD §P02. Invariants: PLAN-004/010/011/012/013, CAL-001/002. Golden: GS-03, GS-04.
- Risks: R-DST, R-RECURRENCE-DUP (mitigated by design; verify via GS).

## P03 — Execution, Goals & Focus (MVP boundary end)
- Objective: record actuals, habits, goals; complete the MVP.
- In scope: FocusSession state machine + recovery, ExecutionRecord, Measurement + aggregation (manual), habit evaluation, Goals/Projects/Milestones (derived progress).
- Out: health-sourced measurement (P08), AI analytics.
- Prerequisites: P01, P02 exits.
- Milestones: M1 focus machine + recovery; M2 execution records + measurements; M3 habit evaluation; M4 goals/projects + derived progress.
- Exit gate: DoD §P03 = **MVP exit**. Invariants: EXEC-001..004, HEALTH-002/004 (manual), TASK-010, GOAL-001/002/003. Golden: GS-01, GS-02, GS-05 (manual), GS-13, GS-21.
- Risks: R-DATA-LOSS (focus recovery), R-SCOPE.

## P04 — Collaboration & Sync
- Objective: multi-device sync and shared workspaces.
- In scope: backend decision (ADR-0003 via S-03/S-03a), auth-backed sync, outbox draining, per-type conflict (ADR-0015), membership/roles/sharing, RLS, audit, notifications.
- Prerequisites: P03 exit; spikes S-03, S-04.
- Exit gate: DoD template + P04 anchors. Invariants: SYNC-001/002/003, PRIV for sharing. Golden: GS-08, GS-14, GS-17.
- Risks: R-OFFLINE-SYNC, R-PERMISSION, R-CLOUD-COST, R-DATA-LOSS.

## P05 — Document & Knowledge
- Scope: block editor (S-07), documents, revisions, links, search (FTS), viewers (S-08/09), reading/TTS (S-12), revision-based collaboration (ADR-0017).
- Prerequisites: P04; S-07; S-08/09/12 for the viewer/reading features.
- Exit gate: DoD template. Invariants: DOC-001..005. Golden: GS-08.
- Risks: R-DOC-COLLAB, R-EDITOR-LICENSE (mitigated by ADR-0018/0020), R-VIEWER-FEASIBILITY.

## P06 — AI Platform
- Scope: orchestrator, provider router, context builder (egress-scoped), tool gateway, proposal/approval (ADR-0012), local providers; cloud as a port.
- Prerequisites: P04 (command/sync maturity); data-classification (3a) + AI governance (Batch 2) already designed.
- Exit gate: DoD template; FF-ARCH-08 green. Invariants: AI-001/002, PRIV-001/002/003. Golden: GS-15, GS-16.
- Risks: R-AI-HALLUCINATION, R-AI-LEAK, R-CLOUD-COST.

## P07 — Dictionary, Translation & Vocabulary
- Scope: Dictionary + Translation (provider ports/ACL), offline packages, Vocabulary (spaced repetition), selection adapter integration.
- Prerequisites: P06 (for AI-assisted explanation, optional); S-10 (sources/licenses).
- Exit gate: DoD template. Invariants: DICT-*, VOCAB-*. Golden: GS-09.
- Risks: R-DICT-LICENSE, R-EXTERNAL-API.

## P08 — Health & Activity Integration
- Scope: Android Health Connect (steps), evidence via RecordMeasurement, dedup, revocation.
- Prerequisites: P06/P03; S-13.
- Exit gate: DoD template. Invariants: HEALTH-001/003/005/006. Golden: GS-05, GS-10.
- Risks: R-HEALTH-PRIVACY, R-HEALTH-DUP, R-WINDOWS-NOHEALTH.

## P09 — Learning Studio & Automation
- Scope: courses/modules/lessons/progress; learning task generation via Task contract; automation rules.
- Prerequisites: P07 (vocabulary), P03 (tasks).
- Exit gate: DoD template. Risks: R-SCOPE.

## P10 — Advanced Ecosystem
- Scope: iOS/HealthKit (S-14), advanced collaboration, CRDT if justified (ADR-0017 trigger), calendar integrations, advanced analytics.
- Prerequisites: validated need per item (AP-13).
- Exit gate: per-item DoD. Risks: R-SCOPE, R-DOC-COLLAB (CRDT).

## Self-check
- [x] Each phase lists objective, scope, prerequisites (incl. spikes), milestones, exit gate (via DoD), invariant + golden coverage, risks.
- [x] DoD and matrix are referenced, not restated.
- [x] MVP boundary = end of P03.
