# ADR-0064: Sharing commands (schema v14)

- Status: Accepted (P04b task T12, 2026-11-19)
- Date: 2026-11-19
- Deciders: Implementation, within the owner's decisions B2–B9, B13 and B14 of [p04b-plan.md](../roadmap/p04b-plan.md)
- Related: [ADR-0059](0059-sync-egress-classification.md) (classification), [ADR-0060](0060-shared-spaces-in-one-store.md), [ADR-0061](0061-shared-spaces-on-the-server.md), [ADR-0062](0062-space-keys.md), [ADR-0063](0063-space-sync.md)

## Context
T8–T11 made shared spaces exist, sync and change keys. T12 adds what a person does with them: make and name a space, move items in and out, invite and join, approve, remove, leave, change roles, hand over, set the rules, assign a task, export.

The hard part is moving an item between workspaces while keeping its id (B3, ID-001). It must arrive on the account's other devices, whichever of the two syncs (personal or space) comes first. And a co-member must never use the same mechanism to take a personal record.

## Decision
1. **`SharingService`** (application port, `DriftSharingService`).
   - Changes to the store go through the gateway:
     - naming a space: `WorkspaceSettingsCommandHandler` op `setName`, owner only;
     - moving: `SpaceMoveHandler`;
     - assigning: task op `assign`;
     - showing a space.
   - Membership is the server's (SHARE-003): the device calls `SpaceGateway` and then refreshes its cache. The space sync's `refresh` is also where the leaving rule is applied.
   - Every failure is a `SharingProblem` the app can show:
     - `syncOff`: B5, sync must be on;
     - `notAllowed`;
     - `spaceFull` and `tooManySpaces`;
     - `noSuchInvitation`;
     - `ownerMustHandOver`;
     - `changedSinceShown`;
     - `cannotMove`;
     - `exportNotAllowed`.
2. **A space's name** is `workspace_settings.name`, a synced record sealed with the space key, so the server never sees it. Only the owner sets it. Every member's device checks that, because the server cannot see what a write changes. `createSpace` does the following: makes the space on the server, refreshes, names it with a command, marks its rules as seen, and shows it.
3. **Moving (B3), one command, ids kept.**
   - **`moveSetOf`** collects what moves (live records only):
     - a top-level task with its subtasks;
     - a list with its tasks and its events;
     - an event;
     - a calendar with its events;
     - a goal with its milestones;
     - with every task and event, its schedule, occurrence changes and done ticks.
   - **What stays:** reminders, focus history, measurements and results stay personal (B2, B3). Goal links stay where they are. A task moved alone leaves its list behind (`taskListId` cleared). An event leaves its calendar or list behind unless that moves too.
   - **What blocks a move:**
     - Restricted data (ADR-0059);
     - a tracked task (a habit or a target; B2: "until its tracking is turned off");
     - a subtask alone;
     - an item already there.
   - **Asked first (PRIV-002).** `previewMove` shows what becomes visible: counts, titles, whether notes and dates go along. The command carries each record with its version (`expect`). If anything changed since it was shown, nothing moves (`changedSinceShown`).
   - **Who:**
     - Into a space, the actor is the member and the command's workspace is the space, so the gateway stamps "changed by".
     - Out of a space, the actor is the profile and the workspace is the personal one. The handler checks the person is an owner or editor of the space (B4). A viewer cannot move things out.
   - **What a move writes:** each moved record gets the new workspace and owner (the account in a space, the profile outside) and a version above its last synced copy in the target. Each one has its own outbox row there (FF-ARCH-06 steps `space.moveIn` and `space.moveOut`).
4. **"Moved away": the source side of a move.**
   - `sync_base` is now keyed by **(workspace, kind, record)**, a table rebuild in v14. A moved record has a last synced copy in each workspace.
   - Each workspace's sync looks for records it synced that now live in another workspace. It pushes a tombstone of the last synced copy (`_pushMovedAway`). It sends this once: a conflict means someone changed the record meanwhile, and their change comes in by the pull.
   - **From the personal workspace,** the tombstone carries `movedTo`. On the account's other devices, the personal pull applies mode `movedAway`: the local personal copy goes, and the space's copy arrives by the space sync.
   - **Space change first, before the personal "moved away":** the space sync does not take a change whose record is still in another workspace here (`notTaken`, T11). It keeps it aside in `sync_parked`. When `movedAway` arrives, the space's cursor goes back to that change.
   - **Trust.** Only a "moved away" from the account's own personal workspace takes a record out of the personal workspace. A co-member's change can never do it (T11's guard stands).
   - **Moving out on another device:** the personal pull takes the personal copy over the space's copy.
   - **For the other members** the space's tombstone is a delete ("for the others it is like a delete", B3).
5. **Leaving (B8)**, `leaveSpaceHere`. It runs when this account leaves, when it is removed or the space deleted (found by `refresh`), and when the person lets a copy go (`forgetSpace`). It applies the space's leaving rule:
   - **(a) disappear:** the space's records, outbox rows and workspace go from this device;
   - **(b) disappear with export:** the space is hidden and kept (`left_keep = exportFirst`). `exportSpace` works once, then `forgetSpace`;
   - **(c) keep read only:** a copy stays and can still be shown. Nothing changes it: no member, so the device refuses writes, and there is no sync.

   In every case the key and the sync bookkeeping go, waiting changes are set aside, and nothing is sent. If the space was shown and the rule is not (c), the personal workspace is shown first, by a command. A space joined again is a member's space again (`cacheSpace` clears `left_at`).
6. **The rest:**
   - **Removing a member** removes them on the server, rotates the key (ADR-0062), and seals the space again at once (`syncSpace`).
   - **Leaving as the owner** needs a hand-over first (`ownerMustHandOver`).
   - **Rules (SHARE-005):** a change is a `RulesNotice` until `rulesSeen`. The rules a joiner saw before asking are not a notice when the approval brings them.
   - **Export (B14):** `exportSpace` writes a readable copy (`lifeflow-space-copy`, not restorable) when the person is the owner, or the export rule says every member, or under rule (b) after leaving.
   - **Assigning (B9):** only an owner or an editor, active in the space, can be assigned. No push notification.
7. **Schema v14:**
   - `workspace_settings.name`;
   - `sync_base` keyed by workspace;
   - `sync_parked`;
   - `workspaces.left_at` and `left_keep`.

   `recordSchemaVersion` = 14 because the settings record changed and "moved away" is new, so a v13 device says "Update LifeFlow".

## Consequences
- Not in T12:
  - The UI (T13). `SharingService` is not wired into the app's providers yet.
  - Two people on real devices (T14).
- Known limits:
  - A record changed on one device while another device moves it ends up where the change was made. The concurrent change wins over the move.
  - Goal links are not moved and may point across workspaces.
  - A rules change between asking to join and being approved shows no notice: the peek gives no change time.
  - The leaving rule is applied when the device next refreshes.
- Tests:
  - `sharing_test.dart` (11):
    - create and name, B5;
    - both invitation kinds, cancel, approve;
    - move in with the preview and "changed since shown", reminders kept, and back out;
    - what never moves, a list with its tasks;
    - a move reaching the other device in both orders;
    - move out as a delete for others;
    - assign, and a viewer moving nothing;
    - all three leaving rules;
    - remove with rotation, hand over, roles;
    - export by the rule, delete the space.
  - `space_sync_supabase_e2e_test.dart`: one more case over HTTP, a named space and a confirmed move.
  - FF-ARCH-06/09: steps `spaceSettings.create`, `task.assign`, `space.moveIn` and `space.moveOut`.
  - The upgrade loop runs from v2 to v13.
- Mutations: 24 run one at a time; 23 killed, one after a new test (a task leaving its list).
  - The one survivor is equivalent: the version "above the last synced copy in the target". A move always bumps by one and "moved away" by one, so the row's version never falls below that copy. It stays as a guard.
