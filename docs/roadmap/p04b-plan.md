# P04b plan: Sharing with other people

- Status: **Proposal, waiting for the owner's decisions B1–B14** (2026-11-16)
- Date: 2026-11-16
- Inputs: [p04-plan.md](p04-plan.md) (D1, D12, D14; the P04b line of the exit gate), [p04a-exit-gate.md](../testing/p04a-exit-gate.md), [authorization-model.md](../governance/authorization-model.md) (§3, §5, OQ-AUTHZ-1), [workspace-and-access.md](../domains/workspace-and-access.md) (Membership, WA-001), [data-classification.md](../data/data-classification.md) (the "shared" row of the egress matrix), [sync-protocol.md](../data/sync-protocol.md) §9, ADR-0052, ADR-0054, ADR-0057, ADR-0059; requirements FR-TASK-10, FR-CAL-05, FR-GOAL-06; persona PER-2; use cases UC-13, UC-19; invariants PRIV-002/003, ID-001/002, GOV-001/002, WA-001, GOAL-003; open questions OQ-AUTHZ-1, OQ-V5
- Estimate: about 21–29 person-days (p04-plan.md guessed 15–25 before the design; the end-to-end keys and the multi-space store add to it), plus a 30 % risk buffer.

## 1. Goal and exit gate
A few people (PER-2: family, a small team) share a space of lists, tasks, events and goals, each with a role. Personal data stays private unless the user moves an item into a shared space. P04a's properties hold for shared spaces too: local-first, end-to-end encrypted, and nothing lost in a conflict.

Exit gate:
- **A member cannot read or write a space they are not in, or write beyond their role, even with crafted requests.** Enforced by the server (RLS and the functions), with a pgTAP allow/deny suite per role (R-PERMISSION, OQ-V5).
- **Nothing personal becomes shared implicitly** (PRIV-002/003). An item enters a shared space only by an explicit action that shows what becomes visible. Restricted data never does.
- **A removed member gets nothing new**: no access on the server, and a new space key they do not have.
- **The server still sees no content** (D12). Keys reach a member only wrapped for that member.
- P04a's GS-14, GS-17 and SYNC-001…004 hold in a shared space with two people editing.

Fitness functions: FF-ARCH-06/09 for every new handler; FF-ARCH-07 for any new package; ADR-0059's classification also checks the share action.

Out of scope (proposed, B11): comments and an activity feed; email invitations; instant updates (Realtime); event attendees and replies (FR-CAL-05 part); showing shared items mixed into personal views; public links; moving part of a guest profile (D13).

## 2. Starting point (checked in code)
- A profile store has **one** workspace (WA-001); `Workspaces.kind` exists, but only `personal` is used.
- Every view reads the active workspace when it subscribes, and P04a's join made them subscribe again on a change (ADR-0058 §4).
- `WorkspaceOwnerAuthorization` allows only the owner, plus the `sync` actor for `ApplySyncChanges`. There is no membership or role table, and `ActorKind` has no member kind.
- Records carry `ownerId` (a profile id, local to one device) and `deletedBy`. There is no assignee, and nothing says who changed a record last.
- The server (`account_workspaces`, `sync_records`) belongs to one account per workspace: RLS and `push_records` check `account_id = auth.uid()`.
- Keys: one workspace key per synced workspace, wrapped by the account's recovery key or passphrase (ADR-0054).
- Export assumes every workspace in the file belongs to the profile.
- Email: Supabase's built-in sender delivers only to the project's own team members, about 2 emails an hour, unless a custom SMTP server is set up ([Supabase docs](https://supabase.com/docs/guides/auth/auth-smtp)).
- Crypto: `cryptography` 2.9.0 (already licensed, VS-42) has X25519 key agreement in pure Dart, so a key can be wrapped for one person.

## 3. Owner decisions (proposals)

| # | Question | Proposal |
|---|---|---|
| B1 | How shared things appear | **A shared space is a separate space in the drawer**, next to "Personal": you switch to "Family" to see its lists, tasks, calendar and goals, as you switch tabs today. Each view shows one space at a time. *Alternative (later): shared items mixed into your personal Overview, Timeline and Calendar*. That touches every query and every view, so it is proposed for a later phase. |
| B2 | What a shared space can hold | **Lists, tasks with their subtasks, schedules, repeats and done ticks, events and calendars, goals and milestones.** **Not in a shared space:** habits and targets with their measurements and results, focus sessions and records, and reminders. Those are personal: a reminder belongs to the person who set it, and how someone tracks themselves is theirs. A tracked task cannot be moved into a shared space until its tracking is turned off. |
| B3 | How an item gets into a shared space | **Made there**, or **"Move to space…"** on a list, task, event, calendar or goal. Moving keeps its id (ID-001), takes its subtasks and schedule with it, and **asks first**, listing what becomes visible: the title, the notes, the subtasks, the dates. Its reminders and focus history stay with you, outside the space. Moving back out is allowed for an editor; for the others it is like a delete. *Alternative: copy instead of move* (the item then exists twice). |
| B4 | Roles and what each may do (OQ-AUTHZ-1) | **Owner**: everything, plus members, roles, invitations, the space's name, and deleting the space. **Editor**: create, edit, complete, move in and out, delete to the trash, assign. **Viewer**: read only. The server refuses any write from a viewer. One owner per space; the owner can hand the role to another member. The full matrix is in §4. |
| B5 | Who can be invited | **Only people with a LifeFlow account** (signed in). To create a space or join one, your profile must have **sync turned on**, because your personal key carries the keys of your spaces to your other devices. Guests cannot join. |
| B6 | How an invitation is sent | **An invitation code** (also shown as a QR code and as a `lifeflow://join/…` link), which the owner sends by any messenger. It is for one person and one role, and it expires after 7 days. *Not proposed now: by email.* Supabase's built-in email only reaches the project's own team, so email needs an outside email service set up first (an account and DNS records; free plans exist). That can come later. |
| B7 | How the new member gets the space's key (end-to-end) | **The owner approves each new member**: the person enters the code, the owner's device shows "Lan (lan@…) wants to join as Editor", and the owner taps Approve. The owner's device then gives the space key to that person only (wrapped with their public key). Joining therefore finishes the next time the owner's app syncs. *Alternative: the code itself carries the key*, so joining is immediate, but anyone who gets the code before it is used can join. |
| B8 | Removing a member, or leaving | The person loses access on the server at once. **The owner's device then makes a new space key and seals the space again**, so a removed member cannot read anything new even with their old key. On the removed or leaving person's devices **the space disappears**, and they are offered an export first. *Alternative: they keep a read-only copy of what they had.* |
| B9 | Assignment (FR-TASK-10, part) | A task in a shared space can be **assigned to one member** (an editor or the owner). The task shows who it is assigned to, and the space has an "Assigned to me" filter. Anyone with the editor role can complete it. **No push notification**: the assignee sees it at their next sync (LifeFlow does not run in the background, D8). |
| B10 | Who did what | Each item in a shared space shows **"changed by Lan, 10:42"** (the last change) and who created it. *Comments and an activity feed: not in P04b (B11).* |
| B11 | Left out of P04b | Comments, activity feed, email invitations, instant updates (Supabase Realtime), event attendees and replies, mixed personal + shared views (B1), public links. Each can be its own later task. |
| B12 | How soon others see a change | As in P04a (D8): your change is sent about 5 seconds after you make it; the others get it when they return to the app, tap Sync now, or **within 1 minute while a shared space is open** (5 minutes for personal data). *Alternative: instant updates with Supabase Realtime* (free plan: 200 connections) as a "something changed" signal. Proposed only if 1 minute proves too slow in T14. |
| B13 | Limits | **Up to 10 members per space and 10 shared spaces per account**, which is enough for a family or a small team on the free plan (500 MB, D2). Checked on the server. |
| B14 | Export | **"Export" saves your personal data, as today.** A shared space can be exported by any member as a copy of what they can read; the file says it holds other people's data. *Alternative: only the owner can export a shared space.* |

## 4. Permission matrix (B4)
Rows are actions in a shared space; "server" means the server enforces it as well as the app.

| Action | Owner | Editor | Viewer |
|---|---|---|---|
| Read the space | yes | yes | yes |
| Create, edit, complete, move to the trash, restore | yes | yes | no (server) |
| Move an item in from personal, or back out | yes | yes | no (server) |
| Assign a task | yes | yes | no (server) |
| Invite, approve, remove members, change roles | yes (server) | no | no |
| Rename the space; delete the space for everyone | yes (server) | no | no |
| Leave the space | after handing over the owner role | yes | yes |

With end-to-end encryption the server cannot see what a write changes. It can only check that the writer is an owner or editor of the space. Finer rules (for example "only the assignee may complete") would be app rules only, so none are proposed.

## 5. Technical design (no owner input needed; ADRs during the tasks)
- **Spaces in one store.** A profile store holds its personal workspace and the shared spaces it belongs to. WA-001 becomes "one personal workspace, any number of shared ones, one active at a time". Switching spaces changes the active workspace, and the views subscribe again (the P04a mechanism). Schema v13 adds:
  - a local cache of each space's members and roles (from the server, read only);
  - the assignee and "changed by" on records of a shared space;
  - the space's name.
- **Member identity.** In a shared space a person is their account id, not a profile id (profile ids are per device). Records made in a shared space carry the account id as `ownerId`. Moving a personal item into a space rewrites only that field. The id is kept (ID-001).
- **Server (Supabase, migrations):**
  - `spaces` (owner account, name, limits);
  - `space_members` (account, role, the space key wrapped for that member, by whom, when);
  - `space_invitations` (a hash of the code, role, expiry, used by);
  - `account_keys` (each account's X25519 public key, and its private key sealed with the account's personal workspace key, so every device of that account can open it).

  RLS lets members read their spaces' records. `push_records` and `purge_records` accept owners and editors only. Membership, role, invitation and key changes go only through security-definer functions that check the owner (sync-protocol §9: server-authoritative). The personal workspace stays as P04a made it.
- **Keys** (ADR-0054 extended):
  - a space key per shared space, wrapped for each member with X25519 and AES-GCM;
  - a new key on every removal, and the owner's device seals the space again (a re-upload);
  - the record id HMAC is derived from the space key, so a rotation also means new server ids. The rotation is a full replacement of the space on the server, done as one guarded step.
- **Sync per space.** The engine runs once per synced workspace (personal and every space), each with its own cursor in `sync_state`, which is already keyed by workspace.
- **Authorization.**
  - `WorkspaceOwnerAuthorization` becomes a role policy: the owner of the personal workspace as today; in a shared space, the role from the members cache.
  - The `sync` actor may apply pulled changes in any space the device syncs, from any member. The server already checked that the writer is an owner or editor.
  - FF-ARCH-09: authorize before domain, for every new command.
- **Share egress.** "Move to space" asks ADR-0059's classification: Personal and Confidential (notes) move after the explicit confirmation; Restricted never moves (PRIV-002). It is one command (FF-ARCH-06), audited.
- **Conflicts.** Two people are two devices: P04a's per-type merges apply unchanged. A membership change is never merged; the server decides.

## 6. Tasks (P04b)
One branch per task, as in P04a; merge after the headless tests, and after your check where marked.

| Task | Content | Main proof | Your check | Est. (pd) |
|---|---|---|---|---|
| **S-16** Spike: members on the server | Membership RLS, role checks in the functions, invitations, per-member key wrapping with X25519, on local Supabase | pgTAP allow/deny per role (owner, editor, viewer, removed, stranger), also with crafted requests; OQ-V5 answered | no | 2–3 |
| **T8** Spaces in one store | Schema v13, personal + shared workspaces, the active space and switching, WA-001 refined, member identity, export rules (B14) | upgrade test v2…v12 → v13; every view follows a space switch; GS-11 still holds | no | 3–4 |
| **T9** Server schema | Migrations for spaces, members, invitations, account keys; RLS and functions; contract test memory ↔ Supabase | contract and pgTAP suites green; limits (B13) | no | 3–4 |
| **T10** Keys for spaces | Account key pair, space keys wrapped per member, approval (B7), rotation on removal (B8) | only a member opens the space; a removed member cannot open anything sealed after the removal | no | 2–3 |
| **T11** Sync and roles | The engine per space, the role policy, the sync actor in a space, viewers read only, the 1-minute interval (B12) | two people editing one space: GS-14, GS-17, SYNC-003 hold; a viewer's write is refused on the device and on the server | no | 2–3 |
| **T12** Sharing commands | Create a space, move in and out (B3, with the classification check), invite, accept, approve, remove, leave, change role, hand over ownership, assign (B9) | FF-ARCH-06/09 steps; PRIV-002 (nothing moves without confirmation; Restricted never) | no | 3–4 |
| **T13** UI | Spaces in the drawer, the space's members and roles, invite (code, QR, link), join with a code, approve, "Move to space…" with its confirmation, assignee and "Assigned to me", "changed by", read-only views for viewers | widget tests; app integration test with two accounts on the in-memory server | **yes** | 4–5 |
| **T14** Two people | Your project, two accounts (yours and a second person's or a second account), Windows + Android: invite, join, edit, conflict, assign, remove; measure how soon changes appear (B12) | your check | **yes** | 1–2 |
| **T15** P04b exit gate | p04b-exit-gate.md, ADRs, invariants, risks; your review | all suites, CI | yes | 1 |

Order: S-16 → T8 → T9 → T10 → T11 → T12 → T13 → T14 → T15.

## 7. New invariants and scenarios (proposals)
- LF-INV-SHARE-001: an item enters or leaves a shared space only by an explicit command that the user confirmed; Restricted data never enters.
- LF-INV-SHARE-002: a write to a shared space is accepted only from its owner or an editor. Enforced on the device and on the server.
- LF-INV-SHARE-003: membership, roles and invitations change only on the server, through owner-checked functions. Devices only cache them.
- LF-INV-SHARE-004: after a member is removed, nothing sealed afterwards can be opened with a key that member had.
- Golden scenarios: GS-23 (a stranger and a removed member read and write nothing, even with crafted requests), GS-24 (a viewer cannot write), GS-25 (a move into a space shows what becomes visible, and nothing else moves), GS-26 (two people edit one task offline: P04a's merge rules hold).

## 8. Risks
- **R-PERMISSION** (main risk): a member sees or writes too much. Mitigation: the server enforces membership and roles; a pgTAP suite per role, with crafted requests; the spike first.
- **R-KEY-LOSS / R-KEY-LEAK**: the key handover and the rotation are new crypto. Mitigation: one well-known construction (X25519 + HKDF + AES-GCM); owner approval (B7); rotation tested with a removed member's old key; no new library.
- **R-DATA-LOSS**: a move between spaces or a rotation drops data. Mitigation: one command per move, with ids kept; the rotation replaces the space on the server only after the new copy is complete; export before leaving (B8).
- **R-SCOPE**: sharing invites many features. Mitigation: B11 lists what is left out; each can be its own later task.
- **R-CLOUD-COST**: more people means more rows. Mitigation: the limits in B13; the free plan's 500 MB covers families and small teams; the owner decides on a paid plan (D2).
