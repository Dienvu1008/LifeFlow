# Domain: Workspace and Access

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Classification: Supporting. Phase: P01 minimal, P04 full. In MVP: yes (minimal).
- Related: [ADR-0008](../adr/0008-guest-first-with-optional-account-binding.md), [../governance/authorization-model.md](../governance/authorization-model.md), [../architecture/domain-model.md](../architecture/domain-model.md)

## 1. Purpose
Decide who owns and may touch data, and provide the guest-first profile and optional account binding from ADR-0008. In the MVP this is a single local owner per profile; the full membership and sharing model is P04.

## 2. Aggregate roots and boundaries
- **`LocalProfile`** (root): the local identity and its optional account binding. One per data space on the device. Boundary: profile metadata and its single `AccountBinding`.
- **`Workspace`** (root): the container every resource belongs to. In MVP exactly one Personal Workspace per profile. Boundary: workspace metadata and (P04) its `Membership` set.

## 3. Entities and value objects
- `LocalProfile`: `profileId: EntityId`, `displayName`, `createdAt: Instant`, `activeWorkspaceId: WorkspaceId`.
- `AccountBinding` (child of LocalProfile): `accountId` (opaque, from the auth provider), `provider`, `boundAt: Instant`. At most one per profile.
- `Workspace`: `workspaceId: WorkspaceId`, `kind {personal, shared(P04)}`, `ownerId: OwnerId`.
- `Membership` (P04 only): `actorRef`, `role`.

## 4. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-ID-001 | Binding an account never changes any entity ID or workspace ID | `BindAccount` command |
| LF-INV-ID-002 | Data of one LocalProfile is not visible to another | storage isolation + every query scoped by `workspaceId` |
| LF-INV-SEC-002 | An auth failure or offline state never blocks access to the active profile's local data | `AuthGateway` is called only for sign-in/refresh, never on the read path |
| LF-INV-WA-001 | A profile has exactly one active Workspace in MVP | profile invariant |

## 5. Domain services
- `ProfileBinder`: applies the bind-or-new-profile rule from ADR-0008 (if the current profile has data, require an explicit choice; else bind directly).

## 6. Commands
| Command | Actor | Args | Preconditions | Result | Events | Idempotency | Concurrency |
|---|---|---|---|---|---|---|---|
| `CreateLocalProfile` | system (first launch) | displayName? | no active profile | profile + personal workspace | `ProfileCreated` | by `operationId`; re-run returns the existing first profile | n/a (new) |
| `BindAccount` | local owner | accountId, provider, moveData: bool | signed-in via AuthGateway | binding or a new profile | `ProfileBoundToAccount` (+ `ProfileCreated` if moveData=false) | by `operationId` | `expectedVersion` on the profile |
| `SignOut` | local owner | — | bound profile | session cleared | `SignedOut` | idempotent | — |
| `SwitchProfile` | local owner | profileId | profile exists on device | active profile changed | — | idempotent | — |

[Decision, owner 2026-11-04] OQ-S7 resolved: on `SignOut`, the app returns to a **profile chooser**; all profiles and their data **stay on the device** (nothing is deleted); each profile is bound to **at most one account**; a different account may sign in on a new profile. This is a Decision for the MVP. The P04 refinements (what sign-out means once content is synced to a backend) remain a Proposal pending P04.

## 7. Queries / read ports
- `AuthorizationService.check(actor, action, resourceRef) → Allow | Deny(reason)` — the only authority port other contexts and the Governance Kernel use. MVP policy: allow if `actor` is the owner of `resourceRef.workspaceId`; deny otherwise. See [authorization-model.md](../governance/authorization-model.md).
- `ActiveWorkspace() → WorkspaceId`.

## 8. Domain events
`ProfileCreated`, `ProfileBoundToAccount`, `SignedOut` (catalog in domain-model.md section 5).

## 9. Repository contract
```
ProfileRepository:
  getActiveProfile(): LocalProfile?
  listProfiles(): List<LocalProfile>
  save(LocalProfile): void        // through a command handler only
WorkspaceRepository:
  getPersonalWorkspace(profileId): Workspace
```
No method exposes another profile's workspace to a query that is not scoped by it.

## 10. Open questions
- OQ-S7: **resolved** (see the Decision above the commands table).
- OQ-S8 (P04): binding to an account that already has cloud data.
- OQ-WA-1: is the auth provider's `accountId` stored in plain local storage or secure storage? Proposal: secure storage for tokens, plain storage for the non-secret `accountId`. Security batch confirms.

## 11. Self-check
- [x] Every command lists events, idempotency and concurrency.
- [x] Every invariant has an enforcement point.
- [x] No query returns cross-profile data unscoped.
