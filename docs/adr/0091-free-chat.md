# ADR-0091: The free chat: what it reads, what it may propose, how it is routed
- Status: Accepted (P06b W4, 2026-11-04)
- Date: 2026-11-04
- Deciders: the owner ([ADR-0088](0088-assistant-destination-and-free-chat.md); [p06b-plan.md](../roadmap/p06b-plan.md) Q1, Q2); implementation
- Related: [ADR-0016](0016-data-classification-and-egress-policy.md) (egress), [ADR-0082](0082-ai-history-and-approved-changes.md) (history and approvals), [ADR-0086](0086-assistant-orchestrator.md) (routing, the code decides), [ADR-0087](0087-assistant-ui.md)
## Context
ADR-0088 gave the assistant a destination and a free chat that reads all spaces and may propose changes. The engine port has no multi-turn or tool-calling API: an engine takes one checked request (instructions, the person's words, tagged data) and answers with text or with JSON for a schema. Approvals run in the personal space as the person (ADR-0082). The app's search wants every typed word, which a whole question rarely matches.
## Decision
1. **One turn = one checked request** (`AiAssistant.chat`, `AiPurpose.chat`). It is answered with JSON for `chatSchema`: a `reply` and a list of `changes`. Every field is required, with "" or 0 when not used, so strict JSON modes of cloud providers accept it. There is no streaming for the chat yet: the reply comes at once.
2. **What it reads:**
   - **The earlier turns** of the chat: the last 12 messages, at most 6,000 characters, as one item `aichat:<session>`. They are data, never instructions, and pass the egress checkpoint like any item. They are Confidential (the chat history). They are Restricted when an earlier answer was made from a Restricted item, or from a measurement or unknown kind that is gone (its class can no longer be told).
   - **The shown space's next 7 days**: up to 15 open tasks and events, each with "on <date> at <time>".
   - **Search hits for the message in every space of the profile** (the owner's Q2): the shown space first; spaces the person left are not searched; at most 8 of each kind (documents, tasks, PDF pages) in all. The message is searched by **any** of its words, with common Vietnamese and English words and punctuation left out (`searchAnyQueryOf`). A hit from a shared space is titled "<space> · <title>", so the consent sheet says where it comes from.
   - The instructions give today's date, weekday and time; the reply is in the language of the message (D9).
3. **Routing:**
   - As every turn (`chooseAiRoute`): the person's preferred engine first; decline rather than lower privacy (OQ-AI-2).
   - The earlier turns are what a chat is about: an engine that may not receive them is passed over (so Restricted turns go to the device or nowhere).
   - A Restricted search hit is only left out.
   - **With the cloud option off, the cloud engine is not tried at all**: the message itself is the person's private words.
   - Confidential items need consent per request (D6), as for the other turns.
4. **What it may propose** (the owner's Q1), built and checked by the code; the model never names a command:
   - **create** a task in the personal space (`CreateTask`, a new tool: id from the app, title only, at the end of the tasks without a list). With a date and a start it also proposes the new task's slot; that slot expects the task's first version, so it runs after the create (or is stale).
   - **rename** or **schedule** (one slot within one day, as the day plan) a task that was sent, that is in the personal space ("changeable" in its text), with its version.
   - **One change per task** in a proposal: each change is bound to its task's version, so a second one would be stale once the first runs.
   - At most 10 changes. Anything else (ids not sent, a shared space's task, a bad date or time, a slot past midnight, other actions) is dropped.
   - Every change is approved by the person, each or all (D8, LF-INV-AI-001), stale when its task changed (LF-INV-AI-002). An approved change carries its AI provenance in the audit log.
5. **Not in this step:** events are read but not created or moved (they are, since [ADR-0093](0093-chat-events.md)); a shared space's tasks are read but not changed (an approval runs in the personal space).
6. **The screen:**
   - The destination shows the chat.
   - Before a first message it shows what the assistant can do, the shortcuts "Plan my day" and "Fix conflicts" (they open the day page and start at once), and the history.
   - Each answer shows its engine and model, and its proposal under it.
   - "New chat" starts again; a chat from the history opens and goes on.
   - When a message is not kept (consent cancelled, declined, failed), its words go back into the field.
7. **The order of messages.** A session's messages are read by time, then by the order they were written on this device (rowid), then by id. Times are kept to the second and a UUID v7 is random within a millisecond, so a question and its answer written together could come back swapped. This was the infrastructure test that failed about one CI run in three.
## Consequences
- Older app versions on other devices do not list chat sessions (they skip an unknown purpose) until they are updated; nothing is lost.
- Each cloud turn with private items asks for consent again (D6 is per request). If this proves tiring, a "for this chat" consent is a later decision for the owner.
- A local 2B model may answer slowly without streaming; streaming the reply before the changes is a possible later step.
