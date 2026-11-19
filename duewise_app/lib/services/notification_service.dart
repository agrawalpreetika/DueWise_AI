import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../features/subscriptions/subscription_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize Timezones for scheduled notifications
    tz.initializeTimeZones();

    // 2. Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS Settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap here if needed
      },
    );

    // Request permissions explicitly for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> printPendingNotifications() async {
    final List<PendingNotificationRequest> pendingNotifications =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();

    print('--- PENDING NOTIFICATIONS (${pendingNotifications.length}) ---');
    for (var notification in pendingNotifications) {
      print(
        'ID: ${notification.id} | Title: ${notification.title} | Scheduled Time: ${notification.payload ?? "No Payload"} | Body: ${notification.body}',
      );
    }
  }

  // Helper to generate a unique integer notification ID from string subscription ID, offset, and hour
  int _generateNotificationId(String subscriptionId, int offset, int hour) {
    return subscriptionId.hashCode ^ offset ^ hour;
  }

  // Schedule multiple reminders for a subscription (3 days before, 1 day before, and on due date at 9 AM and 6 PM)
  Future<void> scheduleSubscriptionReminders(Subscription sub) async {
    // If paused, do not schedule reminders
    if (sub.isPaused) return;

    final targetDate = sub.isFreeTrial
        ? (sub.trialEndDate ?? sub.nextDueDate)
        : sub.nextDueDate;

    const reminderOffsets = [
      3,
      1,
      0,
    ]; // 3 days before, 1 day before, on the day
    const targetHours = [9, 18]; // 9:00 AM and 6:00 PM (18:00)

    for (int daysBefore in reminderOffsets) {
      for (int hour in targetHours) {
        final notificationId = _generateNotificationId(
          sub.id,
          daysBefore,
          hour,
        );

        final scheduledTime = targetDate
            .subtract(Duration(days: daysBefore))
            .copyWith(hour: hour, minute: 0, second: 0, millisecond: 0);

        // If scheduled time is in the past, skip it
        if (scheduledTime.isBefore(DateTime.now())) continue;

        String titleText = sub.isFreeTrial
            ? 'Free Trial Ending: ${sub.title}'
            : 'Upcoming Bill: ${sub.title}';

        String bodyText = daysBefore == 0
            ? (sub.isFreeTrial
                  ? 'Your free trial for "${sub.title}" converts to a paid subscription today (₹${sub.amount.toInt()}).'
                  : 'Your bill "${sub.title}" of ₹${sub.amount.toInt()} is due today!')
            : (sub.isFreeTrial
                  ? 'Reminder: "${sub.title}" free trial ends in $daysBefore day(s).'
                  : 'Reminder: "${sub.title}" (₹${sub.amount.toInt()}) is due in $daysBefore day(s).');

        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
              'duewise_reminders',
              'Subscription Reminders',
              channelDescription:
                  'Notifications for upcoming subscription bills and trials',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
            );

        const DarwinNotificationDetails iosPlatformChannelSpecifics =
            DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            );

        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(
              android: androidPlatformChannelSpecifics,
              iOS: iosPlatformChannelSpecifics,
            );

        await flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          titleText,
          bodyText,
          tz.TZDateTime.from(scheduledTime, tz.local),
          platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: scheduledTime.toString(),
        );
      }
    }
  }

  // Cancel all associated reminders for a subscription ID (covers both 9 AM and 6 PM)
  Future<void> cancelSubscriptionReminders(String subscriptionId) async {
    const reminderOffsets = [3, 1, 0];
    const targetHours = [9, 18];
    for (int daysBefore in reminderOffsets) {
      for (int hour in targetHours) {
        final notificationId = _generateNotificationId(
          subscriptionId,
          daysBefore,
          hour,
        );
        await flutterLocalNotificationsPlugin.cancel(notificationId);
      }
    }
  }

  // Keep single notification support just in case (defaults to 9 AM)
  Future<void> scheduleSubscriptionReminder({
    required int id,
    required String title,
    required double amount,
    required DateTime scheduledDate,
    required int daysBefore,
    int hour = 9,
  }) async {
    final targetDate = scheduledDate
        .subtract(Duration(days: daysBefore))
        .copyWith(hour: hour, minute: 0, second: 0, millisecond: 0);

    if (targetDate.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'duewise_reminders',
          'Subscription Reminders',
          channelDescription:
              'Notifications for upcoming subscription bills and trials',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    String message = daysBefore == 0
        ? 'Your bill "$title" of ₹${amount.toInt()} is due today!'
        : 'Reminder: "$title" (₹${amount.toInt()}) is due in $daysBefore day(s).';

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Upcoming Payment: $title',
      message,
      tz.TZDateTime.from(targetDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Cancel single notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Instant Test Notification
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'duewise_test_channel',
          'Test Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      999,
      'DueWise Notifications Active! 🚀',
      'Your background and scheduled reminders are fully configured.',
      details,
    );
  }

  // Schedule a test notification for 2 minutes later
  Future<void> scheduleInstantTestNotification() async {
    // Current time se sirf 2 minute baad ka time set karein
    final testTime = DateTime.now().add(const Duration(minutes: 2));

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'duewise_test_channel',
          'Test Notifications',
          channelDescription: 'Testing background notification delivery',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      888, // Unique Test ID
      '⏰ 2-Minute Test Reminder',
      'Aapka ye test notification successfully trigger ho gaya hai!',
      tz.TZDateTime.from(testTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print("Test notification scheduled for: $testTime");
  }
}
