# P01 exit-gate evidence

Maps each line of the P01 definition of done ([definition-of-done.md](definition-of-done.md)) to the tests and checks that prove it. Status: **ready for owner review**, pending the owner's device check of T7 and a green CI on the T7 branch.

How to reproduce: `dart test` in `packages/foundation|domain|application|infrastructure`, `flutter test` in `packages/ui` and `apps/lifeflow_app`, and `dart run tools/fitness/<script>.dart` for each fitness script. CI runs the same (`.github/workflows/ci.yml`).

## Golden scenarios

| GS | Proof |
|---|---|
| GS-06 crash between commit and dispatch | `infrastructure/test/atomic_set_test.dart` (FF-ARCH-06), `command_gateway_test.dart` |
| GS-07 outbox iff committed | `atomic_set_test.dart` (fault injection at each pipeline point), `command_gateway_test.dart` |
| GS-11 cross-profile/workspace read denied | `app_services_test.dart` (WorkspaceOwnerAuthorization), `profile_directory_test.dart` (switching, separate files) |
| GS-12 concurrent writers, one wins | `command_gateway_test.dart`, `task_commands_test.dart` (expectedVersion) |
| GS-18 hierarchy acyclic and bounded | `domain/test/task_rules_test.dart`, `task_commands_test.dart`, export validation in `profile_export_test.dart` |
| GS-19 encryption at rest | `local_store_test.dart` (encrypt policy, upgrade from plain), `storage_security_test.dart` (header detection); Android and Windows both encrypted by default (ADR-0021, ADR-0022); owner confirmed on device |
| GS-20 export/restore round trip | `profile_export_test.dart` (clean-install round trip with original ids, tampered, newer rejected), `profile_restore_test.dart` (restore into the same profile: identical, overwrite, merge, hierarchy, undo; T7b), `data_flow_test.dart`, `app_integration_test.dart`; owner device check of T7b pending |
| GS-22 guest to account keeps ids, offline | `account_service_test.dart`, `profile_commands_test.dart`, `ui/test/account_flow_test.dart`; owner confirmed on device (sign in, offline, sign-out lock) |

## Invariants

| Invariant | Proof |
|---|---|
| LF-INV-ID-001/002 | `foundation/test/ids_test.dart`; bind keeps ids (`profile_commands_test.dart`); one file and key per profile (`profile_directory_test.dart`) |
| LF-INV-WA-001 | `domain/test/workspace_rules_test.dart`, `app_services_test.dart` |
| LF-INV-TASK-001/002/003/004/010/011 | `domain/test/task_rules_test.dart`, `task_commands_test.dart` |
| LF-INV-GOV-001/002/003 | `application/test/command_test.dart`, `authorization_gate_test.dart` (FF-ARCH-09), `atomic_set_test.dart`; one controlled exception recorded in ADR-0023 (registry intent) |
| LF-INV-OUTBOX-001/002 | `atomic_set_test.dart`, `command_gateway_test.dart`; a restore writes one outbox row per changed record (`profile_restore_test.dart`) |
| LF-INV-AUDIT-001 | `atomic_set_test.dart`; audit in every handler test |
| LF-INV-VER-001 | `command_gateway_test.dart`, `task_commands_test.dart`; versions only increase on restore (`profile_restore_test.dart`) |
| LF-INV-SEC-001/002 | `storage_security_test.dart`, key never in db; offline session does not lock (ADR-0024 tests) |
| LF-INV-SEC-010 | `profile_export_test.dart` (decrypted, versioned, checksummed, includes tombstones and audit; guard that every table is exported) |
| LF-INV-SEC-011 | `local_store_test.dart`, `storage_security_test.dart` |
| LF-INV-SYNC-004 (tombstone write) | `task_commands_test.dart`; tombstones round-trip in export; overwrite and undo tombstone instead of deleting (`profile_restore_test.dart`) |

## Fitness functions

| FF | How it is checked |
|---|---|
| FF-ARCH-01 pure domain | `tools/fitness/ff_arch_01_pure_domain.dart` |
| FF-ARCH-04 UI isolation | `tools/fitness/ff_arch_04_ui_isolation.dart` (ui depends on application and foundation only) |
| FF-ARCH-06 atomic set | `tools/fitness/ff_arch_06_09.dart` (static guards + tagged `atomic_set_test.dart`) |
| FF-ARCH-09 authorize before apply | same script (single `handler.apply` call site, authorize-before-apply order, governance writes inside the transaction + tagged `authorization_gate_test.dart`) |

The FF-ARCH-06/09 guards were mutation-tested: removing the transaction wrapper, moving authorization after apply, adding a second apply call site, and an unregistered handler each make the script fail.

## Encryption decision (P01 exit-gate decision)
Chosen: **Windows is encrypted too**, with a plain build only as an explicit fallback flag (ADR-0022). Risk R-ENCRYPTION-WINDOWS is closed for the MVP.

## Additional P01 decisions recorded
ADR-0021 to ADR-0025: encryption posture, Windows encryption, per-profile stores and registry, sign-out lock, export and restore.

## Known limits carried out of P01
- The sign-out lock is application-level, not cryptographic (ADR-0024). Crypto lock waits for OQ-DATA-3 (b) or (c) in P04.
- Export is unencrypted by design in the MVP (ADR-0025); passphrase export is open.
- OQ-S9: partial move of guest data into an account.
- OQ-S8: binding a profile to an account that already has cloud data (P04).
- Sign-in uses email and GitHub; other providers are not in P01.

## Test counts at T7b
foundation 3, domain 17, application 3, infrastructure 146 (incl. export, 21 restore, 2 atomic-set, 8 authorization), ui 68, app 11.

## Owner sign-off
- [x] T7 device check (Windows and Android): export warns and saves; tampered or newer file rejected (owner, 2026-11-07). Restore-as-copy was rejected by the owner and replaced by T7b.
- [ ] T7b device check (Windows and Android): identical file says nothing to restore; overwrite and merge options; hierarchy question; undo last restore; a file of a profile not on the device becomes a new profile.
- [ ] CI green on the T7 branch.
- [ ] Owner approves P01 as done.
