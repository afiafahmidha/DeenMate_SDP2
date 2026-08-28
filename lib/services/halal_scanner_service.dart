import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/halal_scanner/halal_scanner_home.dart';
import 'halal_analyzer_service.dart';

class HalalScannerService {
  static final HalalScannerService instance = HalalScannerService._();
  HalalScannerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, String> _additiveOverrides = {};
  Map<String, String> get additiveOverrides => _additiveOverrides;

  String? get uid => _auth.currentUser?.uid;

  CollectionReference? get _scanCollection {
    final user = uid;
    if (user == null) return null;
    return _db.collection('users').doc(user).collection('halalScans');
  }

  /// Saves a scanned product to Firestore
  Future<void> saveScan(ScannedProduct product) async {
    final col = _scanCollection;
    if (col == null) {
      print('Cannot save halal scan: User not authenticated (UID is null)');
      return;
    }

    try {
      final docId = product.barcode.isNotEmpty ? product.barcode : DateTime.now().millisecondsSinceEpoch.toString();

      await col.doc(docId).set({
        'barcode': product.barcode,
        'productName': product.name,
        'ingredients': product.ingredients.join(', '),
        'additives': product.additives.join(', '),
        'halalStatus': product.status.toLowerCase(),
        'resultDetails': product.risk,
        'imageUrl': product.imageUrl,
        'scannedAt': FieldValue.serverTimestamp(),
        // Store analysis results as a list of maps
        
        'analysisResults': product.analysisResults?.map((e) => e.toJson()).toList(),
      }, SetOptions(merge: true));
      print('Halal scan saved successfully: ${product.name}');
    } catch (e) {
      print('Error saving halal scan: $e');
    }
  }

  /// Fetches the last scanned products from Firestore
  Future<List<ScannedProduct>> getScanHistory({int limit = 20}) async {
    final col = _scanCollection;
    if (col == null) return [];

    try {
      final snapshot = await col
          .orderBy('scannedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Handle analysis results
        List<IngredientAnalysisResult>? analysisResults;
        if (data['analysisResults'] != null) {
          analysisResults = (data['analysisResults'] as List)
              .map((e) => IngredientAnalysisResult.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        return ScannedProduct(
          name: data['productName'] ?? 'Unknown',
          barcode: data['barcode'] ?? '',
          scanDate: (data['scannedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: (data['halalStatus'] as String? ?? 'UNKNOWN').toUpperCase(),
          origin: _inferOrigin(data['halalStatus'] ?? 'unknown'),
          risk: data['resultDetails'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          ingredients: (data['ingredients'] as String? ?? '').split(', ').where((s) => s.isNotEmpty).toList(),
          additives: (data['additives'] as String? ?? '').split(', ').where((s) => s.isNotEmpty).toList(),
          analysisResults: analysisResults,
        );
      }).toList();
    } catch (e) {
      print('Error fetching scan history: $e');
      return [];
    }
  }

  /// Helper to infer origin based on status for model compatibility
  String _inferOrigin(String status) {
    switch (status.toLowerCase()) {
      case 'halal': return 'Verified Halal';
      case 'haram': return 'Prohibited';
      case 'mushbooh': return 'Doubtful';
      default: return 'Unknown';
    }
  }

  /// Deletes all scan history for the user
  Future<void> clearHistory() async {
    final col = _scanCollection;
    if (col == null) return;

    try {
      final snapshot = await col.get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing scan history: $e');
    }
  }
  /// Deletes a single scan from Firestore by barcode (document id)
  Future<void> deleteScan(String barcode) async {
    final col = _scanCollection;
    if (col == null || barcode.isEmpty) return;

    try {
      await col.doc(barcode).delete();
    } catch (e) {
      print('Error deleting halal scan: $e');
    }
  }
  /// Saves user's custom preference for an additive
  Future<void> saveAdditiveOverride(String code, String status) async {
    final user = uid;
    if (user == null) return;

    try {
      _additiveOverrides[code] = status;
      await _db.collection('users').doc(user).collection('settings').doc('halalPreferences').set({
        'overrides': {
          code: status,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving additive override: $e');
    }
  }

  /// Fetches user's custom additive preferences
  Future<Map<String, String>> getAdditiveOverrides() async {
    final user = uid;
    if (user == null) return {};

    try {
      final doc = await _db.collection('users').doc(user).collection('settings').doc('halalPreferences').get();
      if (!doc.exists) {
        _additiveOverrides = {};
        return {};
      }

      final data = doc.data() as Map<String, dynamic>;
      final overrides = data['overrides'] as Map<String, dynamic>?;
      _additiveOverrides = overrides?.map((key, value) => MapEntry(key, value.toString())) ?? {};
      return _additiveOverrides;
    } catch (e) {
      print('Error fetching additive overrides: $e');
      return {};
    }
  }
}
