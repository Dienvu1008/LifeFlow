# Product Scope and MVP Boundary

- Status: MVP boundary confirmed by owner on 2026-11-04 (open questions OQ-S1 to OQ-S4 resolved, see section 6)
- Date: 2026-11-04
- Related: [product-vision.md](product-vision.md), [requirements.md](requirements.md), [personas-and-use-cases.md](personas-and-use-cases.md), [../adr/0005-mvp-scope-personal-first.md](../adr/0005-mvp-scope-personal-first.md)

## 1. Decision summary

[Decision, per user] The MVP is **narrow and personal-first**.

**MVP = Task, Schedule and Recurrence, Calendar and Event, Focus, basic Measurable Habit, on Windows and Android, fully offline.** Everything else is deferred but has a defined extension point, so deferral does not force a redesign.

[Decision, owner 2026-11-04] The owner confirmed this boundary and added two items: **Goals, Projects and Milestones are in the MVP (P03)**, and **account sign-in must exist in the MVP** (OQ-S2, OQ-S4). The owner then clarified that sign-in is for **authentication only** (OQ-S5) and that the app **can be used before signing in** (OQ-S6). Sign-in is therefore available but optional. See [ADR-0008](../adr/0008-guest-first-with-optional-account-binding.md).

[Proposal] MVP corresponds to roadmap phases **P01 to P03** (detailed in the roadmap batch). Collaboration and Sync (P04) is the first post-MVP phase.

## 2. Why this boundary

| Reason | Effect |
|---|---|
| Solo developer plus coding agent | Each added context multiplies tests, invariants and review effort. A narrow MVP keeps the critical path short. |
| Sync is the highest-risk capability | Shared workspaces, RLS and conflict handling are deferred until a stable single-user domain exists. The domain is still designed with stable IDs, versions and tombstones so sync can be added without schema redesign (see Extension points). |
| Legacy code already covers this core | Per the [assessment](../assessment/legacy-repo-assessment.md), pure-Dart logic for recurrence, DST and progress can be ported with tests, shortening MVP work. |
| Principle P1 | Core stays small; other domains attach through contracts. |

## 3. In scope (MVP)

| Capability | Included | Not included (explicitly) |
|---|---|---|
| Task management | Task, Subtask (hierarchy with cycle protection), lists, status, priority, tags, Inbox/Today/Upcoming/Completed/Archive/Trash views, templates deferred | Assignment, comments, dependencies, Kanban/Timeline views, shared tasks |
| Scheduling | Schedule semantics (date-only vs datetime, start/end/deadline variants, all-day, timezone, duration, reminders); one schedule and one recurrence per Task/Event with derived occurrences (ADR-0007); exceptions | Multiple schedules on one Task/Event (use two Tasks instead, ADR-0007), AI schedule proposals |
| Calendar and Event | Event as its own concept; calendar views; event recurrence; deterministic conflict detection; local notifications | Attendees/invitations, shared calendars, Google/Outlook sync |
| Execution and Focus | Execution records, actual start/end, Pomodoro/stopwatch, persisted focus session with crash recovery, planned vs actual | Advanced analytics, productivity scoring |
| Measurable Habit | Targets (at least, at most, about with min/max), manual measurement entries, per-day/week/cycle aggregation, completion policy (manual or automatic from manual entries) | Automatic data from Health, hybrid completion from external evidence |
| Platform | Windows and Android, adaptive layout, offline | iOS, macOS, Linux, Web |
| Data | Local database, migrations, local export (JSON), local backup/restore | Cloud sync of user content, cloud account data deletion (identity-only deletion is in scope, see UC-20b) |
| Goals and Projects | Goal, Project, Milestone; progress derived from linked Tasks and Habits by reference (a Goal is not a Task); archive and trash | Shared goals, dependencies between projects |
| Identity | Guest-first local profile with a Personal Workspace from first launch; optional account sign-in (email and at least one social provider, provider decided in the ADR-0003 spike); binding the current data to the account or starting a new profile; sessions that survive offline use; sign-out | Multi-user workspaces, roles, invitations (P04); any cloud storage of user content |

[Decision] Habit is a Task capability (recurrence plus measurable target), see [ADR-0006](../adr/0006-habit-is-a-task-capability.md). Goals and Projects are in P03, after Execution and Measurement exists, because goal progress is derived from Tasks and Habits.

[Decision] In the MVP the account is used for **authentication only** (OQ-S5). User content is not synced and nothing is backed up to the cloud; content sync, sharing and server-side storage remain P04.

[Decision] When a user who already has data signs in, the app asks whether to move the current data to that account. If the user declines, a new profile ("new session") is created and the previous profile stays on the device. See ADR-0008.

## 4. Deferred (post-MVP), with extension points

| Capability | Target phase (hypothesis) | Extension point built into MVP |
|---|---|---|
| Collaboration, Shared Workspace, permissions, audit | P04 | Every resource carries `workspaceId` and `ownerId`; all mutations go through an application command layer; stable UUIDs; per-entity version; tombstones instead of hard delete |
| Sync (cloud) | P04 | Operation log/outbox table shape and idempotency keys defined in the data batch; commands carry `operationId` |
| Documents and Knowledge | P05 | Contract: `LinkedResource` references (type, id) usable from Task/Event; no schema dependency on a document model |
| AI Platform | P06 | Command layer is the only mutation path (AI will call commands); `Proposal` and `Approval` contracts documented in governance batch |
| Dictionary, Translation, Vocabulary | P07 | Language primitives separated; Task creation contract usable by a future review scheduler |
| Health and Activity (steps first) | P08 | `MeasurementEntry` has `source` and `provenance` fields from the start; completion policy can accept evidence from a port |
| Learning Studio, automation | P09 | Task creation contract used by learning |
| iOS/HealthKit, CRDT, calendar integrations, advanced analytics | P10 | None; `[Open]` to validate need first |

## 5. Non-goals (not planned at any phase unless evidence changes)

- Custom smartwatch/vendor adapters (platform health providers only).
- A proprietary fitness algorithm.
- Microservices.
- Web client.
- Scraping websites for dictionary data against their terms.

## 6. Open scope questions

| ID | Question | Option A | Option B | How to decide |
|---|---|---|---|---|
| ID | Question | Resolution | Status |
|---|---|---|---|
| OQ-S1 | Windows to Android data transfer without cloud in MVP? | **Defer until sync (P04).** UC-16 is not in MVP. File export/import (UC-20a) remains for backup only. | Decision |
| OQ-S2 | Are Goals/Projects part of MVP? | **Yes, in P03.** | Decision |
| OQ-S3 | Multiple schedules per Task? | **Single schedule per Task or Event; recurrence expands to derived occurrences, and per-occurrence changes are exceptions.** See [ADR-0007](../adr/0007-single-schedule-with-derived-occurrences.md). | Decision |
| OQ-S4 | Cloud login in MVP? | **Yes, sign-in must exist** (refined by OQ-S6: it is optional to use). Auth provider choice is made before the sign-in work package; see [ADR-0003](../adr/0003-backend-decision-deferred-to-spike.md). | Decision |
| OQ-S5 | What does the account do in MVP beyond identity? | **Authentication only.** No cloud backup, no content sync in MVP. | Decision |
| OQ-S6 | May the app be used before sign-in? | **Yes.** Guest-first. On sign-in with existing data the app asks whether to move the data to the account; if not, a new session (profile) is created. See [ADR-0008](../adr/0008-guest-first-with-optional-account-binding.md). | Decision |
| OQ-S7 | What happens at sign-out? Return to the guest profile? Is the account's data kept on the device? Can a different account sign in on the same profile? | Not decided. Proposal: sign-out returns to a profile chooser; profiles and their data stay on the device; one profile is bound to at most one account. | Open Question |
| OQ-S8 | In P04, what if a profile with local data is bound to an account that already has cloud data? | Deferred to the sync batch. | Open Question (P04) |

## 7. Effect on a solo developer

[Assumption, confidence low] Effort for MVP is estimated in the roadmap batch. This document only states that Collaboration, Sync, Documents, AI, Dictionary, Health and Learning are intentionally outside the critical path of the first release.
