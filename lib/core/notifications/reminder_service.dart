// Local reminders: the daily puzzle and "your lives are full".
//
// Why one-shots for the next 7 days instead of a repeating alarm: we can skip
// today once the daily is solved, name the day's puzzle, and re-plan on every
// launch/resume/solve. Inexact delivery is enough, so no exact-alarm permission.

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/level_config.dart';
import '../../domain/rules.dart';
import '../../domain/save_data.dart';

class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _dailyBase = 100;
  static const _livesId = 200;

  static bool get supported =>
      (Platform.isAndroid || Platform.isIOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    final ok = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = ok ?? false;
  }

  /// Asks for permission to notify (Android 13+, iOS). Returns whether it is granted.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    if (Platform.isAndroid) {
      final a = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await a?.requestNotificationsPermission() ?? true;
    }
    final i = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await i?.requestPermissions(alert: true, sound: true) ?? false;
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Daily puzzle and lives reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Re-plans every reminder from the current save.
  Future<void> sync(SaveData s, DateTime now) async {
    await init();
    if (!_ready) return;
    for (var i = 0; i < 7; i++) {
      await _plugin.cancel(id: _dailyBase + i);
    }
    await _plugin.cancel(id: _livesId);

    if (s.settings.dailyReminder) {
      final solvedToday = s.daily.containsKey(dayKey(now));
      for (var i = 0; i < 7; i++) {
        final day = DateTime(now.year, now.month, now.day + i);
        final at = day.add(Duration(minutes: s.settings.reminderMinutes));
        if (!at.isAfter(now) || (i == 0 && solvedToday)) continue;
        final game = LevelConfig.daily(day).game;
        await _schedule(
          _dailyBase + i,
          at,
          "Today's puzzle is ${game.title}",
          s.profile.name.isEmpty
              ? 'A fresh puzzle is waiting on ${game.island}.'
              : '${s.profile.name}, a fresh puzzle is waiting on ${game.island}.',
        );
      }
    }
    if (s.settings.livesAlert && !s.settings.relaxed) {
      final full = EconomyRules.fullAt(s.economy, now);
      if (full != null && full.isAfter(now)) {
        await _schedule(
          _livesId,
          full,
          'Your lives are full',
          'All three hearts are back. Ready for the next level?',
        );
      }
    }
  }

  Future<void> _schedule(int id, DateTime at, String title, String body) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        title: title,
        body: body,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }
}

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);
