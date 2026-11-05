# Authorization Model

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Related: [governance-kernel.md](governance-kernel.md), [../domains/workspace-and-access.md](../domains/workspace-and-access.md), [ADR-0003](../adr/0003-backend-decision-deferred-to-spike.md)

## 1. Actors
| Actor | Trust | Can hold authority? |
|---|---|---|
| Local owner | Trusted for own workspace | Yes — the only authority in MVP |
| AI assistant | **Untrusted by default** | No — proposes only; actions run as the owner after approval, through the gateway |
| External provider (health, dictionary, calendar) | Data source only | No — supplies data, never decides domain state |
| Sync | Transport only (P04) | No — moves and reconciles changes; does not decide business semantics |

[Decision] AI, providers and sync never have independent authority. When AI acts, the executed command's `actor` is the approving owner, with the AI recorded in provenance (see audit-and-provenance.md).

## 2. Resource reference
`ResourceRef { workspaceId, entityType, entityId }`. Authorization is always evaluated against a resource ref and an action.

## 3. Actions and authority (answers the brief's authority questions)
| Authority question | MVP answer | P04 answer |
|---|---|---|
| Who may create a resource | The owner, in their own workspace | A member with a create-permitting role |
| Who may edit a resource | The owner | Owner or a member with edit permission |
| Who may share | n/a (no sharing in MVP) | Owner, per sharing policy |
| Who may change a schedule | The owner | Owner or permitted member |
| Who may mark completed | The owner | Owner or assignee |
| Who may change a health measurement | The owner (manual); health provider supplies evidence, never a completion | Same; providers never gain authority |
| Who may use cloud AI | The owner, subject to data-classification policy on what context may leave the device | Same, plus workspace policy |
| Who may read a shared resource | n/a in MVP | Members with read permission (RLS-enforced) |

## 4. MVP policy
[Decision] Single-owner policy: `AuthorizationService.check(actor, action, ref)` returns Allow if `actor` is the owner of `ref.workspaceId` and the resource is in the active profile's workspace; Deny otherwise. Profile isolation (LF-INV-ID-002) means a command for another profile's workspace is denied.

The policy engine hook exists in the pipeline but is trivial in MVP (owner-allow). This is the seam where P04 policies and AI limits attach without changing the pipeline.

## 5. P04 extension (designed, not built)
- `Membership { actorRef, role }` per shared workspace; roles map to permission sets.
- Sharing grants make a specific resource visible to a workspace; a personal resource never becomes shared implicitly (principle P3).
- Server-side enforcement via Supabase RLS (if ADR-0003 resolves to Supabase): every table policy mirrors the application authorization, so a client cannot read another tenant's rows even if it bypasses the app (VS-06, VS-07). The application check and the RLS policy must agree; the data batch defines the membership tables and the RLS test suite (VS-08).

## 6. AI and cloud-AI data boundary
[Decision] Using cloud AI is itself an authorized, classified action: the Context Builder may include only data the owner is allowed to see and that is not classified as restricted-from-cloud (data classification is the data batch). This is checked before any context leaves the device. Detailed in [ai-action-governance.md](ai-action-governance.md).

## 7. Invariants
- LF-INV-GOV-002 (authorize before domain), LF-INV-ID-002 (profile isolation), LF-INV-AI-001 (AI cannot bypass authorization).

## 8. Open questions
- OQ-AUTHZ-1: exact role set and permission matrix for P04. Deferred to the collaboration/data batch.
- OQ-AUTHZ-2: how AI usage limits (rate, cost, data classes) are expressed as policy. AI/estimation batches.

## 9. Self-check
- [x] Every authority question in the brief has an MVP and a P04 answer.
- [x] AI, providers and sync are explicitly non-authorities.
- [x] The MVP policy is a seam, not a special case bypassing the pipeline.
