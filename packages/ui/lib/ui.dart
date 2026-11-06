/// LifeFlow UI (P01). Adaptive shell, view models (Riverpod) and routes
/// (go_router) per docs/architecture/ui-ux-architecture.md and ADR-0019.
/// Depends on `application` ports only, never on infrastructure, Drift or
/// domain internals (FF-ARCH-04). Business logic never lives here (AP-12).
library ui;

export 'src/layout.dart';
export 'src/messages.dart';
export 'src/providers.dart';
export 'src/router.dart';
export 'src/shell.dart';
export 'src/task_tree.dart';
