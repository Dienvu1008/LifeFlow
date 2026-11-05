# ADR-0019: UI state management (Riverpod) and navigation (go_router)

- Status: Accepted (owner to confirm)
- Date: 2026-11-04
- Deciders: Architecture team
- Evidence: [../architecture/ui-ux-architecture.md](../architecture/ui-ux-architecture.md), [technical-stack.md](../architecture/technical-stack.md), [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) (legacy: mixed BLoC/Cubit/ChangeNotifier, index-based navigation); AP-12

## Context
The legacy app mixed BLoC, Cubit and ChangeNotifier and used a single integer index plus ~40 imperative pushes for navigation (assessment). LifeFlow needs one state-management approach (AP-12) and a declarative router for adaptive multi-pane UI, with licenses compatible with ADR-0018.

## Options (state management)
1. Riverpod (MIT).
2. BLoC/flutter_bloc (MIT).
3. Mixed (legacy) — rejected (AP-12).

## Options (navigation)
1. go_router (BSD-3, Flutter-maintained).
2. Imperative Navigator only — rejected (no route table, poor for adaptive/deep-link).
3. auto_route (third-party).

## Decision
- **State management: Riverpod** (`flutter_riverpod`, MIT, VS-28). One approach app-wide. UI state (view models/providers) is never the source of truth for domain data; domain state comes from the application layer via repositories/queries (AP-12, NFR-UX-02). Business logic stays out of widgets.
- **Navigation: go_router** (BSD-3, VS-27). A declarative route table supports adaptive layouts and (later) deep links.

Both licenses are ADR-0018-compliant. BLoC was a reasonable alternative (also MIT); Riverpod is chosen for compile-safe dependency injection and testability without a `BuildContext`, which suits the pure application/domain layering. This is a preference, not a correctness issue; revisit only if it causes friction.

## Consequences
- Pro: one mental model; view models are plain, testable; DI is explicit.
- Pro: declarative routing enables the pane-based desktop layout and mobile tabs from one route table.
- Con: the team learns Riverpod's provider model; acceptable.
- Con: porting any legacy BLoC code means rewriting its state layer (expected under ADR-0002).

## Follow-ups
- ui-ux-architecture.md details the view-model boundary and adaptive navigation.
- Batch 4: a fitness function that domain/application code does not import Flutter (FF-ARCH-01) keeps business logic out of the UI layer.
