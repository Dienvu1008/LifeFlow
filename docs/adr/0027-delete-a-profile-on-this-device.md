# ADR-0027: Deleting a profile from this device

- Status: Accepted (owner request, 2026-11-07, P01 task T7d)
- Date: 2026-11-07
- Deciders: Project owner
- Related: [ADR-0023](0023-per-profile-stores-and-registry.md) (per-profile files and keys), [ADR-0024](0024-sign-out-locks-the-account-profile.md), [ADR-0025](0025-profile-export-and-restore.md)

## Context
Profiles could be created (guest, new space, restore) but never removed. During device testing the list filled with old "Guest" and "Guest (restored)" profiles, which made results hard to read. ADR-0023 anticipated that deleting a profile is a file plus key operation.

## Decision
- **Only a profile that is not open** can be deleted. The open profile's store is in use; the user switches first. So one profile always remains, and the app is never left without one.
- **What is removed**: the registry entry, the profile's database file (with `-wal`, `-shm`, `-journal`) and its key in secure storage. Other profiles are untouched.
- **Order and recovery** (same idea as the ADR-0023 intent): in one registry transaction, write the intent `pending_delete` and remove the registry row; then delete the files; then the key; then clear the intent. Once the row is gone, the profile is never listed or opened again. If the app stops in between, the next open finishes the delete.
- **Any profile type**: guest, restored, or an account profile (also when signed out). For an account profile the dialog says that nothing is stored online yet, so the account cannot bring the data back. Signing in again with that account later gets a new empty profile (ADR-0008 rules).
- **Confirmation**: "Delete …?" with "cannot be undone" and a hint to switch and export first. The delete button is red.
- **Not a command on profile data**: like switching, deleting is a device-level change to the registry and files, not a mutation inside a profile store; there is no store left to hold its audit row. It is not undoable.

## Consequences
- Pro: the device can be cleaned up; test results are easier to read.
- Con: permanent. Mitigated by the confirmation and the export hint.
- Later: deleting the open profile in one step (switch, then delete), and a cloud copy at P04.

## Verification
- `packages/infrastructure/test/profile_delete_test.dart`: file, key and registry entry removed, others untouched; the open profile refused; unknown profile reported; a signed-out account profile can be deleted; a delete interrupted by a secure-storage failure is finished on the next open.
- `packages/ui/test/profile_delete_flow_test.dart`: Delete on every profile but the open one; Cancel; confirm removes it; account warning; a refused delete is shown.
- `apps/lifeflow_app/test/app_integration_test.dart`: through the UI on real stores, the file and key are gone.
- Mutations: skipping the finish-on-open fails the recovery test; allowing the open profile fails the refusal test.
