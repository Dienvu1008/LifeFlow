/// LifeFlow domain (P01). Pure domain models, rules and events per bounded
/// context. Depends only on foundation + time_kernel (no Flutter, no database,
/// FF-ARCH-01). Task Management lands in P01; other contexts in their phases.
library domain;

export 'src/task.dart';
