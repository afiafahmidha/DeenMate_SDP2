import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Copies legacy embedded feature maps into document-first Firestore paths.
/// Nothing is deleted: the old fields remain as a backwards-compatible cache.
class FirestoreStructureMigrationService {
  FirestoreStructureMigrationService._();
  static final instance = FirestoreStructureMigrationService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> migrateCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final root = _db.collection('users').doc(user.uid);
    final snapshot = await root.get();
    final data = snapshot.data();
    if (data == null) return;

    Future<void> copyMap(String key, String collection, String id) async {
      final value = data[key];
      if (value is Map<String, dynamic> && value.isNotEmpty) {
        await root.collection(collection).doc(id).set({
          ...value,
          'migratedFrom': 'users/$key',
          'migratedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await copyMap('dhikr', 'dhikrStats', 'summary');
    await copyMap('zakat', 'zakatProfiles', 'current');
    await copyMap('inheritance', 'inheritanceScenarios', 'current');
    await copyMap('hajjUmrah', 'hajjProgress', 'current');

    // Quran already uses users/{uid}/quranTracker/state. Support any older
    // root-level quran map without replacing the current tracker document.
    final legacyQuran = data['quran'] ?? data['quranProgress'];
    if (legacyQuran is Map<String, dynamic> && legacyQuran.isNotEmpty) {
      await root.collection('quranTracker').doc('state').set({
        ...legacyQuran,
        'migratedFrom': 'users/quran',
        'migratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await root.collection('settings').doc('dataStructure').set({
      'version': 2,
      'migratedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
