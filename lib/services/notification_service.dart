import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/meal.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  static Future<void> init() async {
    tz.initializeTimeZones();

    // Get timezone from device
    final timezoneName = _getDeviceTimezone();
    debugPrint('Device timezone: $timezoneName');
    try {
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      debugPrint('Timezone $timezoneName not found, falling back to Europe/Oslo');
      tz.setLocalLocation(tz.getLocation('Europe/Oslo'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const channel = AndroidNotificationChannel(
      'meal_channel',
      'Meal Reminders',
      description: 'Daily meal notifications',
      importance: Importance.high,
      playSound: false,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    // Request permissions (Android 13+)
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  // Test notification - fires immediately
  static Future<void> testNotification() async {
    debugPrint('Showing immediate test notification');

    await _plugin.show(
      9999,
      'Test Notification',
      'Notifications are working!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_channel',
          'Meal Reminders',
          channelDescription: 'Daily meal notifications',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        ),
      ),
    );
  }

  // Check if exact alarms are permitted
  static Future<bool> canScheduleExactAlarms() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canSchedule = await androidPlugin?.canScheduleExactNotifications() ?? false;
    debugPrint('Can schedule exact alarms: $canSchedule');
    return canSchedule;
  }

  // Test scheduled notification - fires in 1 minute
  static Future<String> testScheduledNotification() async {
    final canSchedule = await canScheduleExactAlarms();
    if (!canSchedule) {
      debugPrint('ERROR: Exact alarms not permitted!');
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
      return 'Exact alarms not permitted. Please enable in Settings > Apps > day_planner > Alarms & reminders';
    }

    // Cancel all existing to avoid conflicts
    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(minutes: 1));
    debugPrint('Current time: $now');
    debugPrint('Scheduling test for: $scheduledTime');

    try {
      await _plugin.zonedSchedule(
        9998,
        'Scheduled Test',
        'This fired 1 minute after scheduling!',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_channel',
            'Meal Reminders',
            channelDescription: 'Daily meal notifications',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Notification scheduled successfully');
      return 'Scheduled for ~1 minute from now (${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')})';
    } catch (e) {
      debugPrint('Error scheduling: $e');
      return 'Error: $e';
    }
  }

  static String _getDeviceTimezone() {
    // Get timezone name from platform
    final timezoneName = DateTime.now().timeZoneName;
    debugPrint('System timezone name: $timezoneName');

    // Map common abbreviations to IANA names
    final tzMap = {
      'CET': 'Europe/Oslo',
      'CEST': 'Europe/Oslo',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
    };

    return tzMap[timezoneName] ?? 'Europe/Oslo';
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }

  // Schedule only today's meals
  static Future<void> scheduleTodaysMeals({
    required List<Meal> meals,
    required bool vibrate,
  }) async {
    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    debugPrint('Scheduling ${meals.length} meals for today (${now.weekday})');

    int id = 0;
    for (final meal in meals) {
      final timeParts = meal.time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Skip if time has already passed
      if (scheduledDate.isBefore(now)) {
        debugPrint('Skipping ${meal.name} - time already passed');
        continue;
      }

      debugPrint('Scheduling ${meal.name} for $scheduledDate');

      await _plugin.zonedSchedule(
        id++,
        meal.name,
        'Time to eat: ${meal.name}',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_channel',
            'Meal Reminders',
            channelDescription: 'Daily meal notifications',
            importance: Importance.max,
            priority: Priority.max,
            playSound: false,
            enableVibration: vibrate,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Schedule daily refresh at 7am tomorrow
    await _scheduleDailyRefresh();
  }

  // Schedule a notification at 7am to trigger app refresh
  static Future<void> _scheduleDailyRefresh() async {
    final now = tz.TZDateTime.now(tz.local);
    var refreshTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      7, // 7am
      0,
    );

    // If 7am already passed today, schedule for tomorrow
    if (refreshTime.isBefore(now)) {
      refreshTime = refreshTime.add(const Duration(days: 1));
    }

    debugPrint('Scheduling daily refresh for $refreshTime');

    await _plugin.zonedSchedule(
      1000, // Fixed ID for refresh notification
      'Good morning!',
      'Your meal plan for today is ready',
      refreshTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_channel',
          'Meal Reminders',
          channelDescription: 'Daily meal notifications',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
