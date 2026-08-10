import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Action ids used on the actionable prayer-alarm notification buttons.
/// Kept as plain strings (rather than an enum) because
/// flutter_local_notifications hands the raw actionId straight back to us
/// as a String in the NotificationResponse — including from the
/// background/terminated-app isolate, where only primitives can cross the
/// isolate boundary.
class PrayerNotificationAction {
  static const String prayed = 'prayed';
  static const String snooze = 'snooze';
  static const String missed = 'missed';
}

/// Which kind of prayer notification fired — lets the app tell an
/// "on-time" alarm apart from the later "did you pray?" nudge when it
/// decides how to react to a tapped action (e.g. a nudge's "Missed" should
/// log a qaza; an on-time alarm's "Missed" is more of an early heads-up).
class PrayerNotificationKind {
  static const String alarm = 'alarm';
  static const String nudge = 'nudge';
}

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

  // End-of-window "did you pray?" nudge gets its own id space so it never
  // collides with (or accidentally cancels) the on-time alarm above.
  static const int _nudgeIdOffset = 500;

  static const _channelId = 'deenmate_prayer_alarms';
  static const _channelName = 'Prayer Alarms';
  static const _channelDesc =
      'Adhan alarm notifications for each daily prayer time';

  static const _categoryAlarm = 'prayer_alarm_actions';
  static const _categoryNudge = 'prayer_nudge_actions';

  /// Fired whenever the user taps "Prayed", "Snooze", or "Missed" on a
  /// prayer notification while the app is running in the foreground or
  /// background (but still alive). Wire this up from DashboardScreen,
  /// e.g.:
  ///
  /// ```dart
  /// NotificationService.instance.onPrayerAction =
  ///     (prayerName, action, kind) {
  ///   switch (action) {
  ///     case PrayerNotificationAction.prayed:
  ///       _onSalatToggle(prayerName, true);
  ///       break;
  ///     case PrayerNotificationAction.missed:
  ///       _onQazaCountChange(prayerName, (_qazaCounts[prayerName] ?? 0) + 1);
  ///       break;
  ///     case PrayerNotificationAction.snooze:
  ///       NotificationService.instance.snoozePrayerAlarm(
  ///         prayerName: prayerName,
  ///         delay: const Duration(minutes: 10),
  ///       );
  ///       break;
  ///   }
  /// };
  /// ```
  ///
  /// Note: if the user taps an action while the app is fully terminated,
  /// Android delivers the tap to a separate background isolate via
  /// [_onBackgroundResponse] below, where this callback (and all other
  /// app state) isn't available. That path currently just logs the
  /// action — persist it (e.g. via shared_preferences) there if you need
  /// cold-start handling too, then drain/apply it on the next app launch.
  void Function(String prayerName, String action, String kind)? onPrayerAction;

  // ---- Initialise once ----
  Future<void> init() async {
    if (_initialized) return;

    // Load timezone data bundle
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS notification categories declare which action buttons a
    // given notification "type" gets. A notification is tied to a
    // category via its `categoryIdentifier` when it's scheduled below.
    final darwinCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        _categoryAlarm,
        actions: [
          DarwinNotificationAction.plain(
            PrayerNotificationAction.prayed,
            'Prayed',
            options: {DarwinNotificationActionOption.foreground},
          ),
          DarwinNotificationAction.plain(
            PrayerNotificationAction.snooze,
            'Snooze',
          ),
          DarwinNotificationAction.plain(
            PrayerNotificationAction.missed,
            'Missed',
            options: {DarwinNotificationActionOption.destructive},
          ),
        ],
        options: {
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
      DarwinNotificationCategory(
        _categoryNudge,
        actions: [
          DarwinNotificationAction.plain(
            PrayerNotificationAction.prayed,
            'Prayed',
            options: {DarwinNotificationActionOption.foreground},
          ),
          DarwinNotificationAction.plain(
            PrayerNotificationAction.missed,
            'Missed',
            options: {DarwinNotificationActionOption.destructive},
          ),
        ],
      ),
    ];

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: darwinCategories,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );
    _initialized = true;

    // Request permission on Android 13+
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // ---- Notification tap/action handling (app alive: foreground or background) ----
  void _onForegroundResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (payload == null) return;

    // payload format: "<kind>|<prayerName>" e.g. "alarm|Dhuhr"
    final parts = payload.split('|');
    if (parts.length != 2) return;
    final kind = parts[0];
    final prayerName = parts[1];

    if (actionId == null) {
      // Plain tap (no action button) — just opening the app, nothing to do.
      return;
    }

    debugPrint(
      '[NotificationService] Action "$actionId" on $kind for $prayerName',
    );

    if (actionId == PrayerNotificationAction.snooze) {
      // Handle snooze here directly since it doesn't need app/UI state.
      snoozePrayerAlarm(prayerName: prayerName);
    }

    onPrayerAction?.call(prayerName, actionId, kind);
  }

  // Runs in a separate background isolate when the app process has been
  // killed, so it must be a top-level/static function and cannot touch
  // instance state, Flutter bindings, or UI. Kept minimal — persist the
  // action here (e.g. shared_preferences) if you want cold-start replay.
  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    debugPrint(
      '[NotificationService] Background action "${response.actionId}" '
      'payload=${response.payload}',
    );
    // TODO: persist response.actionId + response.payload (e.g. via
    // shared_preferences) and apply it in DashboardScreen on next launch.
  }

  NotificationDetails _detailsFor({
    required String kind,
    required bool fullScreenIntent,
  }) {
    final actions = kind == PrayerNotificationKind.nudge
        ? const [
            AndroidNotificationAction(
              PrayerNotificationAction.prayed,
              'Prayed',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              PrayerNotificationAction.missed,
              'Missed',
              cancelNotification: true,
            ),
          ]
        : const [
            AndroidNotificationAction(
              PrayerNotificationAction.prayed,
              'Prayed',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              PrayerNotificationAction.snooze,
              'Snooze',
            ),
            AndroidNotificationAction(
              PrayerNotificationAction.missed,
              'Missed',
              cancelNotification: true,
            ),
          ];

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const UriAndroidNotificationSound(
        "content://settings/system/alarm_alert",
      ),
      enableVibration: true,
      fullScreenIntent: fullScreenIntent, // only the on-time alarm wakes the lock screen
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: false,
      actions: actions,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      categoryIdentifier:
          kind == PrayerNotificationKind.nudge ? _categoryNudge : _categoryAlarm,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  // ---- Schedule a prayer alarm at exact [scheduledTime] ----
  // Fires an actionable notification right when the prayer window opens,
  // with "Prayed" / "Snooze" / "Missed" buttons so logging is a one-tap
  // reflex instead of something to remember later.
  Future<void> schedulePrayerAlarm({
    required String prayerName,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) await init();

    // Don't schedule if time is in the past
    if (scheduledTime.isBefore(DateTime.now())) return;

    final id = _prayerIds[prayerName];
    if (id == null) return;

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final arabicName = _arabicName(prayerName);

    await _plugin.zonedSchedule(
      id,
      '$arabicName • Time to Pray',
      '$prayerName prayer time has arrived. May Allah accept your prayers.',
      tzTime,
      _detailsFor(kind: PrayerNotificationKind.alarm, fullScreenIntent: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${PrayerNotificationKind.alarm}|$prayerName',
    );

    debugPrint('[NotificationService] Scheduled $prayerName alarm at $tzTime');
  }

  /// Reschedules a prayer's on-time alarm a bit later, for the "Snooze"
  /// action. Uses the same notification id as the original alarm, so the
  /// snoozed one simply replaces it rather than stacking up duplicates.
  Future<void> snoozePrayerAlarm({
    required String prayerName,
    Duration delay = const Duration(minutes: 10),
  }) async {
    await schedulePrayerAlarm(
      prayerName: prayerName,
      scheduledTime: DateTime.now().add(delay),
    );
  }

  // ---- Schedule the end-of-window "did you pray X?" nudge ----
  //
  // A gentler, second reminder timed shortly BEFORE a prayer's window
  // closes (e.g. ~15-20 min before Asr starts, for a Dhuhr nudge) rather
  // than at its start. This catches people who already prayed but forgot
  // to tap "Prayed" on the first alarm, and flags people who genuinely
  // haven't yet — without interrupting them mid-prayer the way a second
  // alarm right at start time would.
  //
  // Callers should pass the same "window closes at" time already used
  // elsewhere to decide when a prayer counts as missed (e.g. Dhuhr's
  // window closes when Asr begins, Isha's when tomorrow's Fajr begins),
  // and this schedules the nudge [leadTime] before that.
  Future<void> scheduleEndOfWindowNudge({
    required String prayerName,
    required DateTime windowEndTime,
    Duration leadTime = const Duration(minutes: 15),
  }) async {
    if (!_initialized) await init();

    final baseId = _prayerIds[prayerName];
    if (baseId == null) return;
    final id = baseId + _nudgeIdOffset;

    final fireTime = windowEndTime.subtract(leadTime);
    if (fireTime.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzTime = tz.TZDateTime.from(fireTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      'Did you pray $prayerName?',
      "$prayerName's window is closing soon — tap to log it.",
      tzTime,
      _detailsFor(kind: PrayerNotificationKind.nudge, fullScreenIntent: false),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${PrayerNotificationKind.nudge}|$prayerName',
    );

    debugPrint(
      '[NotificationService] Scheduled $prayerName nudge at $tzTime '
      '(window closes $windowEndTime)',
    );
  }

  /// Cancel just the end-of-window nudge for a prayer (e.g. call this the
  /// moment the user taps "Prayed" on the earlier on-time alarm, so the
  /// nudge doesn't fire redundantly once it's already logged).
  Future<void> cancelEndOfWindowNudge(String prayerName) async {
    if (!_initialized) await init();
    final baseId = _prayerIds[prayerName];
    if (baseId == null) return;
    await _plugin.cancel(baseId + _nudgeIdOffset);
    debugPrint('[NotificationService] Cancelled $prayerName nudge');
  }

  // ---- Cancel a scheduled prayer alarm (and its end-of-window nudge) ----
  Future<void> cancelPrayerAlarm(String prayerName) async {
    if (!_initialized) await init();
    final id = _prayerIds[prayerName];
    if (id == null) return;
    await _plugin.cancel(id);
    await cancelEndOfWindowNudge(prayerName);
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
