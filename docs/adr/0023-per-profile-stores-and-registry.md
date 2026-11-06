# ADR-0023: One database file and key per profile, plus an encrypted device registry

- Status: Accepted (owner decision, 2026-11-06, P01 task T6c)
- Date: 2026-11-06
- Deciders: Project owner
- Implements: SR-03, data-architecture §6, LF-INV-ID-002 (storage isolation)
- Related: [ADR-0008](0008-guest-first-with-optional-account-binding.md), [ADR-0014](0014-transactional-outbox-and-atomic-side-effects.md), [ADR-0021](0021-encryption-at-rest-platform-posture.md), [ADR-0022](0022-windows-encryption-at-rest.md)

## Context
SR-03 and data-architecture §6 require each LocalProfile to have its own database file and its own key. From T4 to T6b all profiles shared one file, isolated only by `workspaceId` scoping and the owner policy. The owner required the designed layout before P01 exit. Two choices were open:
1. Where the list of profiles lives, since it cannot sit inside any single profile's store.
2. How a change that touches both a profile's store and that list stays consistent, given that no transaction spans two files.

## Decision
**Layout** (app-private support directory):
- `profiles/<profileId>.sqlite`: one store per profile, key `lifeflow.db.key.<profileId>`. Same schema as before, but it holds **exactly one** profile, its Personal Workspace (WA-001), its data, and its own governance tables (audit, outbox, event log, dedupe).
- `lifeflow.registry.sqlite`: a small **encrypted registry** with its own key (`lifeflow.registry.key.v1`). It lists the profiles on the device (id, display name, non-secret account id and provider) and stores which one is active. It holds no user content. (Owner choice 1a, over JSON in secure storage or a plain JSON file.)
- All files follow the at-rest policy of ADR-0022 (encrypted by default; plain only in an explicit fallback build).

**Source of truth and ordering (owner choice 2)**:
- A profile's **own store is the source of truth** for its data and its binding. Its audit, outbox and dedupe rows are written in that store's transaction, so the atomic set (LF-INV-GOV-003) holds **per store**.
- The registry is an index plus the device-level "active profile" pointer.
- A change that also affects the registry follows a fixed order: (1) the registry records an intent (`pending_sync = profileId`); (2) the profile's store commits through the command gateway; (3) the registry copies the mirrored fields from the store and clears the intent. If the app stops between steps, the next open reconciles that one profile from its store. **This is a controlled exception to LF-INV-GOV-003**: the registry write is not in the same transaction as the store write, but it is derived from the committed store and repaired on the next open, so no profile data or audit is lost.

**Consequences for the domain and handlers**:
- `ProfileCommandHandler` binds or signs out only the profile that owns its store. When `ProfileBinder` decides on a new profile ("new space", or a different account on a bound profile, OQ-S7), the handler **rejects** the command. The account layer then creates a separate store for the new profile and binds it there. SR-03 is therefore enforced on the single mutation path.
- Switching profile is a device-level registry change, not a mutation of profile data. The app closes the current store, opens the target store, and rebuilds its provider scope.

**Migration of the pre-SR-03 shared database** (one time):
- Each profile's rows are copied into its own new store by ownership: workspaces owned by the profile; task lists and tasks in those workspaces; dedupe rows for those workspaces; and audit, outbox and event-log rows with those operation ids. IDs are preserved (LF-INV-ID-001). Row counts are verified per table.
- The registry entries and a `legacy_migrated` marker are written in one registry transaction. The shared file is then renamed to `lifeflow.sqlite.pre-sr03` and **kept** (still encrypted, old key kept) as a safety net. An interrupted migration is redone from the untouched source.
- Governance rows that cannot be attributed to a workspace are counted (`legacy_unmapped_rows`) and remain only in the kept file.

## Consequences
- Pro: profile isolation is now physical. One profile's data cannot be read with another profile's key, and deleting a profile will be a file plus key operation (P04).
- Pro: per-profile export and restore (T7) become file-scoped.
- Con: switching profile reopens a database; this is acceptable because switching is infrequent (AS-07).
- Con: the registry write is outside the store transaction. This is mitigated by the intent marker and reconciliation, and covered by tests.
- Con: the kept `.pre-sr03` file is a second encrypted copy of the pre-migration data. Follow-up: remove it once T7 export exists, or on the owner's confirmation.
- Correction recorded: on Windows, `flutter_secure_storage` 4.x keeps keys in a DPAPI-protected file (`flutter_secure_storage.dat`), not in Credential Manager. So the size limit cited against registry option (b) does not apply to this version. Option (a) was chosen for transactional writes and a uniform at-rest policy, and that rationale still holds.

## Verification
- Headless (`profile_directory_test.dart`, `account_service_test.dart`, app integration test): every profile gets its own file and key; a missing file is reported, never replaced; in a plain build, A's data is physically absent from B's file; switching in the UI swaps the store; "new space" creates a new file and key while the guest keeps its data; an interrupted change is reconciled; the shared DB is split with ids, tasks, audit and outbox preserved and FTS rebuilt; migration runs once, resumes after a partial copy, and finishes an interrupted rename.
- Mutation checks: copying all tasks into every profile, letting the handler bind a new profile in place, and skipping reconciliation each make tests fail.
- Device (Windows): the owner's encrypted shared DB was backed up, then split into 2 encrypted profile stores plus an encrypted registry; the shared file was kept as `.pre-sr03`; existing tasks and the subtask are shown.
