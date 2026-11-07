# Invariant Catalog

- Status: Draft (Batch 4). **This is the single source of truth for `LF-INV-*`.** The index in [../architecture/domain-model.md](../architecture/domain-model.md) is a summary; on any discrepancy, this catalog wins.
- Date: 2026-11-04
- Related: [policy-catalog.md](policy-catalog.md), [invariant-test-matrix.md](invariant-test-matrix.md), [../testing/golden-scenarios.md](../testing/golden-scenarios.md)

Fields per entry: statement (formal), rationale, scope, enforcement point, failure behavior, verification method, severity, dependencies. Severity: **critical** (data loss, security, or authority bypass), **high** (correctness of a core feature), **medium** (contained correctness). Verification method names the layer(s) in [../testing/test-strategy.md](../testing/test-strategy.md).

Harvest note (Batch 4): 60 invariants were found across the docs and are all cataloged below. No invariant was altered. Two were newly **named** here to close gaps found during consolidation (LF-INV-DOC-005, LF-INV-SEC-011) and added back to the domain-model index; both are marked "introduced in Batch 4".

## 1. Identity and Workspace

### LF-INV-ID-001 — Stable identity
- Statement: once created, an entity's ID never changes, including across update, account binding and (future) sync.
- Rationale: sync and references depend on stable IDs (ADR-0009, ADR-0008).
- Scope: all aggregates. Enforcement: ID is immutable on the aggregate; `BindAccount` does not re-key. Failure: reject the operation. Verification: unit + property + binding integration test (GS-22). Severity: critical. Depends: —.

### LF-INV-ID-002 — Profile isolation
- Statement: data of one LocalProfile is never visible to another.
- Rationale: privacy on a shared device (ADR-0008). Scope: Workspace and Access + storage. Enforcement: one encrypted DB file per profile; all queries scoped by `workspaceId`. Failure: deny/empty. Verification: isolation integration test (GS-22), architecture scan. Severity: critical. Depends: LF-INV-SEC-001.

### LF-INV-WA-001 — One active workspace (MVP)
- Statement: a profile has exactly one active Personal Workspace in the MVP. Rationale: MVP simplicity. Scope: Workspace. Enforcement: profile invariant. Failure: reject. Verification: unit. Severity: medium. Depends: —.

## 2. Task and Planning

### LF-INV-TASK-001 — Task identity stable
- Statement: a Task's identity is stable across updates, move, binding, restart. Rationale: references and history. Scope: Task. Enforcement: immutable ID. Failure: reject. Verification: unit + property. Severity: critical. Depends: LF-INV-ID-001.

### LF-INV-TASK-002 — Bounded hierarchy depth (command-time)
- Statement: a `CreateTask`/`Reparent` may not place a task deeper than the current depth limit (4); the limit is checked at command time, not stored, so changing it is not a data migration. Rationale: predictable hierarchy/UI; owner decision OQ-R1. Scope: Task. Enforcement: `CreateTask`/`Reparent`. Failure: reject command. Verification: unit + property (random depth). Severity: high. Depends: —.

### LF-INV-TASK-003 — No hierarchy cycles
- Statement: the parent graph is acyclic. Rationale: integrity. Scope: Task. Enforcement: `Reparent` rejects if the new parent is the task or a descendant. Failure: reject. Verification: property test over random reparents (GS: task hierarchy). Severity: high. Depends: LF-INV-TASK-002.

### LF-INV-TASK-004 — Valid status transitions
- Statement: status changes follow the allowed graph. Rationale: lifecycle correctness. Scope: Task. Enforcement: `Task.transition`. Failure: reject. Verification: state-machine test. Severity: high. Depends: —.

### LF-INV-TASK-010 — Measurement policy enforced
- Statement: a measurable task's completion respects its MeasurableTarget + CompletionPolicy. Rationale: habits must be accurate. Scope: Task + Execution. Enforcement: completion service over Execution summaries. Failure: do not complete. Verification: table-driven + integration (GS-01). Severity: high. Depends: LF-INV-EXEC-001.

### LF-INV-TASK-011 — Trash excludes but preserves
- Statement: a trashed task is excluded from active views but kept until purge. Rationale: recoverable delete; sync tombstones. Scope: Task. Enforcement: query scoping + tombstone. Failure: — (query filter). Verification: unit + integration. Severity: medium. Depends: LF-INV-SYNC-004.

### LF-INV-PLAN-004 — Date-only preserved
- Statement: a date-only ScheduleSpec is never implicitly converted to an instant. Rationale: avoid timezone drift (ADR-0010). Scope: Time Kernel. Enforcement: type separation. Failure: compile/validation error. Verification: property + unit (GS: DST/date). Severity: high. Depends: —.

### LF-INV-PLAN-010 — Recurrence bounded and deterministic
- Statement: occurrence generation is bounded per window and deterministic. Rationale: no runaway expansion (ADR-0007). Scope: Time Kernel. Enforcement: `OccurrenceWindowQuery` hard cap + pure function. Failure: truncate with notice. Verification: property (determinism) + unit (GS-03). Severity: critical. Depends: —.

### LF-INV-PLAN-011 — Exceptions preserved across rule edits
- Statement: exceptions survive rule edits that do not change their original date. Rationale: user intent (ADR-0007). Scope: Time Kernel/Task. Enforcement: exceptions keyed by original date, applied after generation. Failure: — . Verification: unit + integration. Severity: high. Depends: LF-INV-PLAN-010.

### LF-INV-PLAN-012 — No duplicate occurrences
- Statement: a window never yields duplicate occurrences. Rationale: correctness (GS-03). Scope: Time Kernel. Enforcement: de-dup by original date. Failure: — . Verification: property test. Severity: high. Depends: LF-INV-PLAN-010.

### LF-INV-PLAN-013 — Wall-clock preserved across DST
- Statement: a timed recurring item keeps its local wall-clock time across DST. Rationale: correctness (ADR-0010). Scope: Time Kernel. Enforcement: `ZonedWallClock` + resolver. Failure: resolver rule. Verification: table-driven over DST zones (GS-04). Severity: high. Depends: LF-INV-PLAN-004.

## 3. Calendar

### LF-INV-CAL-001 — Event distinct from Task
- Statement: an Event has its own identity, never shared with a Task. Rationale: domain separation. Scope: Calendar. Enforcement: separate aggregate/ID space. Failure: reject. Verification: unit. Severity: medium. Depends: —.

### LF-INV-CAL-002 — All-day excluded from timed conflicts
- Statement: all-day events use LocalDate and are excluded from timed conflict detection by default. Rationale: correct conflict UX. Scope: Calendar. Enforcement: `OverlapQuery` input mapping. Failure: — . Verification: unit (GS: conflict). Severity: medium. Depends: LF-INV-PLAN-004.

## 4. Execution and Measurement

### LF-INV-EXEC-001 — History preserved
- Statement: corrections create a new record/measurement that supersedes the old; the old is kept. Rationale: no silent loss of actuals. Scope: Execution. Enforcement: `CorrectMeasurement`/append-only. Failure: reject overwrite. Verification: unit + integration (GS: measurement correction). Severity: critical. Depends: —.

### LF-INV-EXEC-002 — Accurate duration
- Statement: focus duration is accurate within 1s after recovery; uses monotonic/UTC math. Rationale: trustworthy actuals. Scope: Execution. Enforcement: derive from timestamps, not a counter. Failure: reject negative. Verification: unit + crash/recovery (GS-13). Severity: high. Depends: —.

### LF-INV-EXEC-003 — Session recoverable
- Statement: a running/paused focus session is recoverable after crash. Rationale: no lost focus time (FR-FOCUS-05). Scope: Execution. Enforcement: persist at start and each transition. Failure: mark unrecoverable, never silently drop. Verification: crash/recovery test (GS-13). Severity: critical. Depends: LF-INV-EXEC-002.

### LF-INV-EXEC-004 — One record per session
- Statement: at most one ExecutionRecord per focus session. Rationale: no double counting. Scope: Execution. Enforcement: `EndFocusSession` keyed by sessionId; idempotent. Failure: dedupe. Verification: idempotency test (GS-13). Severity: high. Depends: LF-INV-GOV-003.

## 5. Goals and Projects

### LF-INV-GOAL-001 — Derived progress, no write-back
- Statement: Goal/Project progress is derived read-only; no Goal operation writes to a Task. Rationale: Goals do not own Tasks. Scope: Goals. Enforcement: progress service reads only. Failure: — . Verification: unit (pure function) + integration (GS-21). Severity: high. Depends: —.

### LF-INV-GOAL-002 — Delete removes links, not tasks
- Statement: deleting a Goal/Project removes links, not the linked Tasks. Scope: Goals. Enforcement: `TrashGoal`/`DeleteLink`. Failure: — . Verification: integration (GS-21). Severity: high. Depends: —.

### LF-INV-GOAL-003 — Cross-workspace link rejected
- Statement: a linked resource in another workspace is rejected. Scope: Goals. Enforcement: link command checks workspaceId. Failure: reject. Verification: unit (P04-relevant). Severity: medium. Depends: LF-INV-ID-002.

## 6. Document and Knowledge

### LF-INV-DOC-001 — No hierarchy cycle
- Statement: document hierarchy has no parent-child cycle. Scope: Document. Enforcement: `MoveDocument` ancestry check. Failure: reject. Verification: property test. Severity: high. Depends: —.

### LF-INV-DOC-002 — Revision history preserved
- Statement: revision history is preserved; no silent content loss; conflicts keep both. Scope: Document. Enforcement: append-only revisions; keep-both (ADR-0015). Failure: keep both. Verification: integration (GS-08). Severity: critical. Depends: LF-INV-SYNC-003.

### LF-INV-DOC-003 — References resolve or marked broken
- Statement: internal references resolve or are marked broken, never silently dropped. Scope: Document. Enforcement: reference integrity check. Failure: mark broken. Verification: unit. Severity: medium. Depends: —.

### LF-INV-DOC-004 — Distinct relation types
- Statement: hierarchy, hyperlink, semantic reference, attachment and cross-context link are distinct relations. Scope: Document. Enforcement: separate value objects. Failure: — . Verification: unit/architecture. Severity: medium. Depends: —.

### LF-INV-DOC-005 — No silent content loss on concurrent edit (introduced in Batch 4)
- Statement: two concurrent edits to one document never silently discard content; both become revisions with a surfaced conflict. Rationale: the brief's "no silent content loss" was implied by LF-INV-DOC-002 + ADR-0015 but not a named invariant; named here for the test matrix. Scope: Document + Sync. Enforcement: per-type keep-both (ADR-0015). Failure: keep both, surface conflict. Verification: sync conflict test (GS-08). Severity: critical. Depends: LF-INV-DOC-002, LF-INV-SYNC-003.

## 7. Dictionary and Vocabulary

### LF-INV-DICT-001 — Lexical identity separate from contextual meaning
- Scope: Dictionary/Vocabulary. Enforcement: separate models. Verification: unit. Severity: medium. Depends: —.
### LF-INV-DICT-002 — Source/license provenance preserved
- Scope: Dictionary. Enforcement: ACL attaches source/license. Verification: unit. Severity: high. Depends: —.
### LF-INV-DICT-003 — AI definitions not authoritative
- Scope: Dictionary. Enforcement: lookup stores provider data only. Verification: unit. Severity: medium. Depends: —.
### LF-INV-DICT-004 — Translation routing obeys egress
- Scope: Translation. Enforcement: provider router checks classification. Verification: unit + egress test. Severity: high. Depends: LF-INV-PRIV-001.
### LF-INV-VOCAB-001 — Lookup is not save
- Scope: Vocabulary. Enforcement: explicit `SaveVocabulary`. Verification: unit. Severity: medium. Depends: —.
### LF-INV-VOCAB-002 — Dictionary updates never overwrite progress
- Scope: Vocabulary. Enforcement: SavedVocabulary owns user data. Verification: integration (GS-09). Severity: high. Depends: —.
### LF-INV-VOCAB-003 — Deterministic review scheduling
- Scope: Vocabulary. Enforcement: pure spaced-repetition function. Verification: property test (reproducibility). Severity: high. Depends: —.
### LF-INV-VOCAB-004 — Review Tasks via Task contract
- Scope: Vocabulary. Enforcement: `CreateReviewTask` calls `CreateTask`. Verification: contract test. Severity: high. Depends: LF-INV-GOV-001.

## 8. Health and Activity

### LF-INV-HEALTH-001 — Permission-scoped, re-checked
- Scope: Health. Enforcement: re-check before each use. Verification: integration (GS-10). Severity: high. Depends: —.
### LF-INV-HEALTH-002 — Missing data is not zero
- Scope: Execution + Health. Enforcement: period evaluation reads only existing measurements. Verification: unit + integration (GS-05). Severity: critical. Depends: LF-INV-EXEC-001.
### LF-INV-HEALTH-003 — Revocation is not deletion, not zero
- Scope: Health. Enforcement: revocation keeps data with provenance. Verification: integration (GS-10). Severity: high. Depends: LF-INV-HEALTH-002, LF-INV-HEALTH-004.
### LF-INV-HEALTH-004 — Provenance preserved
- Scope: Execution + Health. Enforcement: ACL requires provenance. Verification: unit. Severity: high. Depends: —.
### LF-INV-HEALTH-005 — Duplicate protection
- Scope: Health ACL. Enforcement: dedup by origin id / Changes token. Verification: unit + integration (GS-05). Severity: high. Depends: —.
### LF-INV-HEALTH-006 — Evidence cannot bypass completion policy
- Scope: Health. Enforcement: Health only calls `RecordMeasurement`; Task decides completion. Verification: contract + integration (GS-01). Severity: critical. Depends: LF-INV-TASK-010.

## 9. Governance and Transaction

### LF-INV-GOV-001 — Single mutation path
- Statement: all state changes go through the command gateway. Scope: Governance. Enforcement: gateway; FF-ARCH-03. Failure: reject/compile. Verification: architecture (FF-ARCH-03) + integration. Severity: critical. Depends: —.
### LF-INV-GOV-002 — Authorize before domain
- Scope: Governance. Enforcement: pipeline step 2. Verification: integration (GS-11) + unit. Severity: critical. Depends: —.
### LF-INV-GOV-003 — Atomic command side effects
- Statement: aggregate change, audit, outbox, event log and dedupe commit in one transaction. Scope: Governance. Enforcement: one DB transaction (ADR-0014). Failure: full rollback. Verification: crash/fault-injection test (GS-06, GS-07) + FF-ARCH-06. Severity: critical. Depends: —.
### LF-INV-OUTBOX-001 — Outbox iff committed
- Scope: Governance. Enforcement: same transaction. Verification: crash test (GS-07). Severity: critical. Depends: LF-INV-GOV-003.
### LF-INV-OUTBOX-002 — Event log iff committed
- Scope: Governance. Enforcement: same transaction; dispatch after commit. Verification: crash test (GS-06). Severity: critical. Depends: LF-INV-GOV-003.
### LF-INV-AUDIT-001 — Audit iff committed
- Scope: Governance. Enforcement: same transaction. Verification: crash test (GS-07) + integration. Severity: critical. Depends: LF-INV-GOV-003.
### LF-INV-VER-001 — In-transaction version check and increment
- Statement: version is re-read and compared inside the transaction, incremented only on a match, before commit. Scope: Governance. Enforcement: ADR-0014 §3.1. Failure: VersionConflict + rollback. Verification: concurrency test (GS-12). Severity: critical. Depends: LF-INV-GOV-003.

## 10. Sync

### LF-INV-SYNC-001 — Idempotent apply
- Scope: Sync (P04). Enforcement: dedupe by operationId. Verification: sync test. Severity: critical. Depends: LF-INV-GOV-003.
### LF-INV-SYNC-002 — Conflict by version not time
- Scope: Sync. Enforcement: version comparison. Verification: sync test (GS-07/GS-12 analogues). Severity: high. Depends: LF-INV-VER-001.
### LF-INV-SYNC-003 — Per-type resolution, no global LWW
- Scope: Sync. Enforcement: per-type strategies (ADR-0015). Verification: sync tests per category (GS-08, measurement/learning scenarios). Severity: critical. Depends: —.
### LF-INV-SYNC-004 — Tombstone propagation
- Scope: Governance/Sync. Enforcement: deletes are tombstones in the outbox. Verification: sync test (GS-14). Severity: critical. Depends: LF-INV-GOV-003.

## 11. Security and Privacy

### LF-INV-SEC-001 — Secrets only in secure storage
- Scope: platform adapters. Enforcement: keys/tokens in `flutter_secure_storage`; never in DB/logs/export/sync/AI context. Verification: security test + log scan. Severity: critical. Depends: —.
### LF-INV-SEC-002 — Offline never blocked by auth
- Scope: Workspace and Access. Enforcement: AuthGateway only on sign-in/refresh, never the read path. Verification: integration (airplane-mode, GS-22). Severity: critical. Depends: —.
### LF-INV-SEC-010 — Export completeness
- Scope: Data/export. Enforcement: export includes all user-owned entities + tombstones + audit. Verification: round-trip test (GS: export). Severity: high. Depends: —.
### LF-INV-SEC-011 — At-rest encryption (introduced in Batch 4)
- Statement: the local database is encrypted at rest and the app verifies the cipher at startup. Rationale: data-architecture §4 decided this but it had no named invariant for the test matrix. Scope: storage. Enforcement: SQLite3MultipleCiphers + `PRAGMA cipher` assert. Failure: refuse to run unencrypted in release. Verification: security test (`PRAGMA cipher`, file-at-rest inspection; spike S-02 check app). Severity: critical. Depends: LF-INV-SEC-001.
- **Platform posture (P01 task T5, ADR-0021, 2026-11-04):** enforced and verified on **Android** (SQLite3MultipleCiphers, `PRAGMA cipher` asserted at startup). On **Windows MVP** the app runs a plain local DB as an **explicit, tracked exception** (S-02: no Windows-clean build) — the startup self-check (`StorageSecurity.evaluate`) emits a warning and records `atRestEncrypted=false`/`trackedException=true` in diagnostics (non-silent). Windows is promoted to encrypted when a Windows-clean path is confirmed (ADR-0021 option A stretch). Mitigations: security-requirements §1a, data-classification §2a.
- **T5a (2026-11-06, ADR-0022):** enforced on **Windows as well as Android**; the plain Windows posture is now only an explicit fallback build flag. Verified on the owner's Windows device (existing plain DB encrypted in place, data intact).
- **T6b (2026-11-06):** enforcement is implemented (`openLocalStore`, sqlite3mc on every platform, key only where the policy encrypts). Verification uses the file header (SR-01e), not `PRAGMA cipher`. GS-19 is covered headless with the real sqlite3mc binary (`local_store_test.dart`) and end-to-end in the app test; Android on-device verification is part of the T6b gate.
### LF-INV-PRIV-001 — Default-deny egress
- Scope: classification. Enforcement: egress matrix (ADR-0016). Verification: egress tests (GS-12 cloud-AI analogue, FF-ARCH-08). Severity: critical. Depends: —.
### LF-INV-PRIV-002 — Restricted never to cloud AI / not shared implicitly
- Scope: classification/AI. Enforcement: Context Builder + share action. Verification: egress test (GS: cloud-AI restricted) + FF-ARCH-08. Severity: critical. Depends: LF-INV-PRIV-001.
### LF-INV-PRIV-003 — Classification enforced at every egress point
- Scope: AI/sync/share. Enforcement: each egress calls the classifier. Verification: egress tests + FF-ARCH-08. Severity: critical. Depends: LF-INV-PRIV-001.

## 12. AI

### LF-INV-AI-001 — No authorization bypass / no direct persistence
- Scope: AI governance. Enforcement: AI uses the gateway + authorization. Verification: integration (GS: AI injection) + architecture scan. Severity: critical. Depends: LF-INV-GOV-001/002.
### LF-INV-AI-002 — Approval bound to resource version
- Scope: AI governance. Enforcement: approval carries resourceRef→Version; revalidated at execution (ADR-0012). Verification: integration (GS: stale AI proposal). Severity: critical. Depends: LF-INV-VER-001.

## 13. Self-check
- [x] All 60 harvested invariants are cataloged; 2 new named invariants (LF-INV-DOC-005, LF-INV-SEC-011) are marked and will be added to the domain-model index.
- [x] Every entry has enforcement, verification and severity.
- [x] No invariant statement was changed during consolidation.
