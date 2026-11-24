# ADR-0082: The assistant's history as records, and approved changes through the gateway

- Status: Accepted (P06 task T3, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p06-plan.md](../roadmap/p06-plan.md) (the owner's D7: the history syncs; D8: each change approved on its own, with "Approve all")
- Related: [ADR-0080](0080-ai-egress-and-approvals.md) (version-bound approvals), [ADR-0012](0012-ai-proposal-approval-binding.md), [ADR-0011](0011-command-gateway-single-mutation-path.md), [ADR-0014](0014-transactional-outbox-and-atomic-side-effects.md), [ADR-0059](0059-sync-egress-classification.md), [ai-action-governance.md](../governance/ai-action-governance.md), [audit-and-provenance.md](../governance/audit-and-provenance.md) §4

## Context
The assistant suggests changes; the person decides (LF-INV-AI-001). An approval holds only for the exact arguments and the versions the change was computed against (LF-INV-AI-002, GS-15). The owner chose (D7) that the assistant's history syncs, because people read it again. An applied AI change must say where it came from (LF-INV-AI-003).

## Decision
1. **Three record kinds** (schema v18, `recordSchemaVersion` 18):
   - `aiSession`: title, purpose (plan the day, fix a conflict, ask about a document);
   - `aiMessage`: the session, the role (person or assistant), the text, the model and site of an assistant's message, the items sent with the question (`sentRefs`, kind, id and version);
   - `aiProposal`: the session, the message, the model, the site, a note, and its changes as JSON, each with its status (proposed, applied, stale, failed, dismissed), who approved it and when, the reason, and the operation that applied it.
   
   They are in the record registry, so they sync sealed, are exported and restored, and go to the trash like other records. All three are **Confidential**, like notes. Syncing them is not egress to a model.
2. **The personal space only.** The handlers refuse any other workspace and any actor other than the person (`owner`). The service writes in the personal workspace even while a shared space is shown. They are not shared-space kinds and cannot be moved into a space. Proposals therefore change only personal records for now.
3. **Handlers** (through the gateway; FF-ARCH-06 covers each):
   - `AiSessionHandler`: create, rename, trash and restore (the session's messages and proposals go and come back with it), add a message, add a proposal (every change proposed, 1 to 50, unique ids).
   - `AiProposalHandler`: records a change that did not run: dismissed, stale or failed. It never writes "applied".
   - `AiApprovedChangeHandler`: wraps the target's own handler. In the gateway's transaction it reads again every version the approval holds, runs the target's command, and marks the change applied with the operation id. The change and the mark are one commit, or neither is written. A version that moved fails with `aiStaleReason`.
4. **Approving one change** (`DriftAiHistoryService.approve`):
   1. the domain makes the approval (this person, the canonical arguments, the versions; ADR-0080);
   2. the **tool catalog** says which command it is: its handler, its target kind, its op (set by the app, never by the model), the arguments it takes, and a check of their values. An unknown command, an extra argument (for example `op`), a missing target version or a bad value fails, and nothing is tidied: what runs is exactly what was approved. T3 has two tools (`RenameTask`, `SetTaskNotes`); T6 brings the full list;
   3. the versions are read; any change or a thing gone makes it **stale**;
   4. the command runs through the gateway **as the person**, with the target's version expected and the provenance on the command;
   5. a version conflict or the in-transaction check gives stale; a refusal, or a handler that breaks, gives failed with the reason. Each is recorded on the proposal.
   
   "Approve all" approves each proposed change in order (D8). A later change computed against a version an earlier one moved is stale. A change that is not proposed any more keeps its status.
5. **The actor** is the person who approved. The actor kind `aiAssistant` is refused by authorization for every command, so the assistant cannot run anything itself (LF-INV-AI-001). This differs from the earlier sketch in audit-and-provenance.md §4, which named `aiAssistant` as the actor; that section is updated.
6. **Provenance** (LF-INV-AI-003). `Command.aiProvenance` is written by the gateway into the new nullable column `audit_log.ai_provenance`: the proposal, change and session, the model and site, who approved and when, the canonical arguments, the versions, and the consented items. Other changes leave it empty.
7. **Sync merge.** A message is append-only. A proposal merges field by field, and its `changes` merge change by change: the further status wins (applied over failed, stale, dismissed and proposed), so an applied change is never shown as open again. The changes themselves never change.
8. **Files.** An export or undo copy is checked as the commands would check it (`aiRowsError`): known purposes, roles and sites, readable sent items and changes, messages and proposals of a known session. An older file gets empty AI tables. The same fill now covers every record table added after a file's schema (member cards v15, documents v16).

## Consequences
- An AI change is the person's own command with a record of where it came from. No second write path exists: FF-ARCH-06 guard 2 now also allows exactly one wrapped `apply`, in this handler.
- A change approved on two devices at once runs on one at most for the same target version. The other sees a version conflict and records stale; after sync, applied wins.
- If a stale or failed mark cannot be written (the proposal changed meanwhile), the outcome is reported as the proposal now says. Nothing runs twice.
- A proposal on a record of a shared space is not possible until the assistant is allowed there (a later decision).
- The digest of the whole context sent to the model comes with the orchestrator (T6). Until then the message's `sentRefs` record what was sent.

## Verification
- `infrastructure/test/ai_history_test.dart` (18 tests):
  - the history read back; bad input refused; "applied" cannot be recorded directly;
  - the personal space only, while a shared space is shown, and against an owner of the space;
  - Confidential; the trash takes the history with it and gives it back;
  - an approved change runs as the person, with its provenance; approving or dismissing again changes nothing;
  - GS-15: stale, nothing written, then regenerated it applies; a trashed target is stale;
  - the versions read again in the transaction; the target or another thing changed between the check and the run;
  - D8: each, all, dismiss; tools: unknown command, extra arguments, no version, bad values, a handler that refuses or breaks;
  - the assistant as actor refused for every handler;
  - export: in the file, tampered rows refused, a v17 file reads;
  - sync: sealed (no plain text on the server), to another device, applied wins over dismissed, a trashed session goes there too.
- `domain/test/ai_test.dart` (+3): the stored changes round trip; the merge rank; the proposal and message merges.
- FF-ARCH-06: the three handlers and an approved change in the atomic-set table.
- Upgrade tests v1…v17 → v18 (the profile harness rewinds v18).
- Mutations: 26, run one at a time. 24 killed at once. Two survived and got tests:
  - the personal-space check, reached only by an owner of the space;
  - the stale reason from the in-transaction check, reached only by a change between the check and the run.
  
  All 26 killed after that.
