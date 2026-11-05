# Requirements

- Status: Draft (Batch 1)
- Date: 2026-11-04
- Scope: MVP requirements in detail; post-MVP requirements only as one-line placeholders.
- Related: [product-scope.md](product-scope.md), [personas-and-use-cases.md](personas-and-use-cases.md)

Priority: **M** = MVP, **P** = post-MVP (phase in brackets). Each requirement carries a label. Requirements are testable statements, not designs.

## 1. Functional requirements (MVP)

### Task (FR-TASK)
| ID | Requirement | Pri | Label | Use case |
|---|---|---|---|---|
| FR-TASK-01 | A Task has a stable UUID that never changes. | M | Decision | UC-01 |
| FR-TASK-02 | Tasks can have child Tasks (Subtasks) up to a maximum depth decided in the domain batch. | M | Proposal | UC-01 |
| FR-TASK-03 | Re-parenting that would create a cycle is rejected. | M | Decision | UC-01 |
| FR-TASK-04 | Task has status, priority, tags and an optional list. Status values and transitions are defined in the domain batch. | M | Proposal | UC-01 |
| FR-TASK-05 | Views: Inbox, Today, Upcoming, Important, Completed, Archive, Trash. | M | Decision | UC-01 |
| FR-TASK-06 | Delete moves to Trash (tombstone); permanent delete is a separate explicit action. | M | Decision | UC-01 |
| FR-TASK-07 | A Task is composed from capabilities (schedule, measurable target, recurrence) rather than subclassed per type. | M | Proposal | UC-01 |
| FR-TASK-08 | Task changes are recorded in an activity history. | M | Proposal | UC-01 |
| FR-TASK-09 | Completing a parent with open Subtasks requires an explicit choice (default policy). | M | Proposal | UC-01 |
| FR-TASK-10 | Assignment, comments, dependencies, templates, Kanban/Timeline views. | P (P04, later) | Decision | |

### Planning and Scheduling (FR-PLAN)
| ID | Requirement | Pri | Label |
|---|---|---|---|
| FR-PLAN-01 | Schedule supports: start date only; start date-time; start+end date; start+end date-time; end only; end with time. | M | Decision |
| FR-PLAN-02 | Date-only values are stored and compared as calendar dates, never converted to instants. | M | Decision |
| FR-PLAN-03 | Deadline is a distinct concept from scheduled execution. | M | Decision |
| FR-PLAN-04 | All-day items, duration and timezone are supported. | M | Decision |
| FR-PLAN-05 | Reminders (offset or absolute) fire locally on Windows and Android. | M | Proposal |
| FR-PLAN-06 | Recurrence: daily, weekly (weekday selection), monthly, yearly, every N units. | M | Decision |
| FR-PLAN-07 | Recurrence ends by count, by date, or never; generation is windowed with a documented maximum per request. | M | Decision |
| FR-PLAN-08 | Exceptions per occurrence: skip, move, edit, cancel. | M | Decision |
| FR-PLAN-09 | Occurrences are not stored physically; only the rule and exceptions are. | M | Decision |
| FR-PLAN-10 | DST gaps and overlaps resolve by a documented deterministic rule. | M | Proposal |
| FR-PLAN-11 | Overlap detection for timed items is deterministic and AI-free. | M | Proposal |
| FR-PLAN-12 | A Task/Event has at most one Schedule and one RecurrenceRule; a second slot is a second Task/Event. | M | Decision (ADR-0007) |

### Calendar and Event (FR-CAL)
| ID | Requirement | Pri | Label |
|---|---|---|---|
| FR-CAL-01 | Event is a separate concept from Task. | M | Decision |
| FR-CAL-02 | Day, week and month views of events and scheduled tasks; layout adapts to window size. | M | Proposal |
| FR-CAL-03 | Event recurrence uses the same recurrence engine as tasks. | M | Proposal |
| FR-CAL-04 | Overlapping events are flagged. | M | Proposal |
| FR-CAL-05 | Attendees, invitations, shared calendars, external calendar sync. | P (P04) | Decision |

### Execution and Focus (FR-EXEC, FR-FOCUS)
| ID | Requirement | Pri | Label |
|---|---|---|---|
| FR-EXEC-01 | An Execution Record captures actual start, actual end, notes, and optional measurement for a Task or occurrence. | M | Proposal |
| FR-EXEC-02 | Execution records are never overwritten silently; corrections create history. | M | Decision |
| FR-EXEC-03 | Task status, Focus Session state and Execution Record are separate concepts. | M | Decision |
| FR-EXEC-04 | Planned versus actual is available per Task. | M | Proposal |
| FR-EXEC-05 | Measurement entries carry source and provenance. | M | Decision |
| FR-FOCUS-01 | Pomodoro and stopwatch modes. | M | Decision |
| FR-FOCUS-02 | Pause, resume and cancel are explicit actions. | M | Decision |
| FR-FOCUS-03 | A running session is persisted at start. | M | Decision |
| FR-FOCUS-04 | Remaining time is derived from timestamps, not a tick counter. | M | Proposal |
| FR-FOCUS-05 | After crash or restart, the session is recoverable (resume, end, discard). | M | Decision |
| FR-FOCUS-06 | Session overlay or indicator persists when navigating between screens. | M | Decision |
| FR-FOCUS-07 | Ending a session never completes a Task implicitly. | M | Decision |
| FR-FOCUS-08 | A session produces at most one Execution Record. | M | Decision |

### Measurable Habit (FR-HAB)
| ID | Requirement | Pri | Label |
|---|---|---|---|
| FR-HAB-01 | Target types: at least, at most, about with min/max. | M | Decision |
| FR-HAB-02 | Target, Measurement, Execution Record, Evidence and Completion State are distinct concepts. | M | Decision |
| FR-HAB-03 | Multiple Measurements per period; aggregation per metric (sum, max, latest, average) per day, week or custom cycle. | M | Decision |
| FR-HAB-04 | Completion policy: manual, automatic, or hybrid. MVP supports manual and automatic-from-manual-entries. | M | Proposal |
| FR-HAB-05 | Automatic evaluation never deletes or overwrites manual history. | M | Decision |
| FR-HAB-06 | A period with no Measurement is `no data`, not zero, until the period closes under the policy. | M | Decision |
| FR-HAB-07 | Changing a closed period requires explicit confirmation and is recorded. | M | Proposal |
| FR-HAB-08 | Editing a Target does not rewrite already closed periods. | M | Proposal |
| FR-HAB-09 | Health-sourced evidence and hybrid completion. | P (P08) | Decision |
| FR-HAB-10 | A Habit is a Task carrying a RecurrenceRule and a MeasurableTarget capability; it is not a separate entity type. | M | Decision (ADR-0006) |

### Goals and Projects (FR-GOAL)
| ID | Requirement | Pri | Label |
|---|---|---|---|
| FR-GOAL-01 | A Goal and a Project each have a stable UUID, title, optional description and status. | M | Proposal |
| FR-GOAL-02 | A Milestone belongs to one Goal; completing all its linked Tasks does not auto-complete the Milestone unless the user enabled that policy. | M | Proposal |
| FR-GOAL-03 | Goal/Project progress is derived (read-only) from linked Tasks and Habits; nothing writes back to a Task because of Goal progress. | M | Decision |
| FR-GOAL-04 | A Task or Habit can link to zero or more Goals/Projects without becoming owned by them. | M | Decision |
| FR-GOAL-05 | Deleting a Goal/Project does not delete its linked Tasks; only the link is removed. | M | Proposal |
| FR-GOAL-06 | Shared goals across workspaces, dependencies between projects. | P (P04+) | Decision |

### Identity and Sign-in (FR-AUTH)
| ID | Requirement | Pri | Label |
|---|---|---|---|
| FR-AUTH-01 | The app is usable from first launch without signing in (guest-first); a LocalProfile with a Personal Workspace is created automatically. | M | Decision (ADR-0008) |
| FR-AUTH-02 | Sign-in is available and optional; once created, the authentication session is cached locally so the app works offline. | M | Decision |
| FR-AUTH-03 | When a profile with existing data signs in, the app asks whether to move that data to the account. "Yes" binds the current profile; "No" creates a new profile (new session) bound to the account, leaving the previous profile and its data on the device. | M | Decision (ADR-0008) |
| FR-AUTH-04 | User content (tasks, habits, goals, events) is **not** synced to the cloud in the MVP; sign-in provides identity only. | M | Decision |
| FR-AUTH-05 | The account enables no feature beyond identity in the MVP (no cloud backup). | M | Decision |
| FR-AUTH-06 | At sign-out, behavior (return to a profile chooser, which profile becomes active) is defined. | Open (OQ-S7) | Open Question |
| FR-AUTH-07 | A device can hold more than one LocalProfile (guest and/or one per account); each profile's data is isolated from the others. | M | Decision (ADR-0008) |

### Data (FR-DATA)
| ID | Requirement | Pri | Label |
|---|---|---|---|
| FR-DATA-01 | Full local export to a versioned file with checksum. | M | Proposal |
| FR-DATA-02 | Restore from export reproduces data (round trip). | M | Proposal |
| FR-DATA-03 | Local database has tested, forward-only migrations. | M | Proposal |
| FR-DATA-04 | Deleting data produces tombstones kept long enough for future sync. | M | Proposal |

### Post-MVP placeholders
Collaboration (P04), Sync (P04), Documents (P05), AI (P06), Dictionary/Vocabulary (P07), Health (P08), Learning (P09), Advanced (P10). Detailed requirements are written in their batches.

## 2. Non-functional requirements

| ID | Requirement | Target (to be confirmed by benchmark) | Label |
|---|---|---|---|
| NFR-OFF-01 | All MVP features work with no network from first launch, signed in or not; an unreachable auth server never blocks access to local data. | 100% | Decision |
| NFR-DATA-01 | A write is atomic: a failed command leaves no partial state. | Verified by transaction tests | Decision |
| NFR-DATA-02 | No silent data loss on crash, kill or restart. | Crash/recovery tests | Decision |
| NFR-PERF-01 | Cold start to interactive Today view. | Target e.g. under 2 s on mid-range Android and a typical Windows laptop | Assumption (benchmark needed) |
| NFR-PERF-02 | Open a list of 10,000 tasks without jank. | Target e.g. 60 fps scrolling | Assumption (benchmark needed) |
| NFR-PERF-03 | Occurrence generation for a month window. | Target e.g. under 50 ms for 200 rules | Assumption (benchmark needed) |
| NFR-PERF-04 | Focus timer accuracy. | Within 1 s of true elapsed after recovery | Decision |
| NFR-SEC-01 | Data at rest protected as decided in the security batch; no secrets in the repository. | | Proposal |
| NFR-PRIV-01 | In the MVP, the only cloud calls are authentication (and, if OQ-S5 is decided yes, optional backup). No telemetry and no user content (tasks, habits, goals, events, measurements) leaves the device otherwise. | | Decision |
| NFR-UX-01 | Layout adapts to window size on Windows and Android. | | Decision |
| NFR-UX-02 | Business logic lives outside widgets. | Architecture check | Decision |
| NFR-MNT-01 | Domain layer has no dependency on Flutter or on a database package. | Architecture check | Decision |
| NFR-MNT-02 | Each phase has a Definition of Done with automated checks. | | Decision |
| NFR-I18N-01 | UI strings use resource files (ARB), not literals. Languages: English first; others later. | | Proposal |
| NFR-ACC-01 | Accessibility basics (semantics labels, contrast, keyboard navigation on Windows). Full WCAG validation needs manual testing with assistive technologies. | | Proposal |

## 3. Assumptions

| ID | Assumption | Risk if wrong |
|---|---|---|
| AS-01 | Initial users are one person plus a few acquaintances. | Public release earlier than planned would require hardening sooner. |
| AS-02 | Legacy test suite passes (not verified). | Ported tests may need repair. |
| AS-03 | A device may hold several LocalProfiles (ADR-0008); only one is active at a time. Simultaneous multi-profile use is not designed. | Parallel multi-account use would be a larger change. |
| AS-06 | Sign-in in the MVP means identity only; no user content sync is expected by users at this stage. | If users expect sync from signing in, UX copy and onboarding must set that expectation explicitly. |
| AS-07 | A device holds at most a small number of LocalProfiles at once (guest plus a few accounts); no profile list performance concern at MVP scale. | Revisit if heavy multi-account switching becomes a real usage pattern. |
| AS-04 | Windows and Android plugins for notifications and file access are adequate. | Spike S-05 may force native code. |
| AS-05 | Performance targets above are reasonable. | Benchmarks in estimation batch. |

## 4. Open questions

| ID | Question | Where decided |
|---|---|---|
| OQ-S1..S4 | Resolved by owner 2026-11-04, see [product-scope.md](product-scope.md) section 6 | Done |
| OQ-R1 | Maximum Subtask depth? | Domain batch |
| OQ-R2 | Which timezone model for date-only vs instant (floating dates, zone-pinned events)? | Domain batch ADR |
| OQ-R3 | Default policy when completing a parent with open Subtasks? | Domain batch |
| OQ-R4 | Which encryption-at-rest approach on Windows and Android? | Security batch, spike S-01/S-02 |
| OQ-S7 | Sign-out behavior (profile chooser, which profile stays active) | Owner, before P01 exit |
| OQ-S8 | Merge rule when a profile binds to an account that already has cloud data (P04) | Sync batch |

## 5. Traceability matrix

| Requirement group | Use cases | Scope document section |
|---|---|---|
| FR-TASK | UC-01 | product-scope §3 Task management |
| FR-PLAN | UC-06, UC-08 | §3 Scheduling |
| FR-CAL | UC-08 | §3 Calendar and Event |
| FR-EXEC / FR-FOCUS | UC-17 | §3 Execution and Focus |
| FR-HAB | UC-02, UC-03 | §3 Measurable Habit |
| FR-GOAL | UC-21 | §3 Goals and Projects |
| FR-AUTH | UC-22 | §3 Identity and Sign-in |
| FR-DATA | UC-20a | §3 Data |

## 6. Self-check

- [x] Every MVP requirement has a priority and a label.
- [x] Every NFR with a number is marked Assumption until benchmarked.
- [x] Post-MVP requirements are not detailed here to avoid speculative design.
