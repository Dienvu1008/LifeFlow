/// Time Kernel (ADR-0007, ADR-0010, ADR-0013, ADR-0028): stateless schedule,
/// recurrence and DST rules. Pure Dart; depends only on `foundation` and the
/// `timezone` database. Owns nothing persistent and emits no events.
library time_kernel;

export 'src/overlap.dart';
export 'src/recurrence.dart';
export 'src/schedule.dart';
export 'src/zones.dart';
