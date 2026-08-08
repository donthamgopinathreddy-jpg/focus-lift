import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages local rest completion alerts when Focus Lift is backgrounded.
class NotificationService {
  static const int _restNotificationId = 101;
  static const String _channelId = 'focus_lift_rest_channel';
  static const String _channelName = 'Rest Timer Alerts';
  static const String _channelDescription =
      'Alerts when your workout rest interval completes.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static Future<NotificationService> create() async {
    final service = NotificationService();
    await service.initialize();
    return service;
  }

  /// Initializes notification channels and platform handlers.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(initSettings);
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback for non-supported test environments or platforms
      _isInitialized = true;
    }
  }

  /// Contextually requests notification permissions without blocking the workout.
  Future<bool> requestPermission() async {
    try {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          sound: true,
          badge: false,
        );
        return granted ?? false;
      }
    } catch (_) {}
    return false;
  }

  /// Schedules a local notification at restEndsAt timestamp.
  Future<void> scheduleRestNotification({
    required DateTime restEndsAt,
    int? nextSetNumber,
  }) async {
    await cancelRestNotification();

    final now = DateTime.now();
    if (!restEndsAt.isAfter(now)) {
      return;
    }

    try {
      final setLabel =
          nextSetNumber != null ? 'Set $nextSetNumber' : 'your next set';
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final scheduledTz = tz.TZDateTime.from(restEndsAt, tz.local);

      await _plugin.zonedSchedule(
        _restNotificationId,
        'Rest Complete',
        'Time for $setLabel. Train without distractions.',
        scheduledTz,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Gracefully continue if background alarm permission is restricted
    }
  }

  /// Cancels any scheduled rest notifications.
  Future<void> cancelRestNotification() async {
    try {
      await _plugin.cancel(_restNotificationId);
    } catch (_) {}
  }
}
