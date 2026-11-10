// P02 T7 (ADR-0034): the device side of reminders, on
// flutter_local_notifications (spike S-05: fires with the app closed on
// Windows and Android). The app only hands over the plan; what to remind of
// and when is decided in infrastructure + time_kernel.
import 'dart:io';

import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Reminders of your tasks and events',
    importance: Importance.high,
    priority: Priority.high,
  ),
  windows: WindowsNotificationDetails(),
);

/// Marks LifeFlow's reminders and carries what was scheduled, so a sync can
/// keep the unchanged ones: `lf1|<key>|<utc millis>`.
String payloadOf(PlannedReminder r) => 'lf1|${r.key}|${r.at.millis}';

/// What a sync does with the pending notifications: cancel the ids that are
/// not planned (or changed), schedule the planned ones that are not pending
/// as they are. Pure, so it is tested without a device.
({List<int> cancel, List<PlannedReminder> schedule}) diffPending(
    List<({int id, String? payload, String? title, String? body})> pending, List<PlannedReminder> planned) {
  final want = {for (final p in planned) p.id: p};
  final keep = <int>{};
  final cancel = <int>[];
  for (final p in pending) {
    final w = want[p.id];
    if (w != null && p.payload == payloadOf(w) && p.title == w.title && p.body == w.body) {
      keep.add(p.id);
    } else {
      cancel.add(p.id);
    }
  }
  return (cancel: cancel, schedule: [for (final p in planned) if (!keep.contains(p.id)) p]);
}

class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler._(this._plugin, this._ready);

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _ready;

  /// Sets up the plugin once at startup. Never throws: a device that cannot
  /// show notifications gets a scheduler that reports it.
  static Future<LocalNotificationScheduler> initialize({void Function(String message)? log}) async {
    final plugin = FlutterLocalNotificationsPlugin();
    var ready = false;
    if (Platform.isAndroid || Platform.isWindows) {
      try {
        ready = await plugin.initialize(
              settings: const InitializationSettings(
                android: AndroidInitializationSettings('@mipmap/ic_launcher'),
                windows: WindowsInitializationSettings(
                  appName: 'LifeFlow',
                  appUserModelId: 'LifeFlow.App',
                  guid: '3f6b2d1e-8a4c-4e57-9b0d-6c2a1f7e5d93',
                ),
              ),
            ) ??
            false;
      } catch (e) {
        log?.call('notifications unavailable: $e');
      }
    }
    return LocalNotificationScheduler._(plugin, ready);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> sync(List<PlannedReminder> planned) async {
    if (!_ready) return;
    final pending = await _plugin.pendingNotificationRequests();
    final d = diffPending([
      for (final p in pending) (id: p.id, payload: p.payload, title: p.title, body: p.body),
    ], planned);
    for (final id in d.cancel) {
      await _plugin.cancel(id: id);
    }
    if (d.schedule.isEmpty) return;
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    for (final r in d.schedule) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: payloadOf(r),
        // An instant: scheduled in UTC, shown in the device's local time.
        scheduledDate: tz.TZDateTime.from(r.at.utc, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode:
            exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    if (kDebugMode) debugPrint('[reminders] pending ${planned.length}, changed ${d.schedule.length}');
  }

  @override
  Future<ReminderStatus> status() async {
    if (!_ready) return const ReminderStatus(supported: false, allowed: false);
    final a = _android;
    if (a == null) return const ReminderStatus(supported: true, allowed: true); // Windows: no permission step
    return ReminderStatus(
      supported: true,
      allowed: await a.areNotificationsEnabled() ?? false,
      exactAllowed: await a.canScheduleExactNotifications() ?? false,
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final a = _android;
    if (a == null) return true;
    return await a.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> requestExact() async {
    await _android?.requestExactAlarmsPermission();
  }
}

/// Where the platform has no scheduled notifications (and in tests).
class NoDeviceReminders implements ReminderScheduler {
  const NoDeviceReminders();
  @override
  Future<void> sync(List<PlannedReminder> planned) async {}
  @override
  Future<ReminderStatus> status() async => const ReminderStatus(supported: false, allowed: false);
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> requestExact() async {}
}
