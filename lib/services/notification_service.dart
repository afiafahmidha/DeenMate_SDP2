import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Action ids used on the actionable prayer-alarm notification buttons.
class PrayerNotificationAction {
  static const String prayed = 'prayed';
  static const String snooze = 'snooze';
  static const String cancel = 'cancel';
}

/// Which kind of prayer notification fired.
class PrayerNotificationKind {
  static const String alarm = 'alarm';
  static const String nudge = 'nudge';
}

/// Represents a recorded notification in the Notification Center history.
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String category; // 'prayers', 'dhikr', 'zakat', 'quran', 'events', 'sos'
  final bool isRead;
  final String? prayerName;
  final String? targetRoute;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.category,
    this.isRead = false,
    this.prayerName,
    this.targetRoute,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'category': category,
        'isRead': isRead,
        'prayerName': prayerName,
        'targetRoute': targetRoute,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        category: json['category'] as String? ?? 'prayers',
        isRead: json['isRead'] as bool? ?? false,
        prayerName: json['prayerName'] as String?,
        targetRoute: json['targetRoute'] as String?,
      );

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        body: body,
        timestamp: timestamp,
        category: category,
        isRead: isRead ?? this.isRead,
        prayerName: prayerName,
        targetRoute: targetRoute,
      );
}

/// Singleton service for scheduling, cancelling, and tracking all app notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _snoozeDurationMinutes = 20;
  bool _masterEnabled = true;

  final Map<String, bool> _categorySettings = {
    'prayers': true,
    'dhikr': true,
    'zakat': true,
    'quran': true,
    'events': true,
    'sos': true,
  };

  final List<NotificationItem> _history = [];
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  List<NotificationItem> get history => List.unmodifiable(_history);
  int get snoozeDurationMinutes => _snoozeDurationMinutes;
  bool get masterEnabled => _masterEnabled;

  static const Map<String, int> _prayerIds = {
    'Fajr': 1001,
    'Sunrise': 1002,
    'Dhuhr': 1003,
    'Asr': 1004,
    'Maghrib': 1005,
    'Isha': 1006,
  };

  static const int _nudgeIdOffset = 500;
  static const _channelId = 'deenmate_prayer_alarms';
  static const _channelName = 'Prayer Alarms';
  static const _channelDesc =
      'Adhan alarm notifications for each daily prayer time';

  static const _categoryAlarm = 'prayer_alarm_actions';
  static const _categoryInitial = 'prayer_alarm_initial_actions';
  static const _categoryNudge = 'prayer_nudge_actions';

  void Function(String prayerName, String action, String kind)? onPrayerAction;

  // ---- Initialize Once ----
  Future<void> init() async {
    if (_initialized) return;

    await _configureLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        _categoryAlarm,
        actions: [
          DarwinNotificationAction.plain(
            PrayerNotificationAction.prayed,
            'Prayed',
          ),
          DarwinNotificationAction.plain(
            PrayerNotificationAction.snooze,
            'Snooze',
          ),
          DarwinNotificationAction.plain(
            PrayerNotificationAction.cancel,
            'Cancel',
          ),
        ],
        options: {
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
      DarwinNotificationCategory(
        _categoryInitial,
        actions: [
          DarwinNotificationAction.plain(PrayerNotificationAction.snooze, 'Snooze'),
          DarwinNotificationAction.plain(PrayerNotificationAction.cancel, 'Cancel'),
        ],
      ),
      DarwinNotificationCategory(
        _categoryNudge,
        actions: [
          DarwinNotificationAction.plain(
            PrayerNotificationAction.prayed,
            'Prayed',
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

    await _loadPreferencesAndHistory();
    await checkAndRequestPermissions();
  }

  Future<bool> checkAndRequestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final grantedNotif = await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      return grantedNotif ?? false;
    }
    return true;
  }

  Future<void> _loadPreferencesAndHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _snoozeDurationMinutes = prefs.getInt('snooze_duration_minutes') ?? 20;
      _masterEnabled = prefs.getBool('master_notifications_enabled') ?? true;

      for (final cat in _categorySettings.keys) {
        _categorySettings[cat] = prefs.getBool('notif_cat_$cat') ?? true;
      }

      final rawHistory = prefs.getStringList('deenmate_notification_history') ?? [];
      _history.clear();
      for (final jsonStr in rawHistory) {
        try {
          final Map<String, dynamic> map = jsonDecode(jsonStr);
          _history.add(NotificationItem.fromJson(map));
        } catch (_) {}
      }
      _updateUnreadCount();
    } catch (e) {
      debugPrint('[NotificationService] Load preferences error: $e');
    }
  }

  Future<void> setSnoozeDuration(int minutes) async {
    _snoozeDurationMinutes = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snooze_duration_minutes', minutes);
    } catch (_) {}
  }

  Future<void> setMasterEnabled(bool enabled) async {
    _masterEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('master_notifications_enabled', enabled);
    } catch (_) {}

    if (!enabled) {
      await cancelAll();
    }
  }

  bool isCategoryEnabled(String category) {
    return _masterEnabled && (_categorySettings[category] ?? true);
  }

  Future<void> setCategoryEnabled(String category, bool enabled) async {
    _categorySettings[category] = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_cat_$category', enabled);
    } catch (_) {}
  }

  void _updateUnreadCount() {
    final count = _history.where((item) => !item.isRead).length;
    unreadCountNotifier.value = count;
  }

  Future<void> addNotificationItem({
    required String title,
    required String body,
    required String category,
    String? prayerName,
    String? targetRoute,
  }) async {
    final existingIndex = _history.indexWhere(
      (item) => item.title == title && item.category == category,
    );

    if (existingIndex != -1) {
      final existing = _history.removeAt(existingIndex);
      _history.insert(
        0,
        NotificationItem(
          id: existing.id,
          title: title,
          body: body,
          timestamp: DateTime.now(),
          category: category,
          isRead: false,
          prayerName: prayerName ?? existing.prayerName,
          targetRoute: targetRoute ?? existing.targetRoute,
        ),
      );
    } else {
      final item = NotificationItem(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        timestamp: DateTime.now(),
        category: category,
        isRead: false,
        prayerName: prayerName,
        targetRoute: targetRoute,
      );
      _history.insert(0, item);
    }

    _updateUnreadCount();
    await _saveHistoryToPrefs();
  }

  void deleteNotificationItem(String id) {
    _history.removeWhere((element) => element.id == id);
    _updateUnreadCount();
    _saveHistoryToPrefs();
  }

  Future<void> markAsRead(String id) async {
    final index = _history.indexWhere((element) => element.id == id);
    if (index != -1) {
      _history[index] = _history[index].copyWith(isRead: true);
      _updateUnreadCount();
      await _saveHistoryToPrefs();
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _history.length; i++) {
      _history[i] = _history[i].copyWith(isRead: true);
    }
    _updateUnreadCount();
    await _saveHistoryToPrefs();
  }

  Future<void> clearHistory() async {
    _history.clear();
    _updateUnreadCount();
    await _saveHistoryToPrefs();
  }

  Future<void> _saveHistoryToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _history.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('deenmate_notification_history', list);
    } catch (_) {}
  }

  /// Loads the tz database and points `tz.local` at the device's actual
  /// timezone (e.g. Asia/Dhaka). Without this, `tz.local` silently
  /// defaults to UTC and every zonedSchedule() call below fires at the
  /// wrong wall-clock time (offset by the device's UTC difference — e.g.
  /// ~6 hours late for Dhaka), which is why prayer alarms were arriving
  /// late / all bunched up whenever the app was reopened.
  static Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (e) {
      debugPrint('[NotificationService] Timezone lookup failed: $e');
    }
  }

  static tz.TZDateTime _toTzDateTime(DateTime dt) {
    try {
      final local = dt.toLocal();
      return tz.TZDateTime(
        tz.local,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
      );
    } catch (_) {
      return tz.TZDateTime.from(dt, tz.local);
    }
  }

  void _onForegroundResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.length < 2) return;
    final kind = parts[0];
    final prayerName = parts[1];
    final phase = parts.length > 2 ? parts[2] : 'repeat';
    final windowEnd = parts.length > 3
        ? DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts[3]) ?? 0)
        : null;

    if (actionId == null) {
      return;
    }

    debugPrint(
      '[NotificationService] Action "$actionId" on $kind for $prayerName',
    );

    if (actionId == PrayerNotificationAction.snooze) {
      snoozePrayerAlarm(prayerName: prayerName, windowEndTime: windowEnd);
    } else if (actionId == PrayerNotificationAction.prayed) {
      _markPrayerCompleted(prayerName, windowEnd);
      cancelPrayerAlarm(prayerName);
    } else if (actionId == PrayerNotificationAction.cancel) {
      cancelPrayerAlarm(prayerName);
    }

    onPrayerAction?.call(prayerName, actionId, kind);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;
    if (actionId == null || payload == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final parts = payload.split('|');
      final prayerName = parts.length >= 2 ? parts[1] : '';

      if (actionId == PrayerNotificationAction.prayed) {
        if (prayerName.isNotEmpty) {
          final now = DateTime.now();
          final ymd =
              '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
          await prefs.setBool('completed_${ymd}_$prayerName', true);
          await _cancelBackgroundPrayerAlarm(prayerName);
        }
      } else if (actionId == PrayerNotificationAction.snooze) {
        await _scheduleBackgroundSnooze(payload);
      } else if (actionId == PrayerNotificationAction.cancel) {
        if (prayerName.isNotEmpty) {
          await _cancelBackgroundPrayerAlarm(prayerName);
        }
      }
      final pending = prefs.getStringList('pending_background_notification_actions') ?? [];
      pending.add('$actionId|$payload');
      await prefs.setStringList('pending_background_notification_actions', pending);
    } catch (e) {
      debugPrint('[NotificationService] _onBackgroundResponse error: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _scheduleBackgroundSnooze(String payload) async {
    final parts = payload.split('|');
    if (parts.length < 2) return;
    final prayerName = parts[1];
    if (prayerName.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final snoozeMinutes = prefs.getInt('snooze_duration_minutes') ?? 20;
    final next = DateTime.now().add(Duration(minutes: snoozeMinutes));

    final endMillis = parts.length >= 4 ? int.tryParse(parts[3]) : null;
    final end = (endMillis != null && endMillis > 0)
        ? DateTime.fromMillisecondsSinceEpoch(endMillis)
        : next.add(const Duration(hours: 2));

    if (!next.isBefore(end)) return;

    try {
      await _configureLocalTimeZone();
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          actions: [
            AndroidNotificationAction(
              PrayerNotificationAction.prayed,
              'Prayed',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              PrayerNotificationAction.snooze,
              'Snooze',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              PrayerNotificationAction.cancel,
              'Cancel',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          categoryIdentifier: _categoryAlarm,
        ),
      );
      final id = _prayerIds[prayerName];
      if (id == null) return;

      final tzNext = _toTzDateTime(next);
      await plugin.zonedSchedule(
        id,
        '$prayerName prayer time (Snoozed)',
        '$prayerName prayer reminder. Tap Prayed when complete.',
        tzNext,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '${PrayerNotificationKind.alarm}|$prayerName|repeat|${end.millisecondsSinceEpoch}',
      );
      debugPrint('[NotificationService] Scheduled background snooze for $prayerName at $tzNext');
    } catch (e) {
      debugPrint('[NotificationService] _scheduleBackgroundSnooze error: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _cancelBackgroundPrayerAlarm(String prayerName) async {
    final id = _prayerIds[prayerName];
    if (id == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    await plugin.cancel(id);
    await plugin.cancel(id + _nudgeIdOffset);
  }

  Future<void> drainPendingActions(
      Function(String prayerName, String action, String kind) handler) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_background_notification_actions') ?? [];
      if (pending.isEmpty) return;

      await prefs.remove('pending_background_notification_actions');
      for (final item in pending) {
        final parts = item.split('|');
        if (parts.length >= 2) {
          final actionId = parts[0];
          final payloadStr = parts.sublist(1).join('|');
          final subParts = payloadStr.split('|');
          final kind = subParts.isNotEmpty ? subParts[0] : '';
          final prayerName = subParts.length >= 2 ? subParts[1] : '';
          if (prayerName.isNotEmpty) {
            handler(prayerName, actionId, kind);
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Drain pending actions error: $e');
    }
  }

  NotificationDetails _detailsFor({
    required String kind,
    required bool fullScreenIntent,
    required String phase,
  }) {
    final actions = const [
      AndroidNotificationAction(
        PrayerNotificationAction.prayed,
        'Prayed',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        PrayerNotificationAction.snooze,
        'Snooze',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        PrayerNotificationAction.cancel,
        'Cancel',
        showsUserInterface: false,
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
      fullScreenIntent: fullScreenIntent,
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
          kind == PrayerNotificationKind.nudge
              ? _categoryNudge
              : (phase == 'initial' ? _categoryInitial : _categoryAlarm),
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Future<void> schedulePrayerAlarm({
    required String prayerName,
    required DateTime scheduledTime,
    DateTime? windowEndTime,
    bool isSnoozed = false,
  }) async {
    if (!_initialized) await init();
    if (!isCategoryEnabled('prayers')) return;

    if (scheduledTime.isBefore(DateTime.now())) return;

    final id = _prayerIds[prayerName];
    if (id == null) return;

    final tz.TZDateTime tzTime = _toTzDateTime(scheduledTime);
    final arabicName = _arabicName(prayerName);

    final phase = isSnoozed ? 'repeat' : 'initial';
    final endMillis = (windowEndTime ??
            scheduledTime.add(const Duration(hours: 2)))
        .millisecondsSinceEpoch;
    await _plugin.zonedSchedule(
      id,
      '$arabicName • Time to Pray',
      '$prayerName prayer time has arrived. May Allah accept your prayers.',
      tzTime,
      _detailsFor(
        kind: PrayerNotificationKind.alarm,
        fullScreenIntent: true,
        phase: phase,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${PrayerNotificationKind.alarm}|$prayerName|$phase|$endMillis',
    );

    debugPrint('[NotificationService] Scheduled $prayerName alarm at $tzTime');
  }

  Future<void> snoozePrayerAlarm({
    required String prayerName,
    Duration? delay,
    DateTime? windowEndTime,
  }) async {
    final effectiveDelay = delay ?? Duration(minutes: _snoozeDurationMinutes);
    final nextTime = DateTime.now().add(effectiveDelay);
    final end = windowEndTime ?? nextTime.add(const Duration(hours: 2));
    await schedulePrayerAlarm(
      prayerName: prayerName,
      scheduledTime: nextTime,
      windowEndTime: end,
      isSnoozed: true,
    );
  }

  Future<void> _markPrayerCompleted(
      String prayerName, DateTime? windowEndTime) async {
    final now = DateTime.now();
    final ymd =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_${ymd}_$prayerName', true);
  }

  Future<void> scheduleEndOfWindowNudge({
    required String prayerName,
    required DateTime windowEndTime,
    Duration leadTime = const Duration(minutes: 15),
  }) async {
    if (!_initialized) await init();
    if (!isCategoryEnabled('prayers')) return;

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
      _detailsFor(
        kind: PrayerNotificationKind.nudge,
        fullScreenIntent: false,
        phase: 'repeat',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${PrayerNotificationKind.nudge}|$prayerName',
    );
  }

  Future<void> cancelEndOfWindowNudge(String prayerName) async {
    if (!_initialized) await init();
    final baseId = _prayerIds[prayerName];
    if (baseId == null) return;
    await _plugin.cancel(baseId + _nudgeIdOffset);
  }

  Future<void> cancelPrayerAlarm(String prayerName) async {
    if (!_initialized) await init();
    final id = _prayerIds[prayerName];
    if (id == null) return;
    await _plugin.cancel(id);
    await cancelEndOfWindowNudge(prayerName);
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

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

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> scheduleCustomNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String category = 'events',
    String? targetRoute,
  }) async {
    if (!_initialized) await init();
    if (!isCategoryEnabled(category)) return;

    await addNotificationItem(
      title: title,
      body: body,
      category: category,
      targetRoute: targetRoute,
    );

    if (scheduledTime.isBefore(DateTime.now())) return;

    try {
      final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
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
        payload: '$category|$id',
      );
    } catch (e) {
      debugPrint('[NotificationService] System zonedSchedule error: $e');
    }
  }

  Future<void> showCustomNotification({
    required int id,
    required String title,
    required String body,
    String category = 'events',
    String? targetRoute,
  }) async {
    if (!_initialized) await init();
    if (!isCategoryEnabled(category)) return;

    await addNotificationItem(
      title: title,
      body: body,
      category: category,
      targetRoute: targetRoute,
    );

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
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
        payload: '$category|$id',
      );
    } catch (e) {
      debugPrint('[NotificationService] System show error: $e');
    }
  }
}