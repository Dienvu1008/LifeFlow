# Golden Scenarios

- Status: Draft (Batch 4)
- Date: 2026-11-04
- Related: [../invariants/invariant-catalog.md](../invariants/invariant-catalog.md), [invariant-test-matrix.md](../invariants/invariant-test-matrix.md), [test-strategy.md](test-strategy.md)

Each scenario: actor, setup, action, automatable acceptance criteria, invariants exercised, test layer, phase. These are the canonical correctness scenarios; the invariant test matrix links to them. The crash-window and concurrency scenarios (GS-06, GS-07, GS-12) are the ones ADR-0014/0015 require.

| ID | Scenario | Setup → action | Acceptance criteria (automatable) | Invariants | Layer | Phase |
|---|---|---|---|---|---|---|
| GS-01 | Measurable habit auto-completes when enough data arrives | Habit "walk ≥5000/day"; record measurements summing ≥5000 | period state becomes achieved exactly when the aggregate crosses the target; completion is derived, never set by the data source | LF-INV-TASK-010, LF-INV-HEALTH-006 | integration | P03/P08 |
| GS-02 | Measurable target boundaries | targets atLeast/atMost/about incl. min==max and infinite bounds | each boundary evaluates correctly (table-driven) | LF-INV-TASK-010 | unit | P03 |
| GS-03 | Recurrence produces no duplicate / correct count | rule "after 10 occurrences"; query overlapping windows | exactly 10 occurrences, no duplicates, no gaps; regenerating a window is identical | LF-INV-PLAN-010/012 | property | P02 |
| GS-04 | DST correctness | timed recurring item in a DST zone across the transition | occurrences keep local wall-clock; gap→first valid minute, overlap→earliest | LF-INV-PLAN-013, LF-INV-PLAN-004 | table-driven | P02 |
| GS-05 | Missing/late health data is not zero | habit day with no measurement, then a late measurement | day is `no data` not 0 until closed; late data re-evaluates; duplicates by origin id are not double-counted | LF-INV-HEALTH-002/005 | integration | P08 (MVP covers manual path) |
| GS-06 | Crash between commit and event dispatch loses no event | command commits; kill process before handler runs; restart | the event-log row exists; on restart the undispatched event is dispatched exactly once (idempotent handler) | LF-INV-OUTBOX-002, LF-INV-GOV-003 | crash/recovery | P01 |
| GS-07 | Outbox exists iff mutation committed | inject failure at various pipeline points | a committed mutation always has its outbox + audit rows; a rolled-back one has none | LF-INV-OUTBOX-001, LF-INV-AUDIT-001, LF-INV-GOV-003 | fault-injection | P01 |
| GS-08 | Two offline edits to one document | edit same document on two profiles/devices offline, then reconcile | both edits become revisions; a conflict is surfaced; no content silently lost | LF-INV-DOC-002/005, LF-INV-SYNC-003 | sync | P04/P05 |
| GS-09 | Vocabulary progress not overwritten by dictionary update | saved word with review progress; refresh its LexicalEntry | review state and capture context unchanged after the entry updates | LF-INV-VOCAB-002 | integration | P07 |
| GS-10 | Health permission revoked mid-run | permission granted, data stored; revoke while app running | reads stop; stored data remains with provenance marked revoked-source; not treated as zero | LF-INV-HEALTH-001/003 | integration | P08 |
| GS-11 | Cross-workspace / cross-profile read denied | profile A data; attempt a command/query scoped to A from profile B | denied/empty; no data crosses profiles | LF-INV-ID-002, LF-INV-GOV-002 | integration + architecture | P01 |
| GS-12 | Concurrent writers → one wins | two commands with the same expectedVersion on one aggregate | exactly one applies (version+1); the other returns VersionConflict; no lost update | LF-INV-VER-001 | concurrency | P01 |
| GS-13 | Focus session recovers after crash | start session; kill at minute 12; relaunch | session recoverable with elapsed within 1s; at most one ExecutionRecord; pause total preserved; session state ≠ task status | LF-INV-EXEC-002/003/004 | crash/recovery | P03 |
| GS-14 | Delete/tombstone syncs correctly | delete on device A; device B offline then online | tombstone propagates; B reflects the delete; purge after retention propagates | LF-INV-SYNC-004 | sync | P04 |
| GS-15 | Stale AI proposal rejected | AI proposal computed at version v; resource changes to v+1; approve | execution revalidates and rejects; user must regenerate | LF-INV-AI-002 | integration | P06 |
| GS-16 | Cloud AI never receives Restricted context | request with health (Restricted) in scope; cloud engine selected | the egress checkpoint drops Restricted; it never appears in the cloud request | LF-INV-PRIV-002/003 | egress/security | P06 |
| GS-17 | Offline changes survive sync | create/edit offline; go online and sync | all local changes appear after sync; none lost; idempotent replay | LF-INV-SYNC-001, LF-INV-OUTBOX-001 | sync | P04 |
| GS-18 | Task hierarchy stays acyclic and bounded | random sequence of reparent/create commands | parent graph is always acyclic; depth never exceeds the limit; existing deeper data (if limit lowered) stays valid | LF-INV-TASK-002/003 | property | P01 |
| GS-19 | Encryption at rest | open the DB file outside the app | the file is not readable as a plain SQLite DB; `PRAGMA cipher` is present in-app | LF-INV-SEC-011, LF-INV-SEC-001 | security | P01 |
| GS-20 | Export/restore round trip | populate data incl. subtasks, recurrence exceptions, measurement history, tombstones; export; restore into clean install | restored data equals original; audit/provenance included; newer-version file rejected by older app | LF-INV-SEC-010, LF-INV-EXEC-001 | integration | P01 |
| GS-21 | Goal progress is derived, delete keeps tasks | goal linking tasks/habit; complete some; delete the goal | progress is a pure function of linked items; deleting the goal leaves tasks intact | LF-INV-GOAL-001/002 | unit + integration | P03 |
| GS-22 | Guest→account binding keeps IDs; offline works | guest with data; sign in; choose move vs new | "move" keeps every ID and workspaceId; "new" isolates; airplane-mode use works; no token in logs | LF-INV-ID-001/002, LF-INV-SEC-001/002 | integration | P01 |

## Self-check
- [x] The owner's crash-window/concurrency set is present: GS-06, GS-07, GS-12 (plus GS-13 recovery, GS-08 document conflict, GS-05 measurement-not-overwritten via correction path).
- [x] The brief's golden list is covered (GS-01, GS-05, GS-03, GS-04, GS-17, GS-10, GS-08, GS-08/revision, GS-09, GS-15, GS-11, GS-16, GS-13, GS-14).
- [x] Every scenario has automatable criteria, invariant links, a test layer and a phase.
