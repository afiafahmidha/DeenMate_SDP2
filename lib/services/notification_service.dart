import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Singleton service for scheduling and cancelling prayer alarm notifications.
/// Uses [flutter_local_notifications] with exact TZ-scheduled alarms on Android
/// and local notifications on iOS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Unique notification ID per prayer (stable, so cancellation works)
  static const Map<String, int> _prayerIds = {
    'Fajr': 1001,
    'Sunrise': 1002,
    'Dhuhr': 1003,
    'Asr': 1004,
    'Maghrib': 1005,
    'Isha': 1006,
  };

  static const _channelId = 'deenmate_prayer_alarms';
  static const _channelName = 'Prayer Alarms';
  static const _channelDesc =
      'Adhan alarm notifications for each daily prayer time';

  // ---- Initialise once ----
  Future<void> init() async {
    if (_initialized) return;

    // Load timezone data bundle
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;

    // Request permission on Android 13+
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // ---- Schedule a prayer alarm at exact [scheduledTime] ----
  Future<void> schedulePrayerAlarm({
    required String prayerName,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) await init();

    // Don't schedule if time is in the past
    if (scheduledTime.isBefore(DateTime.now())) return;

    final id = _prayerIds[prayerName];
    if (id == null) return;

    final tz.TZDateTime tzTime =
        tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: UriAndroidNotificationSound("content://settings/system/alarm_alert"),
      enableVibration: true,
      fullScreenIntent: true,          // shows on locked screen
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final arabicName = _arabicName(prayerName);

    await _plugin.zonedSchedule(
      id,
      '$arabicName • Time to Pray',
      '$prayerName prayer time has arrived. May Allah accept your prayers.',
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('[NotificationService] Scheduled $prayerName alarm at $tzTime');
  }

  // ---- Cancel a scheduled prayer alarm ----
  Future<void> cancelPrayerAlarm(String prayerName) async {
    if (!_initialized) await init();
    final id = _prayerIds[prayerName];
    if (id == null) return;
    await _plugin.cancel(id);
    debugPrint('[NotificationService] Cancelled $prayerName alarm');
  }

  // ---- Cancel ALL prayer alarms ----
  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
    debugPrint('[NotificationService] Cancelled all prayer alarms');
  }

  // ---- Arabic name mapping ----
  String _arabicName(String prayerName) {
    const map = {
      'Fajr': 'Fajr (الفجر)',
      'Sunrise': 'Sunrise (الشروق)',
      'Dhuhr': 'Dhuhr (الظهر)',
      'Asr': 'Asr (العصر)',
      'Maghrib': 'Maghrib (المغرب)',
      'Isha': 'Isha (العشاء)',
    };
    return map[prayerName] ?? prayerName;
  }

  // ---- Schedule a custom/local notification ----
  Future<void> scheduleCustomNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) await init();

    // Do not schedule past times
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: UriAndroidNotificationSound("content://settings/system/alarm_alert"),
      enableVibration: true,
      visibility: NotificationVisibility.public,
      ongoing: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('[NotificationService] Scheduled custom notification: $title at $tzTime (id=$id)');
  }

  // ---- Show a custom/local notification immediately ----
  Future<void> showCustomNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: UriAndroidNotificationSound("content://settings/system/alarm_alert"),
      enableVibration: true,
      visibility: NotificationVisibility.public,
      ongoing: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
    );

    debugPrint('[NotificationService] Showed instant custom notification: $title (id=$id)');
  }
}
