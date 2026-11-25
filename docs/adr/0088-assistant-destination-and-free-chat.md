# ADR-0088: An Assistant destination and a free chat (P06 D1 changed)
- Status: Accepted (the owner, 2026-11-04)
- Date: 2026-11-04
- Deciders: the owner, after using the app ([p06b-plan.md](../roadmap/p06b-plan.md) §1 and §4)
- Supersedes: part 1 of [ADR-0087](0087-assistant-ui.md) ("the assistant is not a new tab") and the "no free chat" part of P06 D1 ([p06-plan.md](../roadmap/p06-plan.md))
- Related: [ADR-0016](0016-data-classification-and-egress-policy.md), [ADR-0082](0082-ai-history-and-approved-changes.md), [ADR-0086](0086-assistant-orchestrator.md)
## Context
P06 D1 limited the assistant to three uses (plan the day, fix a conflict, ask about a document) and gave it no screen of its own. The entry points were buttons on the Calendar, a document and a PDF, plus Settings → Assistant. Using the app, the owner could not find the assistant, and asked for a place to talk to it.
## Decision
1. **Navigation.** The assistant gets an **Assistant** destination in the drawer and the rail. The Calendar, document and PDF buttons stay.
2. **Free chat.** The Assistant screen has a chat with several turns.
   - It reads **all spaces of the profile** (the owner's Q2): search hits for the question (documents, tasks, PDF pages), bounded per kind.
   - It **may propose changes** with the existing proposal tools (the owner's Q1). Every change is a proposal approved by the person (D8); nothing changes by itself (LF-INV-AI-001); a stale proposal is refused (LF-INV-AI-002).
   - Routing, egress and consent are unchanged (D2, D6, ADR-0086): each item keeps its classification; Restricted never goes to a cloud model; Confidential needs the cloud option and the consent sheet; the assistant declines rather than lower privacy.
   - The chat history syncs like the rest of the history (D7).
3. The implementation details (purpose, multi-turn messages, context budget) are recorded with W4 of the P06b plan.
## Consequences
- A new AI purpose and egress row; the context builder searches across spaces; the message builder carries earlier turns.
- The device check (P06 T8) and the exit gate (T9) cover the new screen.
- The shell gets one more destination, so the drawer and rail indexes shift.
