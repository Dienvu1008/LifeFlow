/// LifeFlow application layer (P01): the command envelope, the command gateway
/// contract (the single mutation path, ADR-0011/0014), the authorization port,
/// and the handler/transaction abstractions. No Flutter, no database.
library application;

export 'src/ai.dart';
export 'src/ai_assistant.dart';
export 'src/ai_engine.dart';
export 'src/app_services.dart';
export 'src/attachments.dart';
export 'src/auth.dart';
export 'src/calendar.dart';
export 'src/command.dart';
export 'src/documents.dart';
export 'src/focus.dart';
export 'src/goals.dart';
export 'src/habits.dart';
export 'src/overview.dart';
export 'src/planning.dart';
export 'src/ports.dart';
export 'src/reading.dart';
export 'src/remote.dart';
export 'src/remote_spaces.dart';
export 'src/reminders.dart';
export 'src/search.dart';
export 'src/extra_times.dart';
export 'src/shelf.dart';
export 'src/spaces.dart';
export 'src/sync.dart';
