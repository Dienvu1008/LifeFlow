# ADR-0060: Shared spaces in one profile store (schema v13)

- Status: Accepted (P04b task T8, 2026-11-17); the personal export amended by [ADR-0070](0070-documents-in-shared-spaces.md) (it lists the ids it points to in a space, so it can be restored after a move)
- Date: 2026-11-17
- Deciders: Implementation, within the owner's decisions B1, B2, B5, B10, B14 of [p04b-plan.md](../roadmap/p04b-plan.md)
- Related: [ADR-0023](0023-per-profile-stores-and-registry.md) (one store per profile), [ADR-0053](0053-sync-storage-contract-schema-v10.md) (outbox contract), [ADR-0057](0057-joining-and-leaving-sync.md), [ADR-0059](0059-sync-egress-classification.md), spike S-16

## Context
Until P04b a profile store held exactly one workspace, its personal one (LF-INV-WA-001). Every view, every command and every bulk statement could treat "the active workspace" and "the personal workspace" as the same thing. A shared space (B1) is another workspace in the same store, so they now differ. Before T8:
- an overwrite restore compared the file with every record of the store, and would have moved a shared space's records to the trash;
- turning personal sync off, joining and undoing a join ran statements without a workspace filter;
- reminders, focus and closing habit periods followed the shown workspace;
- the export took whole tables, other people's data included.

## Decision
1. **One store, several workspaces.** A store holds its profile's one personal workspace (kind `personal`, owned by the profile) and any number of shared spaces (kind `shared`, owned by the owner's account). `profiles.active_workspace_id` is the one shown. LF-INV-WA-001 now reads: one personal workspace, any number of shared ones, one shown at a time. Showing another space is one command on the profile (`switchSpace`, through the gateway, audited). It accepts the personal workspace, or a shared space the profile's account is an active member of. No record moves.
2. **Three kinds of place:**
   - **Follow the shown space** (views and commands): tasks, lists and the Overview, events and calendars, the agenda and scheduling, goals, habits views, setting reminders. Every view still reads the shown workspace when it subscribes, and the UI subscribes again after a switch (ADR-0058 §4).
   - **Always the personal workspace:**
     - sync of the profile (P04a);
     - export and restore, and the restore and join snapshots;
     - reminder planning on the device;
     - focus sessions (the focus bar shows the running one in every space);
     - closing habit periods;
     - account binding and its "has data" check;
     - profile commands.

     Reminders, focus sessions, habits and measurements are personal (B2), so a switch never drops a reminder from the device.
   - **Filtered by workspace:** every bulk statement of sync setup (join, undo, turn off), the purge of a pulled page, and the "Changes to review" list and count of personal sync. `sync_base` gets a `workspace_id`.
3. **Who acts in a shared space.** The local person is a new actor kind, **`member`**, whose id is the account id (profile ids are per device, account ids are the same everywhere). `ProfileStore.commandContext()` gives every service the shown workspace and the actor: `owner` + profile id in the personal workspace, `member` + account id in a shared space. Records made in a shared space carry the account id as `ownerId`.
4. **Roles on the device.** The authorization policy accepts a `member` command only in a shared space, only from an **active** member, and only with the **owner or editor** role. A viewer and someone waiting for approval are refused, even with a crafted command. The roles come from a local cache (`space_members`), written only from what the server says (`ProfileStore.cacheSpace`, used by the space sync of T11/T12; LF-INV-SHARE-003). A profile acting as `owner` in a shared space is refused, because the space belongs to someone else.
5. **"Changed by" (B10).** Every record gets `changed_by`. The gateway sets it to the member's account id on every record a command wrote in a shared space, in the same transaction. Those records are found through their outbox rows: every written record has one (ADR-0053), including the handler's own record row that the gateway writes. It stays null in the personal workspace. In a merge it is bookkeeping (`syncMetaFields`) and follows the side whose change was kept. Tasks get `assignee_id` for B9.
6. **Export (B14).** "Export" is the personal workspace only, also while a shared space is shown:
   - its records, outbox and dedupe rows;
   - the governance rows of its operations;
   - the profile as showing its personal workspace.

   Nothing of a shared space's rows or content is in the file. The one trace is the audit row of the "show space" command, a personal command that names the space's opaque id. Exporting a shared space under its export rule is T12/T13. The restore side compares and writes the personal workspace only. A file from the same account on another device is placed into the personal workspace, never into the shown space.
7. **Schema v13**:
   - `workspaces`: name and the space's rules (leaving, export, invitation kind, when they changed, when they were last shown);
   - `space_members`;
   - `tasks.assignee_id`;
   - `changed_by` on all 16 record tables (added only to the tables an earlier upgrade step did not just create);
   - `sync_base.workspace_id`, filled with the workspace that was synced.

   **`recordSchemaVersion` becomes 13**, since a synced record's shape changed. A device on v12 that pulls a v13 record says "Update LifeFlow" (D10). A v13 device reads pulled v11/v12 records with `changedBy` and `assigneeId` null. `space_members` is a cache: not exported, not synced.

## Consequences
- A shared space can live in a store, be shown, be written by its owner and editors, and be read by its viewers. It does not sync yet (T11), and nothing creates one yet except the server cache (T12). The UI comes in T13.
- B2 ("no reminders, habits or focus in a shared space") is not enforced at write time yet. T12 adds the check to the commands, with the share egress check of ADR-0059.
- Tests:
  - `spaces_store_test.dart` (12):
    - listing and showing spaces (audited), and refusing a space one is not an active member of;
    - every view showing only the shown space;
    - the account as owner and "changed by", the personal workspace unchanged;
    - a viewer and someone waiting refused, also with crafted commands;
    - reminders, focus and habit periods personal across a switch;
    - export without the space;
    - an overwrite restore not touching the space;
    - personal sync on and off while a space is shown, leaving the space's state, last synced copies, review items and waiting changes alone;
    - the v13 fill of `sync_base.workspace_id`.
  - `atomic_set_test.dart`: steps for showing a space, a member's command there (with its stamp) and switching back.
  - The store upgrade loop now runs from v2 to v12.
  - A domain merge test for `changedBy`.
- Mutations 16 of 16 killed. This needed two more tests: a crafted command from someone waiting for approval, and a personal habit closing while a space is shown.
- Not covered by a test: a restore file from the same account's other device placed while a shared space is shown. The code path is the same `personalWorkspaceOf`, but no test exercises it.
