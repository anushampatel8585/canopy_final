import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';
import 'settings_service.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _platformAvailable = false;

  static const int _missedHabitCheckinId = 999000;

  static int generateNotificationId(
    String habitId,
    String timeString,
    int weekday,
  ) {
    int hash = 0;
    final String source = '$habitId|$timeString|$weekday';

    for (final int codeUnit in source.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }

    return hash;
  }

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('Could not set timezone "$timeZoneName": $e');
      }
    } catch (e) {
      debugPrint('Could not read device timezone: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
    );

    try {
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      _platformAvailable = true;
    } catch (e) {
      _platformAvailable = false;
      debugPrint('Notification plugin unavailable: $e');
    }

    _initialized = true;
  }

  Future<bool> requestNotificationPermission() async {
    await init();

    if (!_platformAvailable) {
      return false;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      return false;
    }

    final bool? granted =
        await androidPlugin.requestNotificationsPermission();

    return granted ?? false;
  }

  Future<bool> requestExactAlarmPermission() async {
    await init();

    if (!_platformAvailable) {
      return false;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      return false;
    }

    final bool? granted = await androidPlugin.requestExactAlarmsPermission();

    return granted ?? false;
  }

  Future<void> sendTestNotification() async {
    await init();

    if (!_platformAvailable) {
      debugPrint('Test notification skipped: plugin unavailable.');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'canopy_test_channel',
      'CANOPY Test Notifications',
      channelDescription: 'Test notifications from CANOPY.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notifications.show(
      999999,
      'CANOPY',
      'Notifications are working.',
      notificationDetails,
    );
  }

  Future<void> scheduleHabitReminders(Habit habit) async {
    await init();

    if (!_platformAvailable) {
      debugPrint(
        'Skipping reminder scheduling for "${habit.name}": '
        'notification plugin unavailable.',
      );
      return;
    }

    // The global switch must override per-habit reminder settings.
    if (!SettingsService().remindersEnabled ||
        !habit.reminderEnabled ||
        habit.reminderTimes.isEmpty) {
      await cancelHabitReminders(habit);
      return;
    }

    await cancelHabitReminders(habit);

    switch (habit.frequencyType) {
      case FrequencyType.specificDays:
        for (final int weekday in habit.selectedDays) {
          for (final String timeString in habit.reminderTimes) {
            await _scheduleWeeklyHabitReminder(
              habit,
              timeString,
              weekday,
            );
          }
        }
        break;

      case FrequencyType.daily:
        for (final String timeString in habit.reminderTimes) {
          await _scheduleDailyHabitReminder(
            habit,
            timeString,
          );
        }
        break;

      case FrequencyType.custom:
      case FrequencyType.noFixedFrequency:
        // These modes do not define machine-readable weekdays. Their reminder
        // times are daily nudges, as explained in the schedule UI.
        for (final String timeString in habit.reminderTimes) {
          await _scheduleDailyHabitReminder(habit, timeString);
        }
        break;
    }
  }

  Future<void> _scheduleDailyHabitReminder(
    Habit habit,
    String timeString,
  ) async {
    final List<String> parts = timeString.split(':');

    if (parts.length != 2) {
      return;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return;
    }

    final int notificationId = generateNotificationId(
      habit.id,
      timeString,
      0,
    );

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'canopy_habit_reminders',
      'CANOPY Habit Reminders',
      channelDescription: 'Reminders for CANOPY habits.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      notificationId,
      habit.name,
      'Time to work on your habit.',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _scheduleWeeklyHabitReminder(
    Habit habit,
    String timeString,
    int weekday,
  ) async {
    final List<String> parts = timeString.split(':');

    if (parts.length != 2) {
      return;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return;
    }

    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      return;
    }

    final int notificationId = generateNotificationId(
      habit.id,
      timeString,
      weekday,
    );

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    int daysUntil = weekday - now.weekday;

    if (daysUntil < 0) {
      daysUntil += 7;
    }

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysUntil,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'canopy_habit_reminders',
      'CANOPY Habit Reminders',
      channelDescription: 'Reminders for CANOPY habits.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      notificationId,
      habit.name,
      'Time to work on your habit.',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelHabitReminders(Habit habit) async {
    await init();

    if (!_platformAvailable) {
      return;
    }

    for (final String timeString in habit.reminderTimes) {
      final int dailyId = generateNotificationId(
        habit.id,
        timeString,
        0,
      );

      await _notifications.cancel(dailyId);

      for (int weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++) {
        final int weeklyId = generateNotificationId(
          habit.id,
          timeString,
          weekday,
        );

        await _notifications.cancel(weeklyId);
      }
    }
  }

  Future<void> cancelAllHabitReminders(List<Habit> habits) async {
    for (final habit in habits) {
      await cancelHabitReminders(habit);
    }
  }

  Future<void> syncAllHabitNotifications(List<Habit> habits) async {
    await init();

    if (!_platformAvailable) {
      return;
    }

    // Reconcile from the current repository state. This removes stale IDs
    // left by deleted habits or older reminder-time configurations before
    // recreating reminders for habits that still exist.
    await cancelAllPendingHabitReminderNotifications();

    // The global switch controls ordinary habit reminders only. The missed-
    // habit check-in has its own setting and is intentionally untouched.
    if (!SettingsService().remindersEnabled) {
      return;
    }

    for (final Habit habit in habits) {
      await scheduleHabitReminders(habit);
    }
  }

  /// Cancels every pending ordinary habit reminder, including stale IDs left
  /// behind by earlier edits. The missed-habit check-in and test notification
  /// are deliberately preserved because they are separate notification types.
  Future<void> cancelAllPendingHabitReminderNotifications() async {
    await init();
    if (!_platformAvailable) return;

    final pending = await _notifications.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id == _missedHabitCheckinId || request.id == 999999) {
        continue;
      }
      await _notifications.cancel(request.id);
    }
  }

  Future<void> scheduleMissedHabitCheckin(List<Habit> habits) async {
    await init();

    if (!_platformAvailable) {
      return;
    }

    await _notifications.cancel(_missedHabitCheckinId);

    final settings = SettingsService();
    if (!settings.missedHabitAlertsEnabled) return;

    final today = DateTime.now();
    final List<Habit> incompleteHabits = habits.where((habit) {
      return habit.isScheduledOn(today) && !habit.isCompletedOn(today);
    }).toList();

    if (incompleteHabits.isEmpty) {
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    final timeParts = settings.eveningCheckinTime.split(':');
    if (timeParts.length != 2) return;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null ||
        hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return;
    }

    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      return;
    }

    final names = incompleteHabits.take(3).map((habit) => habit.name).join(', ');
    final remaining = incompleteHabits.length - incompleteHabits.length.clamp(0, 3);
    final String body = remaining > 0
        ? '$names and $remaining more still need attention today.'
        : 'Still to complete: $names';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'canopy_missed_habits',
      'CANOPY Missed Habit Alerts',
      channelDescription: 'Evening reminders for incomplete CANOPY habits.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      _missedHabitCheckinId,
      'CANOPY Check-in',
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
      'Notification tapped. Payload: ${response.payload}',
    );
  }
}