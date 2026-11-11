/// LifeFlow infrastructure (P01). The local Drift store with the
/// governance-ready schema (ADR-0009 shared columns; ADR-0011/0014 audit,
/// outbox, event log, dedupe) and an FTS5 index over task titles.
/// The domain layer never imports this; it reaches persistence via ports
/// (added in T2/T3). See docs/architecture/repository-structure.md, docs/data/.
library infrastructure;

export 'src/app_database.dart';
export 'src/schema.dart';
export 'src/command_gateway.dart';
export 'src/task_command_handler.dart';
export 'src/profile_store.dart';
export 'src/profile_command_handler.dart';
export 'src/storage_security.dart';
export 'src/local_store.dart';
export 'src/account_service.dart';
export 'src/registry_database.dart';
export 'src/profile_directory.dart';
export 'src/profile_export.dart';
export 'src/profile_restore.dart';
export 'src/record_kinds.dart';
export 'src/schedule_mapping.dart';
export 'src/schedule_inputs.dart';
export 'src/agenda_service.dart';
export 'src/calendar_service.dart';
export 'src/event_command_handlers.dart';
export 'src/data_transfer_service.dart';
export 'src/app_service_impl.dart';
export 'src/reminder_rows.dart';
export 'src/reminder_service.dart';
export 'src/execution_rows.dart';
export 'src/focus_command_handler.dart';
export 'src/focus_service.dart';
export 'src/habit_tracking.dart';
export 'src/task_target_ops.dart';
export 'src/measurement_command_handler.dart';
export 'src/habit_service.dart';
