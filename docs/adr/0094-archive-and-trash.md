# ADR-0094: The Archive and the Trash
- Status: Accepted (P06b W6, 2026-11-04; the owner's UI 4 and his answers Q3 to Q5)
- Date: 2026-11-04
- Deciders: the owner ([p06b-plan.md](../roadmap/p06b-plan.md) W6, §4); implementation
- Related: [ADR-0046](0046-lists-colours-and-order-keys.md) (a list's trash), [ADR-0067](0067-document-store-and-exact-search.md) (documents), [sync-protocol.md](../data/sync-protocol.md) §6 (a delete is a tombstone; purge), AP-09 (tombstones until retention allows purge)
## Context
Only documents and goals had a trash screen. Tasks, lists and events could be trashed and restored by command, but nothing listed them, nothing deleted for good, and only goals could be archived. The owner asked for an Archive and a Trash for lists, tasks, events and documents, from the navigation drawer; deleting for good, and by itself after 30 days by default (a setting); archiving a list to take its tasks and events with it; and a choice whether archived items that are scheduled still show on the Calendar and the Timeline.
## Decision
1. **Two columns on lists, tasks, events and documents (schema v19):** `archivedAt` and `purgedAt`, both null by default. Both sync, export and restore with the record. A file of schema 18 or older reads with both null.
2. **Archive** puts an item away, not in the trash.
   - It takes what is in it, at one moment: a list its tasks (with their subtasks) and its events; a task its subtasks; a document its subdocuments. **Unarchive** brings back exactly what went with it, told by that moment, as a list's trash and restore do (ADR-0046). What was archived on its own before stays archived.
   - An archived item is in no list, tree, search, Overview, reminder, habit list or assistant plan. It is in the Archive.
   - Unarchived where its list or parent is still away, it goes to the top, in no list.
   - A trashed item cannot be archived; an archived item can be trashed (from the Archive).
3. **The Archive and the Trash are destinations** in the drawer and the rail, between Goals and Settings. Each lists the top-level items of the shown space with where each was, how many went with it, and when; filtered by kind. The Archive has the switch below; the Trash has the retention.
4. **Archived and scheduled:** a device setting (`Show archived items on the Calendar and Timeline`, off by default). Off, an archived task or event is not on the Calendar, the Timeline, Today or Upcoming. On, it is. Search and the lists never show it.
5. **Restore** of a task from the trash is new (`restore`, with what went to the trash with it; its parent or list gone: at the top, in no list). Lists, events and documents restore by their own commands, which place them again.
6. **Delete for good** (`purge`), of an item in the trash and what went to the trash with it:
   - **The content is blanked on the row and the tombstone stays**, marked `purgedAt`: a task's title, notes and tags; a list's and an event's title and place; a document's title and body. What belonged to it is tombstoned, each with its own outbox row: a task's or an event's schedule, changes of its days, done ticks and reminders; a document's revisions (they hold its old text, now blanked) and links.
   - Why not a hard delete: a delete reaches the person's other devices as a change of the record, and the server drops the content of a deleted record only after 90 days (GS-14). A row deleted here would come back at the next pull. A blanked tombstone replicates like any change, so every device forgets the content at once, and the existing purge later drops the row.
   - A purged item is not listed in the Trash and cannot be restored: the restore commands refuse it.
   - The history stays (execution records, measurements, period results of a task): it holds numbers, not what the person wrote.
7. **Retention and "Empty trash"** (the owner's Q3):
   - Delete forever asks first; so does "Empty trash".
   - The trash keeps an item for the days of the device setting (7, 14, 30, 60, 90, 180, 365; 30 by default; or until the person empties it). What has been there that long is deleted for good when the profile opens and when the Trash is opened or its retention changed. It runs for the shown space; a viewer of a shared space deletes nothing.
8. **Navigation:** ten destinations do not fit a short window, so the rail scrolls.
## Consequences
- What went together is told by the second (times are kept to the second), so two separate actions on related items within the same second cannot be told apart. As with a list's trash, this is not a case a person reaches by hand.
- The auto-delete runs when the app opens or the Trash is used, not on a timer; an app left open for days deletes at its next use.
- A device that never synced keeps the blank tombstones (a few bytes each). They go with a later purge by the server when it syncs.
- Documents linked to a task that was deleted for good show it as missing.
- Moving a list from the Archive to the trash is two steps by design.
- The P06 device check lists the new screens after W6.
