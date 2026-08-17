import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

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
}
