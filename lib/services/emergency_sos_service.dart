import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Persists an SOS incident and its latest known location in Firestore.
/// Medical information and contact numbers stay on the caller's device.
class EmergencySosService {
  EmergencySosService._();

  static final instance = EmergencySosService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null)
      throw StateError('Please sign in before sending an SOS alert.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _incidents =>
      _db.collection('sosIncidents');

  Future<String> createIncident({
    required double latitude,
    required double longitude,
    required String address,
    required bool isSilent,
  }) async {
    final reference = _incidents.doc();
    await reference.set({
      'ownerId': _uid,
      'status': 'active',
      'latitude': latitude,
      'longitude': longitude,
      'address': _clean(address, 240),
      'isSilent': isSilent,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });
    return reference.id;
  }

  Future<void> updateLocation({
    required String incidentId,
    required double latitude,
    required double longitude,
  }) => _incidents.doc(incidentId).update({
    'latitude': latitude,
    'longitude': longitude,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> resolveIncident({
    required String incidentId,
    required double latitude,
    required double longitude,
  }) => _incidents.doc(incidentId).update({
    'status': 'resolved',
    'latitude': latitude,
    'longitude': longitude,
    'updatedAt': FieldValue.serverTimestamp(),
    'resolvedAt': FieldValue.serverTimestamp(),
  });

  String _clean(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }
}
