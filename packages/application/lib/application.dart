/// LifeFlow application layer (P01): the command envelope, the command gateway
/// contract (the single mutation path, ADR-0011/0014), the authorization port,
/// and the handler/transaction abstractions. No Flutter, no database.
library application;

export 'src/auth.dart';
export 'src/command.dart';
export 'src/ports.dart';
