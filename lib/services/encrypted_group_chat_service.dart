import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore-backed group chat, readable only by current group members.
class EncryptedGroupChatService {
  EncryptedGroupChatService._();

  static final instance = EncryptedGroupChatService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in before using group chat.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _messages(String groupCode) => _db
      .collection('emergencyGroups')
      .doc(groupCode)
      .collection('messages');

  Stream<List<Map<String, dynamic>>> messages(String groupCode) =>
      _messages(groupCode).snapshots().map((snapshot) {
        final messages = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .where((message) => (message['text'] as String? ?? '').isNotEmpty)
            .toList();
        messages.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });
        return messages.take(50).toList();
      });

  Future<void> send({
    required String groupCode,
    required String senderName,
    required String text,
  }) async {
    await _messages(groupCode).add({
      'senderId': _uid,
      'senderName': _clean(senderName, fallback: 'Group member'),
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _clean(String value, {required String fallback}) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
  }
}
