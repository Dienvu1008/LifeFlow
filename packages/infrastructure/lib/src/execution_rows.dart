// P03 T2 (schema v5, ADR-0037): ids and well-formedness of the execution,
// measurement, habit and goal rows. Used by the command handlers (T3–T5)
// and by export validation, where a file is untrusted (SR-14).
import 'package:foundation/foundation.dart' show LocalDate;

import 'record_kinds.dart';

/// A session's execution record: at most one per session (LF-INV-EXEC-004).
String executionRecordIdOf(String sessionId) => 'session:$sessionId';

/// The stored result of a period ('period': its first day, or 'once') or of
/// a habit occurrence ('occurrence': its original date).
String periodResultIdOf(String taskId, String periodKey, String kind) => 'task:$taskId@$periodKey#$kind';

/// One link per goal and item.
String goalLinkIdOf(String goalId, String itemType, String itemId) => '$goalId|$itemType:$itemId';

const focusModes = {'pomodoro', 'stopwatch'};
const focusStates = {'running', 'paused', 'ended', 'cancelled', 'unrecoverable'};
const measurementSources = {'manual', 'focusSession', 'import'};
const periodKinds = {'period', 'occurrence'};
const outcomes = {'done', 'missed', 'achieved', 'notAchieved', 'noData'};
const goalKinds = {'goal', 'project'};
const goalStatuses = {'active', 'done', 'archived'};
const aggregations = {'sum', 'max', 'latest', 'average'};

bool _isDate(Object? v) {
  if (v is! String) return false;
  try {
    LocalDate.parse(v);
    return true;
  } catch (_) {
    return false;
  }
}

int _ms(Object? v) => v is int ? v : (v is num ? v.toInt() : -1);

/// Why the P03 rows of [records] (rows by kind name, as exported) cannot be
/// restored, or null. References are checked by the caller.
String? executionRowsError(Map<String, List<Row>> records) {
  for (final t in records['task'] ?? const <Row>[]) {
    final a = t['targetAggregation'];
    if (a != null && !aggregations.contains(a)) return 'a task has an unknown aggregation';
    final since = t['trackedSince'];
    if (since != null && !_isDate(since)) return 'a task has a bad tracking start';
  }
  final sessions = {for (final s in records['focusSession'] ?? const <Row>[]) s['id'] as String: s};
  for (final s in sessions.values) {
    if (!focusModes.contains(s['mode'])) return 'a focus session has an unknown mode';
    if (!focusStates.contains(s['state'])) return 'a focus session has an unknown state';
    if (_ms(s['pausedMs']) < 0) return 'a focus session has a negative pause';
    final planned = s['plannedMs'];
    if (s['mode'] == 'pomodoro' && (planned == null || _ms(planned) <= 0)) {
      return 'a pomodoro has no planned interval';
    }
    final od = s['occurrenceDate'];
    if (od != null && !_isDate(od)) return 'a focus session has a bad date';
  }
  for (final r in records['executionRecord'] ?? const <Row>[]) {
    final sid = r['sessionId'];
    if (sid != null && r['id'] != executionRecordIdOf(sid as String)) {
      return 'an execution record id does not match its session';
    }
    if (_ms(r['focusMs']) < 0) return 'an execution record has a negative time';
    final start = r['actualStart'], end = r['actualEnd'];
    if (start is int && end is int && end < start) return 'an execution record ends before it starts';
    final od = r['occurrenceDate'];
    if (od != null && !_isDate(od)) return 'an execution record has a bad date';
  }
  final measurements = {for (final m in records['measurement'] ?? const <Row>[]) m['id'] as String: m};
  for (final m in measurements.values) {
    final v = m['value'];
    if (v is! num || !v.isFinite || v < 0) return 'a measurement value must be 0 or more';
    if (!_isDate(m['localDate'])) return 'a measurement has a bad date';
    if (!measurementSources.contains(m['source'])) return 'a measurement has an unknown source';
    final sup = m['supersedesId'];
    if (sup != null) {
      final old = measurements[sup];
      if (old == null || old['taskId'] != m['taskId']) return 'a correction points to an unknown measurement';
      if (sup == m['id']) return 'a measurement corrects itself';
    }
  }
  for (final r in records['periodResult'] ?? const <Row>[]) {
    if (!periodKinds.contains(r['kind'])) return 'a period result has an unknown kind';
    if (!outcomes.contains(r['outcome'])) return 'a period result has an unknown outcome';
    final key = r['periodKey'] as String;
    if (key != 'once' && !_isDate(key)) return 'a period result has a bad period';
    if (r['id'] != periodResultIdOf(r['taskId'] as String, key, r['kind'] as String)) {
      return 'a period result id does not match its task and period';
    }
  }
  for (final g in records['goal'] ?? const <Row>[]) {
    if (!goalKinds.contains(g['kind'])) return 'a goal has an unknown kind';
    if (!goalStatuses.contains(g['status'])) return 'a goal has an unknown status';
    for (final f in ['startDate', 'targetDate']) {
      if (g[f] != null && !_isDate(g[f])) return 'a goal has a bad date';
    }
  }
  for (final m in records['milestone'] ?? const <Row>[]) {
    if (m['dueDate'] != null && !_isDate(m['dueDate'])) return 'a milestone has a bad date';
  }
  for (final l in records['goalLink'] ?? const <Row>[]) {
    final type = l['itemType'];
    if (type != 'task' && type != 'event') return 'a goal link has an unknown item type';
    if (l['id'] != goalLinkIdOf(l['goalId'] as String, type as String, l['itemId'] as String)) {
      return 'a goal link id does not match its goal and item';
    }
  }
  return null;
}
