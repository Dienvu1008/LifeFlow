# ADR-0002: New repository with selective porting from `my_time_manager`

- Status: Accepted (owner decision)
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md), [../assessment/legacy-component-matrix.md](../assessment/legacy-component-matrix.md)

## Context
`my_time_manager` is a working app with a domain layer, AI layer and about 900 tests (approximate). It is built on a sqflite singleton with JSON-in-TEXT columns, a destructive v9 migration, no workspace/ownership concept, no sync-ready identity or versions, two recurrence systems, mixed state management, and Firebase-specific auth. LifeFlow needs workspaces, offline sync, governed mutation, and an explicit time model. The owner states no migration of old data is needed.

## Options
1. Evolve `my_time_manager` in place.
   - Pro: no port cost; keeps working app.
   - Con: persistence, identity and mutation path must be replaced under a running app; legacy debt (singleton DB, `app.dart` 1,199 lines, hand-written localization) stays in the way.
2. New repository; port selected pure-Dart logic and tests; rewrite persistence, identity, sync, state management, navigation.
   - Pro: clean boundaries from the start; the legacy app stays available as reference.
   - Con: duplicated effort for features that already exist; risk of losing subtle behavior if ports are careless.
3. New repository with no porting.
   - Con: discards verified logic (DST resolution, recurrence edge cases, AI safety tests).

## Decision
Option 2. The legacy repo is read-only reference. Ports follow these rules:
- Port pure-Dart logic with its tests first (candidates in the component matrix: `wall_clock_resolver`, day-matching of `RepeatRule`, progress calculators, AI core/policy/tool layering, prompt-injection tests).
- Port behavior as specification: translate comments to English, remove dependencies on sqflite and legacy models, and add tests before changing behavior.
- Do not port: `DatabaseManager`, JSON-blob schemas, `ads_mob`, `flutter_background_service`, `packages/time_manager`, Firebase auth, PKCE `plain`, `bypassAuth` default.
- License: legacy is Apache-2.0 and owned by the same author. Third-party code copied from elsewhere must keep its notices (check `NOTICE`).

## Consequences
- LifeFlow's first phases spend effort re-creating basics (tasks, lists) on the new model.
- A port log records each ported file, source path and commit, so provenance is traceable. [Proposal]
- No data migration tooling is built.
- Users of the legacy app are not migrated. [Assumption] This is acceptable; revisit if the legacy app has users who need their data.

## Follow-ups
- Define the port log format in the repository-structure batch.
- Re-verify that legacy tests pass before porting them (not verified in Batch 1).
