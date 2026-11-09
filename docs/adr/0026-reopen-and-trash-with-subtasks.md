# ADR-0026: Reopening a completed task, and trashing a task that has subtasks

- Status: Accepted (owner review on device, 2026-11-07, P01 task T7c)
- Date: 2026-11-07
- Deciders: Project owner
- Related: [ADR-0011](0011-command-gateway-single-mutation-path.md), [ADR-0014](0014-transactional-outbox-and-atomic-side-effects.md), OQ-R3 (complete with or without subtasks)

## Context
On device review the owner found that:
1. A task marked done could not be marked open again, so a mistake could not be undone. The domain already allowed `done → todo` (LF-INV-TASK-004); there was no command or UI for it.
2. Trashing a parent left its subtasks alive, pointing to a trashed parent; the list then showed them as top-level tasks without saying so.
3. The owner asked to be asked first, and to have a setting for it.

While fixing (2), the existing "complete with subtasks" was found to change subtasks without a new version or an outbox row, so sync (P04) would not see those changes.

## Decision
- **Reopen**: unchecking a done task runs `ReopenTask` (`done`/`cancelled` → `todo`). Subtasks are not changed. An open task cannot be reopened (returned as a validation failure).
- **Trash with subtasks**: `TrashTaskWithSubtasks` trashes the task and every live descendant in one command. `TrashTask` trashes only the task; its direct subtasks **move up one level** (to the trashed task's parent), so nothing is left under a tombstone.
- **Every task a command changes** gets `version + 1` and `updatedAt`, and an outbox row under the same operation id (LF-INV-VER-001, LF-INV-OUTBOX-001). This also fixes "complete with subtasks".
- **Asking**: when the task has subtasks, the app asks: Cancel, Keep subtasks, or Trash subtasks too, with "Remember my choice". A task without subtasks is trashed without a question.
- **Setting** (Settings → Tasks): Ask every time (default), Move the subtasks to the trash too, Keep the subtasks. It is a **device setting**, stored in the encrypted device registry (`registry_meta`, key `setting.subtaskTrashPolicy`). It is not profile data: it is not exported and will not sync.

## Consequences
- Pro: completion mistakes can be undone; trashing a parent is explicit and consistent.
- Pro: subtask changes are visible to sync.
- Con: the setting is per device, not per account. Acceptable for an app preference; revisit if settings sync is wanted (P04).
- Not changed: trash is still a tombstone; restoring from the trash is a later feature (Trash view, product scope).

## Verification
- `packages/infrastructure/test/task_reopen_trash_test.dart`: reopen (version, outbox, subtasks untouched, open task refused, complete again); complete with subtasks bumps versions and writes an outbox row per subtask; trash with subtasks (whole subtree, one outbox row each); trash only this task (direct subtasks move up, grandchildren keep their parent); a stale command changes nothing.
- `atomic_set_test.dart` (FF-ARCH-06) covers reopen, complete with subtasks and trash with subtasks with fault injection.
- `packages/ui/test/app_flow_test.dart`: uncheck reopens; the question, its three answers and "Remember my choice"; the setting applies without asking; Settings screen changes it.
