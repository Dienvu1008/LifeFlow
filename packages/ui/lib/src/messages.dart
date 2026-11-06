import 'package:application/application.dart';

/// User-facing text for a failed command. P01 ships English only; localization
/// is added when the string set stabilizes. Never includes ids or secrets.
String describeFailure(CommandFailure f) {
  switch (f.kind) {
    case CommandFailureKind.validationFailed:
      return f.reason == null ? 'That change is not allowed.' : _sentence(f.reason!);
    case CommandFailureKind.unauthorized:
    case CommandFailureKind.policyDenied:
      return 'You do not have permission to do that.';
    case CommandFailureKind.versionConflict:
      return 'This item changed in the meantime. Please try again.';
    case CommandFailureKind.notFound:
      return 'That item no longer exists.';
    case CommandFailureKind.duplicateOperation:
      return 'That action was already applied.';
  }
}

String _sentence(String s) {
  final t = s.trim();
  if (t.isEmpty) return 'That change is not allowed.';
  final cap = t[0].toUpperCase() + t.substring(1);
  return cap.endsWith('.') ? cap : '$cap.';
}
