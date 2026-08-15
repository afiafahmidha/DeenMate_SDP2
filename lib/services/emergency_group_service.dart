import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore-backed SOS groups. Each member may read only groups they joined;
/// enforce the matching rules before shipping (see firestore.rules).
class EmergencyGroupService {
  EmergencyGroupService._();

  static final instance = EmergencyGroupService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('emergencyGroups');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in before using SOS groups.');
    return uid;
  }

  Future<String> createGroup({
    required String leaderName,
    double rangeMeters = 1000,
  }) async {
    final uid = _uid;
    final code = await _newUnusedCode();
    final group = _groups.doc(code);
    final batch = _db.batch();
    batch.set(group, {
      'code': code,
      'leaderId': uid,
      'leaderName': leaderName.trim().isEmpty ? 'Group leader' : leaderName.trim(),
      'rangeMeters': rangeMeters,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(group.collection('members').doc(uid), _memberData(
      name: leaderName,
      isLeader: true,
    ));
    await batch.commit();
    return code;
  }

  Future<void> joinGroup({required String code, required String memberName}) async {
    final normalized = code.trim().toUpperCase();
    final group = _groups.doc(normalized);
    if (!(await group.get()).exists) {
      throw StateError('That group code does not exist. Ask the leader to check it.');
    }
    await group.collection('members').doc(_uid).set(
          _memberData(name: memberName, isLeader: false),
          SetOptions(merge: true),
        );
  }

  Future<void> updateMyLocation({
    required String code,
    required double latitude,
    required double longitude,
  }) =>
      _groups.doc(code).collection('members').doc(_uid).set({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Owner-only in the UI; enforce the same ownership check in Firestore rules.
  Future<void> updateRadarRadius({
    required String code,
    required double rangeMeters,
  }) =>
      _groups.doc(code).update({
        'rangeMeters': rangeMeters,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Owner-only in the UI; enforce the same ownership check in Firestore rules.
  Future<void> removeMember({
    required String code,
    required String memberId,
  }) =>
      _groups.doc(code).collection('members').doc(memberId).delete();

  Stream<List<Map<String, dynamic>>> members(String code) => _groups
      .doc(code)
      .collection('members')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());

  Stream<Map<String, dynamic>?> group(String code) =>
      _groups.doc(code).snapshots().map((doc) => doc.data());

  Future<void> leaveGroup(String code) =>
      _groups.doc(code).collection('members').doc(_uid).delete();

  Map<String, dynamic> _memberData({required String name, required bool isLeader}) => {
        'name': name.trim().isEmpty ? 'Group member' : name.trim(),
        'isLeader': isLeader,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Future<String> _newUnusedCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = 'SOS-${List.generate(6, (_) => chars[random.nextInt(chars.length)]).join()}';
      if (!(await _groups.doc(code).get()).exists) return code;
    }
    throw StateError('Could not generate a unique group code. Please try again.');
  }
}
