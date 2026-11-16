# ADR-0057: Joining and leaving sync

- Status: Accepted (P04 task T4, 2026-11-16)
- Date: 2026-11-16
- Deciders: Implementation, within the owner's decisions D4, D5, D11, D15 of [p04-plan.md](../roadmap/p04-plan.md)
- Related: [ADR-0052](0052-sync-backend-and-end-to-end-encryption.md), [ADR-0053](0053-sync-storage-contract-schema-v10.md), [ADR-0054](0054-sync-keys-recovery-key-and-passphrase.md), [ADR-0055](0055-sync-server-port-and-contract.md), [ADR-0056](0056-sync-engine.md), [ADR-0023](0023-per-profile-stores-and-registry.md)

## Context
T3 gave a sync engine for a workspace that already syncs. T4 decides how a profile starts syncing, how a second device of the same account joins, how a join is undone, and how sync is stopped. Today each device's profile has its own workspace id (ADR-0023), so the second device must move into the first device's workspace.

## Decision
1. **A port, `SyncService`** (application), with `DriftSyncService` behind it: `status`, `prepare` (fresh, join with a recovery key or a passphrase, already on), `offerRecoveryKey` + `startWithRecoveryKey`, `startWithPassphrase`, `join`, `undoJoin`, `syncNow`, `turnOff`, `deleteServerData`. Problems come back as `SyncSetupProblem` values, not exceptions, except when `prepare` cannot reach the server.
2. **Every change goes through the gateway** as one command of the new `SyncSetupHandler` (`TurnSyncOn`, `JoinSyncedWorkspace`, `UndoSyncJoin`, `TurnSyncOff`; actor owner), so each is audited and atomic (GOV-001, FF-ARCH-06). The server calls and the key store are outside the transaction and run in an order that leaves nothing half done: the server workspace is created first, the key is kept, then the command runs; a failed command forgets the key again.
3. **First device.** A recovery key must be confirmed by typing back two of its 24 words before anything reaches the server (T1b); a passphrase must pass the policy (12 characters, not common). The server gets the workspace id, the wrapped key, the unlock kind and salt, and a **key fingerprint** (`key_id`: an HKDF of the workspace key, 64 hex; migration `20261114000003`), which reveals nothing about the key. `TurnSyncOn` adds a pending outbox row for **every** record of the workspace, so the first sync uploads all of it, also records sent before sync was turned off.
4. **Joining (D5).** The device unlocks the account's key with the recovery key or passphrase; a wrong one, a mistyped word (named by its position) or a key whose fingerprint differs is refused and nothing changes. Then, in one command:
   - a snapshot of the whole store (restore snapshot id `sync-join`) is kept for undo;
   - every record moves into the account's workspace **with its id kept** (`workspace_id` updated; the workspace settings record takes the new workspace id; outbox, dedupe and the profile follow; the old workspace row goes);
   - **merge this device's data** (the default): every record gets a pending outbox row and is uploaded, then the account's data comes down and is merged by the engine;
   - **use the account's data only**: the service first exports the store to a file (`SyncSetupResult.export`, for the UI to offer to save); the command deletes the local records; the account's data comes down.
5. **Undo a join** puts the store back as the snapshot has it (old workspace id, its records), turns sync off and forgets the key. Each restored record gets an outbox row marked `local`, so the outbox contract holds while nothing is sent. Undo is possible until sync is turned off. **Undo does not take back what a merge already uploaded**; the other devices keep it.
6. **Turning off (D11)** removes the sync state, the last synced copies and the review items, marks unsent rows `local` and forgets the key. The data stays. **Delete my data from the server** deletes the server workspace (its records with it), then turns off here. Another device notices on its next sync: `workspaceGone`. A device whose key fingerprint no longer matches the server's (the account was started again with a new key) gets `keyChanged` and must turn off and join again.
7. **Signing out does not turn sync off.** The engine reports `signedOut` and keeps everything pending; signing in again resumes.

## Rejected
- A new workspace id on the joining device's records (a re-key): breaks LF-INV-ID-001 and every reference.
- Downloading the account's data into a second workspace on the device: a profile has one active workspace (ADR-0023); two would need the P04b sharing model.
- Undo by deleting the uploaded records from the server: they may already be on other devices and edited there.

## Consequences
- Outcomes `keyChanged`, `workspaceGone` and `notOn` join `SyncOutcome`; `SyncOutcome` and `SyncReport` moved to the application package with the port.
- The handler's own outcome uses the entity id `sync:<workspace>`, because the workspace settings record already has the workspace id and both outbox rows can belong to one operation.
- Profile restore's undo ignores the `sync-join` snapshot.
- Tests: `sync_setup_test.dart` (10: confirmation before upload, merge keeps ids, settings move, replace with export and undo, passphrase, turning off, delete and `workspaceGone`, starting again uploads old records, `keyChanged`, offline and signed out, the command's refusals and the sync actor), the four setup operations (five steps) in `atomic_set_test.dart`, `key_id` cases in `remote_contract_test.dart` (memory and local Supabase). Mutations: 14 of 14 killed, after adding the test where records already sent are uploaded again on a new start, and the check that undo leaves no record pending.
