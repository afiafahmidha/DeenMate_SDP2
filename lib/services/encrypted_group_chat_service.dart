import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Stores only AES-GCM ciphertext in Firestore. The group secret is never
/// uploaded; members must receive it from the group leader out of band.
class EncryptedGroupChatService {
  EncryptedGroupChatService._();

  static final instance = EncryptedGroupChatService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Cipher _cipher = AesGcm.with256bits();
  final HashAlgorithm _hash = Sha256();

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in before using group chat.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _messages(String groupCode) => _db
      .collection('emergencyGroups')
      .doc(groupCode)
      .collection('messages');

  Stream<List<Map<String, dynamic>>> messages(String groupCode) => _messages(
    groupCode,
  ).orderBy('createdAt', descending: true).limit(50).snapshots().map(
    (snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
  );

  Future<void> send({
    required String groupCode,
    required String groupSecret,
    required String senderName,
    required String plaintext,
  }) async {
    final encrypted = await _encrypt(
      groupCode: groupCode,
      groupSecret: groupSecret,
      plaintext: plaintext,
    );
    await _messages(groupCode).add({
      'senderId': _uid,
      'senderName': _clean(senderName, fallback: 'Group member'),
      ...encrypted,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> decrypt({
    required String groupCode,
    required String groupSecret,
    required Map<String, dynamic> message,
  }) async {
    final secretKey = await _keyFor(groupCode, groupSecret);
    final box = SecretBox(
      base64Url.decode(message['ciphertext'] as String),
      nonce: base64Url.decode(message['nonce'] as String),
      mac: Mac(base64Url.decode(message['mac'] as String)),
    );
    final clearText = await _cipher.decrypt(box, secretKey: secretKey);
    return utf8.decode(clearText);
  }

  Future<Map<String, String>> _encrypt({
    required String groupCode,
    required String groupSecret,
    required String plaintext,
  }) async {
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: await _keyFor(groupCode, groupSecret),
    );
    return {
      'ciphertext': base64UrlEncode(box.cipherText),
      'nonce': base64UrlEncode(box.nonce),
      'mac': base64UrlEncode(box.mac.bytes),
    };
  }

  Future<SecretKey> _keyFor(String groupCode, String groupSecret) async {
    final digest = await _hash.hash(
      utf8.encode('${groupCode.trim().toUpperCase()}:$groupSecret'),
    );
    return _cipher.newSecretKeyFromBytes(digest.bytes);
  }

  String _clean(String value, {required String fallback}) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
  }
}
