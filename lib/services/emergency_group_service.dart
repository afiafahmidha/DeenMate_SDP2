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
    if (uid == null)
      throw StateError('Please sign in before using SOS groups.');
    return uid;
  }

  Future<String> createGroup({
    required String leaderName,
    required String groupName,
    double rangeMeters = 1000,
  }) async {
    final uid = _uid;
    final code = await _newUnusedCode();
    final group = _groups.doc(code);
    final batch = _db.batch();
    batch.set(group, {
      'code': code,
      'name': groupName.trim(),
      'leaderId': uid,
      'leaderName': leaderName.trim().isEmpty
          ? 'Group leader'
          : leaderName.trim(),
      'rangeMeters': rangeMeters,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      group.collection('members').doc(uid),
      _memberData(name: leaderName, isLeader: true),
    );
    await batch.commit();
    return code;
  }

  Future<void> joinGroup({
    required String code,
    required String memberName,
  }) async {
    // Resolve and refresh the user before accessing the shared-code document.
    // Without this, a missing/expired auth session surfaces as the generic
    // Firestore permission-denied error rather than an actionable sign-in one.
    final uid = _uid;
    await _auth.currentUser?.getIdToken(true);

    final normalized = code.trim().toUpperCase();
    final group = _groups.doc(normalized);
    if (!(await group.get()).exists) {
      throw StateError(
        'That group code does not exist. Ask the leader to check it.',
      );
    }

    final membership = group.collection('members').doc(uid);
    final existingMembership = await membership.get();

    if (existingMembership.exists) {
      // A re-join is an update, not a new membership. Keep joinedAt immutable
      // so it complies with the member update rule and retains the real date.
      await membership.update({
        'name': memberName.trim().isEmpty ? 'Group member' : memberName.trim(),
        'photoUrl': _auth.currentUser?.photoURL ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await membership.set(_memberData(name: memberName, isLeader: false));
  }

  Future<void> updateMyLocation({
    required String code,
    required double latitude,
    required double longitude,
  }) async {
    final uid = _uid;
    final profile = await _db.collection('users').doc(uid).get();
    final profileData = profile.data()?['profile'] as Map?;
    await _groups.doc(code).collection('members').doc(uid).set({
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': _auth.currentUser?.photoURL ?? '',
      'photoBase64': profileData?['avatarBase64'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Owner-only in the UI; enforce the same ownership check in Firestore rules.
  Future<void> updateRadarRadius({
    required String code,
    required double rangeMeters,
  }) => _groups.doc(code).update({
    'rangeMeters': rangeMeters,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Owner-only in the UI; enforce the same ownership check in Firestore rules.
  Future<void> removeMember({required String code, required String memberId}) =>
      _groups.doc(code).collection('members').doc(memberId).delete();

  Stream<List<Map<String, dynamic>>> members(String code) => _groups
      .doc(code)
      .collection('members')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
      );

  Stream<Map<String, dynamic>?> group(String code) =>
      _groups.doc(code).snapshots().map((doc) => doc.data());

  Stream<List<Map<String, dynamic>>> incidents(String code) => _groups
      .doc(code)
      .collection('incidents')
      .snapshots()
      .map((snapshot) {
        final incidents = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        incidents.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });
        return incidents;
      });

  Future<String> createIncident({
    required String code,
    required String senderName,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final reference = _groups.doc(code).collection('incidents').doc();
    await reference.set({
      'senderId': _uid,
      'senderName': senderName.trim().isEmpty ? 'Group member' : senderName.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address.length > 240 ? address.substring(0, 240) : address,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> resolveIncident({
    required String code,
    required String incidentId,
  }) => _groups.doc(code).collection('incidents').doc(incidentId).update({
    'status': 'resolved',
    'updatedAt': FieldValue.serverTimestamp(),
    'resolvedAt': FieldValue.serverTimestamp(),
  });

  Future<void> leaveGroup(String code) =>
      _groups.doc(code).collection('members').doc(_uid).delete();

  /// Removes the group document. Its subcollections become inaccessible because
  /// their membership rule requires the parent group to exist. Use an admin
  /// backend job for physical recursive deletion of large chat histories.
  Future<void> deleteGroup(String code) async {
    final group = _groups.doc(code);
    final snapshot = await group.get();
    if (!snapshot.exists || snapshot.data()?['leaderId'] != _uid) {
      throw StateError('Only the group owner can delete this group.');
    }
    await group.delete();
  }

  Map<String, dynamic> _memberData({
    required String name,
    required bool isLeader,
  }) => {
    'name': name.trim().isEmpty ? 'Group member' : name.trim(),
    // Only public Auth profile data is replicated to the group roster; private
    // SOS and medical data stay in the owner's user document.
    'photoUrl': _auth.currentUser?.photoURL ?? '',
    'isLeader': isLeader,
    'joinedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Future<String> _newUnusedCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code =
          'SOS-${List.generate(6, (_) => chars[random.nextInt(chars.length)]).join()}';
      if (!(await _groups.doc(code).get()).exists) return code;
    }
    throw StateError(
      'Could not generate a unique group code. Please try again.',
    );
  }
}
