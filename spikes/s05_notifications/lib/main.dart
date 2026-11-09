// Spike S-05 (P02 T0): local notifications on Windows and Android.
// Throwaway code on branch spike/s05-notifications; results are recorded in
// docs/spikes/spike-results.md. Every result line is printed with "S05:".
//
// Questions:
//  1. Does an immediate notification show?
//  2. Does a scheduled one fire at the minute, with the app open, in the
//     background, and closed?
//  3. Can a pending scheduled one be cancelled (needed to remove reminders
//     of trashed or changed items)?
//  4. Can many be pending at once (rolling reminder horizon)?
//  5. Does the device report its IANA zone, and is it in the tz database?
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final plugin = FlutterLocalNotificationsPlugin();
final log = ValueNotifier<List<String>>([]);

void say(String s) {
  final line = '${DateTime.now().toIso8601String().substring(11, 19)} $s';
  debugPrint('S05: $line');
  log.value = [line, ...log.value];
}

const details = NotificationDetails(
  android: AndroidNotificationDetails('s05', 'S-05 spike',
      importance: Importance.max, priority: Priority.high),
  windows: WindowsNotificationDetails(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    final known = tz.timeZoneDatabase.locations.containsKey(info.identifier);
    say('device zone ${info.identifier} known=$known');
    if (known) tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e) {
    say('zone ERROR $e');
  }
  try {
    final ok = await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: 'LifeFlow S-05',
          appUserModelId: 'LifeFlow.Spike.S05',
          guid: '7c1f3a52-9d4e-4b8a-a0f2-5e6d7c8b9a01',
        ),
      ),
      onDidReceiveNotificationResponse: (r) => say('tapped id=${r.id} payload=${r.payload}'),
    );
    say('initialize -> $ok');
    final launch = await plugin.getNotificationAppLaunchDetails();
    say('launched by notification: ${launch?.didNotificationLaunchApp} id=${launch?.notificationResponse?.id}');
  } catch (e) {
    say('initialize ERROR $e');
  }
  runApp(const SpikeApp());
  if (const bool.fromEnvironment('S05_AUTO')) unawaited(autoRun());
  if (const bool.fromEnvironment('S05_SHOW')) unawaited(showRun());
}

/// Re-check of "show now" on Windows: after the window has settled, twice.
Future<void> showRun() async {
  for (final wait in [8, 15]) {
    await Future<void>.delayed(Duration(seconds: wait));
    try {
      await plugin.show(id: 2 + wait, title: 'S-05 show after ${wait}s', body: 'immediate', notificationDetails: details);
      say('shown id=${2 + wait}');
    } catch (e) {
      say('show ERROR $e');
    }
  }
  await Future<void>.delayed(const Duration(seconds: 10));
  say('exiting now');
  exit(0);
}

/// Scripted run for Windows (no one to tap the buttons):
///  - show now (id 1)
///  - id 10 at +1 min   -> fires while the app is OPEN
///  - id 12 at +90 s, cancelled at once -> must never show
///  - 60 pending, then cancelAll -> pending must be 0
///  - id 11 at +3 min   -> fires after the app has EXITED (at +80 s)
Future<void> autoRun() async {
  await Future<void>.delayed(const Duration(seconds: 2));
  try {
    await plugin.show(id: 1, title: 'S-05 now', body: 'immediate', notificationDetails: details);
    say('shown id=1');
  } catch (e) {
    say('show ERROR $e');
  }
  await schedule(10, const Duration(minutes: 1), 'S-05 +1 min (app open)');
  await schedule(12, const Duration(seconds: 90), 'S-05 SHOULD NOT APPEAR');
  try {
    await plugin.cancel(id: 12);
    say('cancel id=12 done');
  } catch (e) {
    say('cancel ERROR $e');
  }
  await pending();
  for (var i = 0; i < 60; i++) {
    await schedule(100 + i, Duration(minutes: 30 + i), 'S-05 bulk $i');
  }
  await pending();
  try {
    await plugin.cancelAll();
    say('cancelAll done');
  } catch (e) {
    say('cancelAll ERROR $e');
  }
  await pending();
  await schedule(11, const Duration(minutes: 3), 'S-05 +3 min (app closed)');
  await schedule(10, const Duration(minutes: 1), 'S-05 +1 min (app open)');
  await pending();
  await Future<void>.delayed(const Duration(seconds: 80));
  say('exiting now');
  exit(0);
}

AndroidFlutterLocalNotificationsPlugin? get android =>
    plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

Future<AndroidScheduleMode> mode() async {
  final exact = await android?.canScheduleExactNotifications() ?? true;
  return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
}

Future<void> schedule(int id, Duration after, String title) async {
  final at = tz.TZDateTime.now(tz.local).add(after);
  try {
    await plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      notificationDetails: details,
      androidScheduleMode: await mode(),
      title: title,
      body: 'scheduled for ${at.toIso8601String().substring(11, 19)} (${tz.local.name})',
      payload: 'id$id',
    );
    say('scheduled id=$id at ${at.toIso8601String().substring(11, 19)}');
  } catch (e) {
    say('schedule id=$id ERROR $e');
  }
}

Future<void> pending() async {
  try {
    final p = await plugin.pendingNotificationRequests();
    say('pending=${p.length} ids=${p.map((e) => e.id).take(12).toList()}${p.length > 12 ? '...' : ''}');
  } catch (e) {
    say('pending ERROR $e');
  }
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <(String, Future<void> Function())>[
      ('1 Permissions', () async {
        final n = await android?.requestNotificationsPermission();
        final x = await android?.requestExactAlarmsPermission();
        final e = await android?.areNotificationsEnabled();
        final c = await android?.canScheduleExactNotifications();
        say('permissions notif=$n exact=$x enabled=$e canExact=$c');
      }),
      ('2 Show now', () async {
        try {
          await plugin.show(id: 1, title: 'S-05 now', body: 'immediate', notificationDetails: details);
          say('shown id=1');
        } catch (e) {
          say('show ERROR $e');
        }
      }),
      ('3 Schedule +1 min', () => schedule(10, const Duration(minutes: 1), 'S-05 +1 min')),
      ('4 Schedule +2 min', () => schedule(11, const Duration(minutes: 2), 'S-05 +2 min (close app now)')),
      ('5 Schedule +3 then cancel', () async {
        await schedule(12, const Duration(minutes: 3), 'S-05 SHOULD NOT APPEAR');
        try {
          await plugin.cancel(id: 12);
          say('cancel id=12 done');
        } catch (e) {
          say('cancel ERROR $e');
        }
        await pending();
      }),
      ('6 Schedule 60 (+5..+64 min)', () async {
        for (var i = 0; i < 60; i++) {
          await schedule(100 + i, Duration(minutes: 5 + i), 'S-05 bulk $i');
        }
        await pending();
      }),
      ('7 Pending', pending),
      ('8 Cancel all', () async {
        try {
          await plugin.cancelAll();
          say('cancelAll done');
        } catch (e) {
          say('cancelAll ERROR $e');
        }
        await pending();
      }),
    ];
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('S-05 notifications')),
        body: Column(
          children: [
            for (final (label, run) in actions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(onPressed: run, child: Text(label)),
                ),
              ),
            const Divider(),
            Expanded(
              child: ValueListenableBuilder<List<String>>(
                valueListenable: log,
                builder: (_, lines, __) => ListView(
                  padding: const EdgeInsets.all(8),
                  children: [for (final l in lines) Text(l, style: const TextStyle(fontSize: 12))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
