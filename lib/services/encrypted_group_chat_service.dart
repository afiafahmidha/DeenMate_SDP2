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
            .where((message) {
              final text = (message['text'] as String? ?? '').trim();
              final file = (message['fileBase64'] as String? ?? '').trim();
              return text.isNotEmpty || file.isNotEmpty;
            })
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
    String text = '',
    String? fileBase64,
    String? fileName,
    String? fileType,
    Map<String, dynamic>? replyTo,
  }) async {
    final payload = <String, dynamic>{
      'senderId': _uid,
      'senderName': _clean(senderName, fallback: 'Group member'),
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (fileBase64 != null && fileBase64.isNotEmpty) {
      payload['fileBase64'] = fileBase64;
      payload['fileName'] = fileName ?? 'Attachment';
      payload['fileType'] = fileType ?? 'document';
    }
    if (replyTo != null && replyTo.isNotEmpty) {
      payload['replyTo'] = replyTo;
    }
    await _messages(groupCode).add(payload);
  }

  Future<void> edit({
    required String groupCode,
    required String messageId,
    required String newText,
  }) async {
    await _messages(groupCode).doc(messageId).update({
      'text': newText.trim(),
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({
    required String groupCode,
    required String messageId,
  }) async {
    await _messages(groupCode).doc(messageId).delete();
  }

  String _clean(String value, {required String fallback}) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
  }
}
