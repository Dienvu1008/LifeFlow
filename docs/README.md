# LifeFlow Documentation

- Status: **Design phase complete (Batches 1–5).** See [FINAL-REPORT.md](FINAL-REPORT.md) for the stakeholder summary and the preconditions to start P01 (implementation).
- Date: 2026-11-04

LifeFlow is a Personal and Collaborative Life Operating System (Flutter, local-first, modular monolith). This folder holds design documents only. No application code exists yet.

## Label legend

Every non-trivial statement carries one of these labels.

| Label | Meaning |
|---|---|
| Existing Fact | True of the legacy repo or environment, observed but not independently re-verified by this team |
| Verified Finding (Verified) | Checked directly in source code or an official document during this work, with the evidence cited |
| Assumption | Believed true, not verified; has a risk if wrong |
| Proposal | Recommended design, not yet a decision |
| Open Question | Unresolved; names who/what decides it |
| Decision | Agreed by the owner or recorded in an accepted ADR |

## Reading order

1. [product/product-vision.md](product/product-vision.md)
2. [product/product-scope.md](product/product-scope.md) (MVP boundary)
3. [assessment/legacy-repo-assessment.md](assessment/legacy-repo-assessment.md), then [legacy-component-matrix.md](assessment/legacy-component-matrix.md)
4. [architecture/architecture-principles.md](architecture/architecture-principles.md), [bounded-contexts.md](architecture/bounded-contexts.md), [context-map.md](architecture/context-map.md)
5. [product/requirements.md](product/requirements.md), [product/personas-and-use-cases.md](product/personas-and-use-cases.md)
6. [research/verified-sources.md](research/verified-sources.md)
7. [architecture/domain-model.md](architecture/domain-model.md), then [domains/](domains/) per context
8. [governance/governance-kernel.md](governance/governance-kernel.md), [authorization-model.md](governance/authorization-model.md), [ai-action-governance.md](governance/ai-action-governance.md), [audit-and-provenance.md](governance/audit-and-provenance.md)
9. [data/data-architecture.md](data/data-architecture.md), [local-storage.md](data/local-storage.md), [sync-protocol.md](data/sync-protocol.md), [data-classification.md](data/data-classification.md)
10. [security/threat-model.md](security/threat-model.md), [privacy-model.md](security/privacy-model.md), [security-requirements.md](security/security-requirements.md)
11. [architecture/technical-stack.md](architecture/technical-stack.md), [ai-architecture.md](architecture/ai-architecture.md), [ui-ux-architecture.md](architecture/ui-ux-architecture.md), [repository-structure.md](architecture/repository-structure.md)
12. [invariants/invariant-catalog.md](invariants/invariant-catalog.md), [policy-catalog.md](invariants/policy-catalog.md), [invariant-test-matrix.md](invariants/invariant-test-matrix.md)
13. [testing/test-strategy.md](testing/test-strategy.md), [golden-scenarios.md](testing/golden-scenarios.md), [architecture-fitness-functions.md](testing/architecture-fitness-functions.md), [definition-of-done.md](testing/definition-of-done.md)
14. [roadmap/master-roadmap.md](roadmap/master-roadmap.md), [phase-breakdown.md](roadmap/phase-breakdown.md), [dependency-map.md](roadmap/dependency-map.md), [effort-estimation.md](roadmap/effort-estimation.md), [risk-register.md](roadmap/risk-register.md), [spikes/spike-plan.md](spikes/spike-plan.md)
15. ADRs in [adr/](adr/)
16. [FINAL-REPORT.md](FINAL-REPORT.md) (summary + P01 preconditions)

## Batch 1 documents

| Document | Purpose |
|---|---|
| [assessment/legacy-repo-assessment.md](assessment/legacy-repo-assessment.md) | Evidence-based review of `my_time_manager` |
| [assessment/legacy-component-matrix.md](assessment/legacy-component-matrix.md) | Reuse/Refactor/Replace/Rewrite per component |
| [product/product-vision.md](product/product-vision.md) | Positioning and principles |
| [product/product-scope.md](product/product-scope.md) | MVP, deferred list, non-goals |
| [product/personas-and-use-cases.md](product/personas-and-use-cases.md) | 20 use cases, MVP ones in full |
| [product/requirements.md](product/requirements.md) | Functional and non-functional requirements |
| [architecture/architecture-principles.md](architecture/architecture-principles.md) | Principles and layering |
| [architecture/bounded-contexts.md](architecture/bounded-contexts.md) | Preliminary contexts and ownership |
| [architecture/context-map.md](architecture/context-map.md) | Relationships and contracts |
| [research/verified-sources.md](research/verified-sources.md) | Official-source claims with check dates |
| [adr/0001-record-architecture-decisions.md](adr/0001-record-architecture-decisions.md) | ADR process |
| [adr/0002-greenfield-repo-selective-port.md](adr/0002-greenfield-repo-selective-port.md) | New repo, selective porting |
| [adr/0003-backend-decision-deferred-to-spike.md](adr/0003-backend-decision-deferred-to-spike.md) | Backend choice via spike |
| [adr/0004-modular-monolith-and-bounded-contexts.md](adr/0004-modular-monolith-and-bounded-contexts.md) | Architecture style |
| [adr/0005-mvp-scope-personal-first.md](adr/0005-mvp-scope-personal-first.md) | Narrow MVP, amended |
| [adr/0006-habit-is-a-task-capability.md](adr/0006-habit-is-a-task-capability.md) | Habit modeled as a Task capability |
| [adr/0007-single-schedule-with-derived-occurrences.md](adr/0007-single-schedule-with-derived-occurrences.md) | One schedule per Task/Event, derived occurrences |
| [adr/0008-guest-first-with-optional-account-binding.md](adr/0008-guest-first-with-optional-account-binding.md) | Guest-first profile, optional account, bind-or-new-profile |

## Batch 2 documents

| Document | Purpose |
|---|---|
| [architecture/domain-model.md](architecture/domain-model.md) | Cross-context aggregates, shared value objects, event catalog, canonical invariant IDs |
| [domains/README.md](domains/README.md) | Domain doc template and index |
| [domains/workspace-and-access.md](domains/workspace-and-access.md) | LocalProfile, Workspace, AccountBinding |
| [domains/task-management.md](domains/task-management.md) | Task, Subtask, capabilities, Habit-as-capability |
| [domains/planning-scheduling.md](domains/planning-scheduling.md) | Time Kernel: schedule, recurrence, occurrences, DST, reminder ownership |
| [domains/calendar-events.md](domains/calendar-events.md) | Event, Calendar, conflict detection |
| [domains/execution-measurement.md](domains/execution-measurement.md) | FocusSession, ExecutionRecord, Measurement, health seam |
| [domains/goals-projects.md](domains/goals-projects.md) | Goal, Project, Milestone, derived progress |
| [domains/deferred-contexts.md](domains/deferred-contexts.md) | Contract stubs for P05+ contexts |
| [governance/governance-kernel.md](governance/governance-kernel.md) | Command gateway, idempotency, concurrency, outbox |
| [governance/authorization-model.md](governance/authorization-model.md) | Actors, authority, MVP policy, P04 extension |
| [governance/ai-action-governance.md](governance/ai-action-governance.md) | AI proposal/approval lifecycle, threats |
| [governance/audit-and-provenance.md](governance/audit-and-provenance.md) | Audit entry, measurement and AI provenance |
| ADRs 0009–0014 | IDs/versioning, time model, command gateway, AI approval binding, Time Kernel packaging, transactional outbox and atomic side effects |

## Batch 3a documents

| Document | Purpose |
|---|---|
| [data/data-architecture.md](data/data-architecture.md) | Local store (Drift), source-of-truth map, whole-file encryption, backup, profile isolation |
| [data/local-storage.md](data/local-storage.md) | Shared column set, table ownership, migrations, FTS |
| [data/sync-protocol.md](data/sync-protocol.md) | Outbox/inbox, idempotency, per-type conflict resolution, tombstones (P04 contract) |
| [data/data-classification.md](data/data-classification.md) | Four classes + default-deny egress matrix |
| [security/threat-model.md](security/threat-model.md) | Assets, trust boundaries, STRIDE threats, mitigations |
| [security/privacy-model.md](security/privacy-model.md) | No-telemetry decision + debugging path, consent, revocation, export/delete |
| [security/security-requirements.md](security/security-requirements.md) | Testable security requirements |
| ADRs 0015–0016 | Per-type conflict resolution; data classification and egress policy |

## Batch 3b documents

| Document | Purpose |
|---|---|
| [domains/health-integration.md](domains/health-integration.md) | Health & Activity (Android Health Connect, P08); evidence-only via RecordMeasurement |
| [domains/dictionary-translation.md](domains/dictionary-translation.md) | Dictionary + Translation: separate models, provider ports/ACL, selection adapter |
| [domains/vocabulary-learning.md](domains/vocabulary-learning.md) | Saved vocabulary, flashcards, deterministic spaced repetition |
| [domains/document-knowledge.md](domains/document-knowledge.md) | Document aggregate, block/revision model, links, viewers, collaboration maturity |
| ADR-0017 | Document collaboration maturity (single-user + revision sync; CRDT deferred) |

## Batch 3c documents

| Document | Purpose |
|---|---|
| [architecture/technical-stack.md](architecture/technical-stack.md) | Stack choices (chosen now / candidate+spike / port only) with licenses |
| [architecture/ai-architecture.md](architecture/ai-architecture.md) | AI platform contract: context-builder scoping, provider routing, threats (consumes ADR-0012/0016) |
| [architecture/ui-ux-architecture.md](architecture/ui-ux-architecture.md) | Adaptive layout, navigation, cross-cutting interactions, state boundary |
| [architecture/repository-structure.md](architecture/repository-structure.md) | Monorepo, package dependency table, fitness-function IDs FF-ARCH-01..08 |
| ADRs 0018–0020 | License policy; Riverpod + go_router; editor decision/spike |
| [adr/0021-encryption-at-rest-platform-posture.md](adr/0021-encryption-at-rest-platform-posture.md) | P01/T5: encryption injectable — Android encrypted, Windows MVP plain + tracked exception (amended by 0022) |
| [adr/0022-windows-encryption-at-rest.md](adr/0022-windows-encryption-at-rest.md) | P01/T5a: Windows encrypted too; plain Windows only as an explicit fallback build flag |
| [adr/0023-per-profile-stores-and-registry.md](adr/0023-per-profile-stores-and-registry.md) | P01/T6c: one DB file + key per profile, encrypted registry, cross-store ordering |
| [adr/0024-sign-out-locks-the-account-profile.md](adr/0024-sign-out-locks-the-account-profile.md) | P01/T6c: sign-out keeps the binding and locks the profile until the same account signs in |
| [adr/0025-profile-export-and-restore.md](adr/0025-profile-export-and-restore.md) | P01/T7–T7c: decrypted, versioned, checksummed export; restore into the same profile, or the same account's profile on another device (overwrite or merge, undo), or as a new profile; closes OQ-DATA-3 (a) |
| [adr/0026-reopen-and-trash-with-subtasks.md](adr/0026-reopen-and-trash-with-subtasks.md) | P01/T7c: reopen a done task; trash a parent with or without its subtasks (ask, or a device setting) |
| [adr/0027-delete-a-profile-on-this-device.md](adr/0027-delete-a-profile-on-this-device.md) | P01/T7d: delete a profile that is not open (file, key, registry entry), finished on next open if interrupted |
| [adr/0028-time-types-and-dst-resolution.md](adr/0028-time-types-and-dst-resolution.md) | P02/T1: time data in foundation, zone database and DST rule in time_kernel; ScheduleSpec |

## Batch 4 documents

| Document | Purpose |
|---|---|
| [invariants/invariant-catalog.md](invariants/invariant-catalog.md) | Single source of truth for all 62 `LF-INV-*` |
| [invariants/policy-catalog.md](invariants/policy-catalog.md) | Named policies (completion, conflict, egress, retention, AI approval, license...) |
| [invariants/invariant-test-matrix.md](invariants/invariant-test-matrix.md) | Invariant × verification × golden scenario / fitness fn (0 gaps) |
| [testing/test-strategy.md](testing/test-strategy.md) | Layers, tooling, performance targets, crash/sync approach |
| [testing/golden-scenarios.md](testing/golden-scenarios.md) | GS-01..22 incl. crash-window/concurrency |
| [testing/architecture-fitness-functions.md](testing/architecture-fitness-functions.md) | FF-ARCH-01..09, provisional-name reconciliation |
| [testing/definition-of-done.md](testing/definition-of-done.md) | Per-phase DoD + template |

## Batch 5 documents

| Document | Purpose |
|---|---|
| [FINAL-REPORT.md](FINAL-REPORT.md) | Stakeholder entry point; answers the brief's final questions; P01 preconditions |
| [roadmap/master-roadmap.md](roadmap/master-roadmap.md) | Phase sequence, MVP, critical path (ordinal) |
| [roadmap/phase-breakdown.md](roadmap/phase-breakdown.md) | Per-phase detail P00–P10 (references DoD/matrix) |
| [roadmap/dependency-map.md](roadmap/dependency-map.md) | Phase + spike dependency graph, human review gates |
| [roadmap/effort-estimation.md](roadmap/effort-estimation.md) | Person-day ranges (dev+agent), critical path, out-of-scope |
| [roadmap/risk-register.md](roadmap/risk-register.md) | Full risk register; defer/not-build/buy summary |
| [spikes/spike-plan.md](spikes/spike-plan.md) | All spikes, time-boxed, escalate-as-Open |

The design phase is complete. The next step is implementation starting at P01, gated by the preconditions in [FINAL-REPORT.md](FINAL-REPORT.md) section 19.

## Spike phase (MVP-blocking spikes)
Results: [spikes/spike-results.md](spikes/spike-results.md). Throwaway POC code lives on `spike/*` and `scaffold/p01-skeleton` branches (not merged to `main`).
- **S-03a (auth):** PASS on Windows — Supabase Auth, GitHub, PKCE S256, offline session. ADR-0003 auth half Accepted. Android/email follow-up.
- **S-01 (Flutter + Drift):** PASS on Windows — CRUD + transaction + persistence + rollback. Finding OQ-STACK-2 (resolved stack is sqlite3 2.x, not 3.x hooks). Android follow-up.
- **S-02 (migrations + FTS5 + encryption):** plain build PASS (FTS5 + migrations); **encryption-at-rest on Windows is Open, escalated to an early P01 task** (both SQLCipher/OpenSSL and sqlite3mc/3.x-hook failed to build on Windows). Risk R-ENCRYPTION-WINDOWS.
| 4 | Invariant catalog, policy catalog, invariant test matrix, fitness functions, test strategy, golden scenarios, definition of done |
| 5 | Master roadmap, phase breakdown, dependency map, spike plan, effort estimation, risk register |

Conventions for later batches:
- Spike numbers follow the order in the original brief: S-01 Flutter+Drift, S-02 SQLite migrations/offline, S-03a auth only (new, must precede P01 exit), S-03 Supabase RLS for shared workspaces, S-04 offline sync and conflicts, S-05 background/notification on Windows and Android, S-10 dictionary dataset licensing, S-13 Health Connect, S-14 HealthKit.
- Invariant IDs shown in Batch 1 (`LF-INV-*`) and event names are provisional until Batch 4 and Batch 2.

## Preconditions before starting Batch 3

1. Owner reviews the domain model ([architecture/domain-model.md](architecture/domain-model.md)) and the governance kernel, and confirms or edits the in-batch decisions: subtask depth = 4 (OQ-R1), parent-completion prompt (OQ-R3), time model (ADR-0010), Time Kernel as its own package (ADR-0013), command gateway (ADR-0011), AI approval binding (ADR-0012), reminder ownership (OQ-B4).
2. Owner confirms ADR-0002 (port rules). ADR-0003 stays Proposed until spike S-03a runs.
3. Non-blocking: OQ-S7 (sign-out), and the per-context open questions listed below, can be answered in their phase.

Resolved in Batch 2: OQ-B1 (Time Kernel package, ADR-0013), OQ-R1 (subtask depth 4), OQ-R2 (time model, ADR-0010), OQ-R3 (explicit parent-completion choice), OQ-B4 (reminder is an owner capability).

Resolved 2026-11-04 (pre-spike): OQ-S7 (sign-out → profile chooser, data stays on device), OQ-DATA-1 (random 256-bit key in secure storage, no passphrase). New non-blocking: OQ-DATA-3 (key/data backup).

Resolved in P01: OQ-R4 (encryption at rest on Android and Windows, ADR-0021/0022), OQ-DATA-3 option (a) (user export as the backup, ADR-0025). **P01 done 2026-11-07** ([testing/p01-exit-gate.md](testing/p01-exit-gate.md)). P02 plan: [roadmap/p02-plan.md](roadmap/p02-plan.md).

## Unresolved decisions (summary)

| ID | Question | Doc |
|---|---|---|
| OQ-DATA-3 (b)/(c) | Passphrase-wrapped key export or cloud escrow, and passphrase-encrypted export file (option (a), the plain export, is resolved by ADR-0025) | data-architecture |
| OQ-S8 | Binding a profile to an account that already has cloud data (P04) | product-scope |
| OQ-S9 | Move all or part of a guest profile's data into an account profile (P04, owner 2026-11-07) | ADR-0024 |
| ADR-0003 | Backend choice (auth before P01 exit via spike S-03a; data/sync P04) | adr |
| OQ-GOV-2/3 | Dedupe/event-log retention; one table or two for outbox+event log | governance-kernel/data batch |
| OQ-PLAN-1/2 | Max occurrences per window; series-split on rule edit (proposals D1/D4 in [roadmap/p02-plan.md](roadmap/p02-plan.md)) | planning-scheduling |
| OQ-EXEC-1/2 | `no data` storage; health idempotency key | execution-measurement |
| OQ-AUTHZ-1/2 | P04 roles; AI usage limits as policy | authorization-model |
| OQ-AI-1/2 | Multi-command approval; offline cloud-only model | ai-action-governance |
| OQ-DICT-1..3 | Dictionary/translation sources+licenses (spike S-10), language detection, audio | dictionary-translation |
| OQ-VOCAB-1/2 | Spaced-repetition algorithm; TTS/ASR ports | vocabulary-learning |
| OQ-DOC-1..3 | Revision cadence; editor library; viewer feasibility | document-knowledge |
| OQ-HEALTH-1/2 | Read-cursor location; background-read cadence | health-integration |
| OQ-STACK-1 | Confirm SPDX for timezone/secure-storage/file/notification packages before adoption | technical-stack |
| OQ-UI-1/2 | Breakpoint widths; desktop multi-window | ui-ux-architecture |
| OQ-REPO-1/2 | Package-per-context vs folders; fitness-function naming | repository-structure |
| OQ-V1 to OQ-V10 | Unverified external claims (incl. FTS5-under-encryption) | research |

Resolved on 2026-11-04 — Batch 1: OQ-S1 (defer to P04), OQ-S2 (Goals in P03), OQ-S3 (single schedule, ADR-0007), OQ-S4 (sign-in exists in MVP), OQ-S5 (authentication only), OQ-S6 (guest-first, ADR-0008), OQ-B2 (Habit is a Task capability, ADR-0006), OQ-B3 (follows OQ-S2). Batch 2: OQ-B1 (ADR-0013), OQ-R1 (depth 4), OQ-R2 (ADR-0010), OQ-R3 (explicit parent-completion choice), OQ-B4 (reminder is a Task/Event capability).
