# ADR-0086: The assistant's turns, routing, and the day plan decided by code

- Status: Accepted (P06 task T6, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p06-plan.md](../roadmap/p06-plan.md) (the owner's D1, D6, D8, D9; spike S-17)
- Related: [ADR-0080](0080-ai-egress-and-approvals.md), [ADR-0081](0081-ai-context-and-egress-checkpoint.md), [ADR-0082](0082-ai-history-and-approved-changes.md), [ADR-0083](0083-local-model-engine.md), [ADR-0085](0085-cloud-model-engine.md), [ai-architecture.md](../architecture/ai-architecture.md) §2, §4, §5, [ai-action-governance.md](../governance/ai-action-governance.md) (the determinism boundary)

## Context
T1–T5 gave the parts: the egress rule, the context and its checkpoint, version-bound approvals and the history, and the local and cloud engines. T6 joins them into the turns of D1:
- "plan my day" and "fix a conflict", which propose changes;
- "ask about this document or PDF", which only answers.

S-17 showed every small model overlapping times, so the times must not come from the model.

## Decision
1. **The port** (application, `ai_assistant.dart`): `AiAssistant` with `planDay`, `fixConflicts`, `askDocument` (streamed through `onText`) and `stop`.
   - Each turn returns an `AiTurnResult`: proposed, answered, needs consent, declined, nothing to do, or failed. It carries every item's egress line, which the consent sheet (T7) shows.
   - `AiAssistantSettings` holds the preferred engine, the cloud option (off by default), the hours of a plan (08:00–18:00 by default) and the language of the app's own words. They are stored as one JSON value.
2. **Routing** (`chooseAiRoute`, pure; ai-architecture §4). The engines are tried in the person's order of preference; one that is not set up is skipped.
   - An engine that **may not receive** an item the request is about (Restricted toward the cloud, or anything with the cloud off) is passed over for the next.
   - An engine that only needs the person's **consent** for those items stops there and asks. It is not swapped for another silently.
   - "Send without these" leaves the waiting items out; a request with nothing left of what it is about is not sent.
   - With no engine left, the request is **declined** (OQ-AI-2 decided): privacy is never lowered to get an answer.
   - **FF-ARCH-08 guard 4**: in shipped code only the router calls the checkpoint, so every request of the assistant takes this route.
3. **The day plan is decided by code** (domain, `fitDayPlan`, pure). The model gives a small JSON per task id: an order, a start and a length. S-17 showed that a long plan was slow and broke.
   - A task keeps the model's start when it fits there. Otherwise it goes to the first free time after that start, or else the first free time of the day.
   - It never goes over a fixed event, a timed task or another task of the plan, outside the hours, before now (today), or off a 5-minute grid.
   - An invented length is replaced by 30 minutes. A task with no room is left out and named in the note. An id the model invents, or a task named twice, is ignored.
   - A property test over 2 000 random plans checks all of this.
4. **The turns** (infrastructure, `DriftAiAssistant`), in the personal space only (D7). Everything fixed comes **from the store, never from the model**:
   - **plan my day**: up to 15 open tasks with no time yet (no schedule, or planned for that day without a time; important ones first). They are placed around the day's events (cancelled ones do not count) and timed tasks (done ones do not count).
   - **fix conflicts**: the timed one-off tasks of that day that overlap something are placed again. Repeating tasks are not moved.
   - **The context** holds only those items, through the context builder. Each item is marked "to place" or "fixed HH:MM-HH:MM" and stays tagged as untrusted data.
   - **Only the tasks that were sent** may be placed.
   - The app builds each change itself: `SetTaskSchedule` with a one-off slot in the device's zone, the version the task had in the context, and a summary in the person's language noting when the code moved it.
   - **ask**: the document or the PDF (or one page) and its question. The answer is streamed and kept; nothing changes.
   - Each turn is kept in the history (ADR-0082): the question, the answer or plan note with the model, the engine and what was sent, and the proposal. A turn the engine failed keeps nothing; an answer cut off keeps what came.
   - Changes run only when the person approves each one (D8, LF-INV-AI-001). A task changed meanwhile makes the change stale (GS-15).
5. **The tool `SetTaskSchedule`** joins the catalog (`AiToolCatalog.standard`). The assistant may only give a task **a one-off slot within one day**: a start and an end, a valid time and zone, no repeat, no deadline. The payload must be exactly the one the app would make for that slot, checked by canonical comparison. A tampered one fails at approval, before any command.
6. **GS-31** is added (golden-scenarios.md): injected text in a task's notes and in a document produces no change without approval, and no egress beyond the rules.

## Consequences
- The assistant can plan a day, fix a day's conflicts and answer about documents, on either engine, with the person deciding each change. Models only order and suggest; the times are always sound.
- A plan only sets times on that day. It does not create tasks, change events, or move a repeating task's occurrence; those are later tools if wanted.
- Task lengths are not stored in LifeFlow, so the model's guess (or 30 minutes) is used and the person sees it before approving.
- The hours are one setting, not a calendar of working days.
- The UI (T7) shows the results: the consent sheet from the egress lines, the proposal with "approve each or all", stale changes, and the history.

## Verification
- `domain/test/ai_day_plan_test.dart` (7 tests): kept, moved, the first free time, left out, ignored, lengths, the grid, now, `HH:MM`, and a property test over 2 000 random plans (no overlap, within the hours, after now, only the tasks asked about, each once, every wish accounted for).
- `infrastructure/test/ai_assistant_test.dart` (18 tests, tagged `ff-arch-08`):
  - a plan around events and a timed task with the model's overlaps corrected; approved, it shows in the agenda without conflict;
  - the context of a plan; done tasks and cancelled events take no time;
  - invented ids and extra fields; today not before now; nothing to plan; a stale approval;
  - **GS-31**: the model obeys an injected instruction, and nothing changes but the history. Only the tool is proposed, the text goes as tagged data, and the cloud gets nothing;
  - routing: cloud off, consent asked then given, "send without these", nothing set up, and Restricted to the local engine or declined;
  - conflicts fixed with a repeating task left alone; ask about a document (streamed, kept, a cut answer);
  - the personal space only; an engine failure; tampered schedules refused by the tool; the settings.
- FF-ARCH-08: guard 4, and at least 25 tagged tests (28 run).
- Mutations: 25, run one at a time. 21 were killed at once. Four survived:
  - two got tests: done tasks and cancelled events taking time;
  - one was a check made twice: the key-set check before the canonical comparison, now removed;
  - one was a check the handler also makes: the tool's time validation. The test now requires the tool's own reason, so a bad slot is refused before any command.
  
  All killed after that.
