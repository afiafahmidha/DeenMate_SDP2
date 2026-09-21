import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  bool _initialized = false;

  /// Starts FCM handling once Firebase has been initialized. This must run for
  /// every signed-in user, not only when they open the SOS screen; otherwise a
  /// group member who has not opened that screen has no device token to alert.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // The SOS screen already observes the incident in Firestore. Keeping the
      // message handler here ensures a notification tap is consumed cleanly.
      _showForegroundNotification(message, showSystemNotification: false);
    });
  }

  Future<void> registerDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    const vapidKey = String.fromEnvironment('FCM_VAPID_KEY');
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: vapidKey.isEmpty ? null : vapidKey,
    );
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'pushTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pushTokens': FieldValue.arrayUnion([newToken]),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _showForegroundNotification(
    RemoteMessage message, {
    bool showSystemNotification = true,
  }) async {
    if (!showSystemNotification) return;

    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null || body == null) return;

    // FCM displays notification payloads while the app is backgrounded. In
    // the foreground Android deliberately suppresses that system banner, so
    // display the same alert through the local-notification service.
    await NotificationService.instance.showCustomNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      category: message.data['category']?.toString() ?? 'sos',
      targetRoute: message.data['route']?.toString(),
    );
  }
}
