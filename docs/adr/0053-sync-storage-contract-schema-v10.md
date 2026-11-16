# ADR-0053: The sync storage contract (schema v10)

- Status: Accepted (P04 task T1, 2026-11-14)
- Date: 2026-11-14
- Deciders: Implementation, within the owner's decisions D4 and D6 of [p04-plan.md](../roadmap/p04-plan.md)
- Related: [ADR-0014](0014-transactional-outbox-and-atomic-side-effects.md) (outbox), [ADR-0029](0029-planning-storage-schema-v4.md) (record registry), [ADR-0050](0050-navigation-habits-and-manual-results.md) (the result policy, U-D13), [ADR-0052](0052-sync-backend-and-end-to-end-encryption.md) (sync backend), spike S-04 in [spike-results.md](../spikes/spike-results.md)

## Context
Spike S-04 showed that sync can push the current state of each record that pending outbox rows name, with the last synced version as the base, and pull and merge per type. It also found two gaps: an ended focus session wrote its execution record without an outbox row, and the result policy (U-D13), which should sync with the workspace (D4), lived on the profile, which is device-local.

## Decision
1. **The outbox contract is "every written record has an outbox row of its own"**, under the command's operation, with `entityType` = the record kind of `record_kinds.dart` and `entityId` = the record's id. The push reads the record's current row from the store, so the outbox payload does not need a fixed shape; the plan's idea of full-record payloads is dropped as unnecessary. The FF-ARCH-06 test now checks, for every handler operation, that each record whose version changed has such a row. The focus handler writes the row for the execution record.
2. **`workspace_settings`**, a syncable record kind (one row per workspace, its id the workspace id, no row = the defaults), takes over the result policy. A new `WorkspaceSettingsCommandHandler` sets it; it refuses an id other than the command's workspace. `profiles.manual_results` stays as a legacy column (migrations are additive) and is neither read nor written any more. The v10 upgrade copies a `tick` policy into a settings row; an export from schema 9 or older gets the same conversion; a file with a bad policy or settings of another workspace is refused.
3. **Device sync bookkeeping**: `sync_base` (the last synced copy of each record: kind, id, version, JSON) for three-way merges, and `sync_state` (per workspace: this device's id, the pull cursor, the last sync time and result). Both are device-local: not exported, not synced, not restored.
4. An index on `outbox (status, entity_type, entity_id)` for the push's read of pending rows.

## Consequences
- Schema v10; stores from v2–v9 upgrade with every column checked (`profile_directory_test.dart`).
- T3 fills `sync_base` and `sync_state` and moves outbox rows from `pending` to `acked`.
- Exports grow by the `workspaceSettings` table; older app versions refuse v10 files as newer (as for every schema step).
- Tests: `sync_contract_test.dart` (the execution record's outbox row, the settings record, its own-workspace rule, export round trip, v9 conversion, refused files), the outbox check in `atomic_set_test.dart`, the v9 → v10 upgrade test; the spike's guard now expects no gap. Mutations 7/7 killed.
