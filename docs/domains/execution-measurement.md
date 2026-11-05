# Domain: Execution and Measurement

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Classification: Core. Phase: P03 (FocusSession and ExecutionRecord usable earlier for focus; measurement evaluation ties to habits). In MVP: yes.
- Related: [task-management.md](task-management.md), [ADR-0009](../adr/0009-identifier-and-versioning-strategy.md), [ADR-0010](../adr/0010-time-model-date-only-vs-instant.md)

## 1. Purpose
Record what actually happened and the evidence for it: focus sessions, execution records, and measurements with provenance. This context owns "actual", so Health (P08) can later publish evidence here through one contract without touching Task Management.

## 2. Aggregate roots and boundaries
- **`FocusSession`** (root): a running or finished focus/stopwatch session. Boundary: the session's own state machine.
- **`ExecutionRecord`** (root): a record of an actual execution of a Task/occurrence, optionally produced from a FocusSession. Boundary: the record and its `Measurement`s.
- `Measurement` (child of `ExecutionRecord`, or standalone against a target): a single observed value with provenance.

[Decision] A standalone `Measurement` (for example a manual steps entry not tied to a focus session) is recorded against a `MeasurableTarget` reference (a Task's capability) and a `LocalDate`, without requiring an `ExecutionRecord`. Both paths produce `MeasurementRecorded`.

## 3. Entities and value objects
- `FocusSession`: `sessionId`, `taskId?`, `mode {pomodoro, stopwatch}`, `startInstant: Instant`, `plannedDuration: Duration?`, `pausedTotal: Duration`, `state {running, paused, ended, cancelled, unrecoverable}`, `version`, timestamps. Remaining time is **derived** (`now - start - pausedTotal`), never stored as a counter (FR-FOCUS-04).
- `ExecutionRecord`: `recordId`, `taskId?`, `actualStart: Instant`, `actualEnd: Instant?`, `note?`, `measurements: List<Measurement>`, `version`, timestamps.
- `Measurement`: `measurementId`, `targetRef {taskId, capability}`, `value: Quantity`, `unit`, `source {manual, focusSession, import, health(P08)}`, `provenance {deviceId, recordedAt: Instant, origin}`, `localDate: LocalDate`, `supersedesId?` (for corrections).

## 4. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-EXEC-001 | History is preserved: a correction creates a new Measurement that `supersedes` the old; the old is kept | `CorrectMeasurement` command |
| LF-INV-EXEC-002 | Duration accounting is accurate within 1s after recovery; uses monotonic/UTC math | FocusSession derivation |
| LF-INV-EXEC-003 | A session in `running`/`paused` is recoverable after crash | state persisted at start and on each transition |
| LF-INV-EXEC-004 | At most one ExecutionRecord per FocusSession | `EndFocusSession` keyed by sessionId |
| LF-INV-HEALTH-002 | A period with no Measurement is `no data`, not zero | period evaluation (in Task Management) reads only existing Measurements |
| LF-INV-HEALTH-004 | Every Measurement keeps its provenance | `Measurement` requires `source` + `provenance` |

## 5. Domain services
- `FocusSessionMachine`: transitions (start, pause, resume, end, cancel) and recovery (`recover(now)` decides resume vs ended-at-planned-end vs unrecoverable). Explicit pause/cancel semantics (FR-FOCUS-02).
- `MeasurementAggregator`: aggregates measurements for a target over a period using the target's `aggregation` policy (sum/max/latest/average) and `localDate` keys. Pure; shares the legacy `FocusStatisticsService` and `HabitStatisticsService` concepts (reusable).

## 6. Commands
| Command | Actor | Args | Preconditions | Result | Events | Idempotency | Concurrency |
|---|---|---|---|---|---|---|---|
| `StartFocusSession` | owner | taskId?, mode, plannedDuration? | no active session for the task (or allowed) | session running, persisted | `FocusSessionStarted` | by `operationId` | n/a |
| `PauseFocusSession` / `ResumeFocusSession` | owner | sessionId | state running/paused | state change | — (audited) | by `operationId` | `expectedVersion` |
| `EndFocusSession` | owner | sessionId, countTime: bool | session exists | ended; optional ExecutionRecord | `FocusSessionEnded` (+ `ExecutionRecorded` if counted) | by sessionId | `expectedVersion` |
| `CancelFocusSession` | owner | sessionId | session exists | cancelled, no record | `FocusSessionEnded` | by sessionId | `expectedVersion` |
| `RecoverFocusSession` | system (on launch) | sessionId, decision | session in running/paused | recovered state | `FocusSessionRecovered` | by sessionId | `expectedVersion` |
| `RecordMeasurement` | owner / Health(P08) / Learning(P09) via gateway | targetRef, value, unit, source, provenance, localDate | value valid for unit | measurement stored | `MeasurementRecorded` | by `operationId` (dedupe by (source, origin-id) when provided) | n/a |
| `CorrectMeasurement` | owner | measurementId, newValue | measurement exists | new superseding measurement | `MeasurementCorrected` | by `operationId` | `expectedVersion` on record |

## 7. Queries / read ports (published)
- `ExecutionSummary(taskId, window)`: planned vs actual, total focus minutes.
- `MeasurementSeries(targetRef, period)`: aggregated value + `no data` flag per period. Consumed by Task Management (habit evaluation) and Goals.

## 8. Domain events
`FocusSessionStarted`, `FocusSessionEnded`, `FocusSessionRecovered`, `ExecutionRecorded`, `MeasurementRecorded`, `MeasurementCorrected`.

## 9. Repository contract
```
FocusSessionRepository:
  getActive(): FocusSession?
  getById(SessionId): FocusSession?
  recoverable(): List<FocusSession>
  save(FocusSession): void
ExecutionRepository:
  recordsFor(taskId, window): List<ExecutionRecord>
  save(ExecutionRecord): void
MeasurementRepository:
  forTarget(targetRef, period): List<Measurement>
  save(Measurement): void
```

## 10. Health integration seam (P08)
[Decision] Health (P08) records evidence only by calling `RecordMeasurement` with `source = health` and full provenance (origin device, Health Connect record id, read window). It never writes Task or FocusSession state, and it never sets completion. Task Management's `CompletionPolicy` decides completion from the aggregated series. De-duplication of multi-source health data happens in the Health context's anti-corruption layer before it calls `RecordMeasurement` (detailed in the health batch).

## 11. Open questions
- OQ-EXEC-1: should `no data` vs `0` be a stored period state or always derived? Proposal: derived from measurement presence; store only the evaluated completion when a period closes. Data batch.
- OQ-EXEC-2: idempotency key for health-sourced measurements (Health Connect client id)? Health batch; the `RecordMeasurement` dedupe hook is already provided.

## 12. Self-check
- [x] Focus session is a persisted, recoverable state machine (contrast legacy in-memory tick).
- [x] Measurement carries provenance and corrections keep history.
- [x] Health seam is a single inbound command; no write-back to Task.
