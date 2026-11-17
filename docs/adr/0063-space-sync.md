# ADR-0063: Sync of shared spaces

- Status: Accepted (P04b task T11, 2026-11-18)
- Date: 2026-11-18
- Deciders: Implementation, within the owner's decisions B2, B4, B5 and B12 of [p04b-plan.md](../roadmap/p04b-plan.md)
- Related: [ADR-0056](0056-sync-engine.md) (the engine), [ADR-0058](0058-sync-ui-and-scheduler.md) (the scheduler), [ADR-0060](0060-shared-spaces-in-one-store.md), [ADR-0061](0061-shared-spaces-on-the-server.md), [ADR-0062](0062-space-keys.md)

## Context
T8 put shared spaces in the store, T9 on the server, T10 gave them keys. A space's records still did not move between people. T11 syncs them with P04a's engine, so the merge rules hold for two people as they do for two devices (SYNC-002/003, GS-14, GS-17). It also finishes a key rotation by sealing everything again, the step T10 left to the space sync.

## Decision
1. **One engine, a space mode.** `SyncEngine` takes an optional `SpaceSyncMode`. Without it, personal sync is unchanged. With it:
   - **Before syncing,** the engine asks the space (`spaces()`), not `workspaces()`. A space it is no longer in is `workspaceGone`; a newer key is `keyChanged`.
   - **Pushes name the key** (`keyId`). A push refused as `staleKey` (the key was rotated meanwhile) sets nothing aside: the sync ends as `keyChanged`, and the change waits for the new key.
   - **Viewers only pull** (`canPush: false`; SHARE-002). Nothing is pushed or purged, even a change crafted into a viewer's outbox, and the server would refuse it anyway (T9).
   - **Only the kinds a space holds (B2)** go out or come in: lists, tasks, schedules, repeats and done ticks, events, calendars, goals, milestones, goal links, and the space's settings (`sharedSpaceKinds`). Reminders, focus sessions, execution records, measurements and period results stay personal. A device never sends them from a space (`withheld`) and never takes them into one (`notTaken`).
   - **A pulled row is not taken (`notTaken`)** when it names another workspace, or when its id is a record of another workspace in this store. A member cannot overwrite someone's personal record, or another space's, by naming its id. This matters because "Move to space…" keeps ids (B3).
   - **Rows of an old key** (a rotation not finished, ADR-0062) open with the previous key.
   - **A row of a key the device does not know:** if the device's key is still the space's current one, the row is older, so it is skipped (a newcomer after a rotation). Otherwise the row is newer: the pull stops before it, the sync ends as `keyChanged`, and nothing past it is lost.
   - **The same version under a new server id** (sealed again) updates the last synced copy's server id. A later purge of it is then still recognised (GS-14 after a rotation).
2. **`DriftSpaceSyncService`** (a `SyncRunner`, the new small interface `SyncService` now extends):
   - **`refresh`** puts what the server says about the account's spaces into the store's cache (`cacheSpace`: roles, rules, who is in; SHARE-003).
     - For each active membership it opens the space key (`SpaceKeyService.openSpaceKey`) and makes a sync state with its own device id.
     - A space no longer listed (removed, left, deleted) loses its sync state and its cached members on this device. Nobody acts in it as a member and it is not listed. Its data stays until the leaving rule is applied (T12).
     - The account's key pair is opened with the personal workspace key, so personal sync must be on (B5). Otherwise `refresh` gives `notOn`.
   - **`syncNow`** refreshes, then syncs the **shown** space as that space's sync actor (ADR-0056's authorization already allows the actor `sync` only in a workspace this device syncs).
   - **Finishing a rotation:** after a sync that ended up to date, the owner's device seals every record of the space again (`resealAll`), deleted ones included. It then drops the old key's rows (`finishRotation`). An interrupted rotation is finished at the next sync, because the previous key is still kept. A record someone already pushed under the new key is left to the normal sync.
   - `status` is on while a shared space is shown.
3. **Every minute (B12).** The app wires a second `SyncScheduler` with `every: spaceSyncEvery` (1 minute) over the space sync. It has the same "When to sync" setting and runs only while a space is shown. The personal scheduler keeps its 5 minutes. `AppWiring.resumed` and `stopSync` handle both. The server gateway is used for spaces only when it implements `SpaceGateway` (the HTTP gateway does).

## Consequences
- **What still needs T12:**
  - creating a space and its name: the name is cached as `''` until T12 gives it a home in the space's settings record;
  - running `rotate` after a removal;
  - applying the leaving rule to a space that disappeared;
  - B2 checks when commands write.
- **What still needs T13:** showing all of this, and a sync right after switching to a space. Until then the first space sync after a switch comes within a minute.
- `SyncReport.notTaken` counts the refused pulled changes, for the local log.
- Tests:
  - `space_sync_test.dart` (12):
    - GS-17 and SYNC-003 for two people, with "changed by";
    - GS-14 delete and purge;
    - a viewer reads and does not push (device and server);
    - nothing personal or foreign is taken, and a personal kind is not sent;
    - rotation end to end: everything sealed again, an offline editor catches up, the removed member stops, and their key opens nothing new;
    - a rotation not finished yet: rows open with the previous key, or a newcomer skips them;
    - a rotation during a sync: the pull stops before the new key, and the old-key push is not set aside;
    - status, B5, and the 1-minute scheduler.
  - `space_sync_supabase_e2e_test.dart` (2, local Supabase, CI): sharing with both invitation kinds, a viewer, and a rotation over HTTP.
- Mutations: 19 run one at a time; 15 killed, 4 not.
  - Removed: `_syncAgain`, a retry after `keyChanged` reachable only in a race. Without it, the next run's refresh does the same.
  - Equivalent:
    - no purge for viewers: a viewer's purge is refused and ignored anyway;
    - the early `keyChanged` and "not active" checks: the stale push and the unknown-key stop, or the refresh, give the same outcome.
