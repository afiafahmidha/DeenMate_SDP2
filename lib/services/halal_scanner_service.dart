import 'dart:async';
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

  Future<String?> _readyUid() async {
    final current = uid;
    if (current != null) return current;
    try {
      final user = await _auth.authStateChanges()
          .firstWhere((value) => value != null)
          .timeout(const Duration(seconds: 8));
      return user?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference? get _scanCollection {
    final user = uid;
    if (user == null) return null;
    return _db.collection('users').doc(user).collection('halalScans');
  }

  CollectionReference<Map<String, dynamic>> get _communityProducts =>
      _db.collection('halalProducts');

  String _normalizeBarcode(String value) {
    // Retail barcodes are numeric; normalize spaces/dashes while preserving
    // leading zeroes so manual entry and camera scans resolve the same doc.
    final trimmed = value.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isNotEmpty ? digits : trimmed;
  }

  /// Looks up a product contributed by another scanner user.
  Future<ScannedProduct?> getCommunityProduct(String barcode) async {
    final rawBarcode = barcode.trim();
    final normalizedBarcode = _normalizeBarcode(barcode);
    if (normalizedBarcode.isEmpty) return null;
    try {
      // Prefer the canonical numeric document id, then support products
      // created by older builds with a raw/trimmed barcode id or field.
      DocumentSnapshot<Map<String, dynamic>>? snapshot =
          await _communityProducts.doc(normalizedBarcode).get();
      if (!(snapshot.exists) && rawBarcode.isNotEmpty && rawBarcode != normalizedBarcode) {
        snapshot = await _communityProducts.doc(rawBarcode).get();
      }
      if (!(snapshot.exists)) {
        for (final value in <String>{normalizedBarcode, rawBarcode}) {
          if (value.isEmpty) continue;
          final matches = await _communityProducts
              .where('barcode', isEqualTo: value)
              .limit(1)
              .get();
          if (matches.docs.isNotEmpty) {
            snapshot = matches.docs.first;
            break;
          }
        }
      }
      if (snapshot == null || !snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;

      List<IngredientAnalysisResult>? analysisResults;
      final rawResults = data['analysisResults'];
      if (rawResults is List) {
        analysisResults = rawResults
            .whereType<Map>()
            .map((e) => IngredientAnalysisResult.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList();
      }

      final ingredients = _stringList(data['ingredients']);
      final additives = _stringList(data['additives']);
      final storedStatus = ((data['halalStatus'] as String?) ?? 'UNKNOWN').toUpperCase();
      final normalizedStatus = ingredients.isEmpty && additives.isEmpty ? 'UNKNOWN' : storedStatus;

      return ScannedProduct(
        name: (data['productName'] as String?)?.trim().isNotEmpty == true
            ? data['productName'] as String
            : 'Community product',
        barcode: (data['barcode'] as String?) ?? normalizedBarcode,
        scanDate: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: normalizedStatus,
        origin: _inferOrigin(normalizedStatus),
        risk: ingredients.isEmpty && additives.isEmpty
            ? 'No ingredients available for analysis'
            : (data['resultDetails'] as String?) ?? 'Community contribution',
        imageUrl: (data['imageUrl'] as String?) ?? '',
        certificationImageUrl: (data['certificationImageUrl'] as String?) ?? '',
        ingredients: ingredients,
        additives: additives,
        analysisResults: analysisResults,
        source: (data['source'] as String?) ?? 'community',
        moderationStatus: (data['moderationStatus'] as String?) ?? 'community',
      );
    } catch (e) {
      print('Error fetching community halal product: $e');
      return null;
    }
  }

  /// Publishes the current scan as a reusable community product.
  /// The barcode document makes later scans resolve without Open Food Facts.
  Future<void> upsertCommunityProduct(ScannedProduct product) async {
    final normalizedBarcode = _normalizeBarcode(product.barcode);
    final readyUserId = await _readyUid();
    if (readyUserId == null || normalizedBarcode.isEmpty) return;
    try {
      await _communityProducts.doc(normalizedBarcode).set({
        'barcode': normalizedBarcode,
        'productName': product.name,
        'ingredients': product.ingredients,
        'additives': product.additives,
        'halalStatus': product.status,
        'resultDetails': product.risk,
        'imageUrl': product.imageUrl,
        'certificationImageUrl': product.certificationImageUrl,
        'analysisResults': product.analysisResults?.map((e) => e.toJson()).toList(),
        'source': product.source == 'unknown' ? 'community' : product.source,
        'submittedBy': readyUserId,
        'moderationStatus': 'community',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving community halal product: $e');
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    if (value is String) return value.split(', ').where((e) => e.isNotEmpty).toList();
    return <String>[];
  }

  /// Saves a scanned product to Firestore
  Future<void> saveScan(ScannedProduct product) async {
    final readyUserId = await _readyUid();
    if (readyUserId == null) {
      print('Cannot save halal scan: User not authenticated (UID is null)');
      return;
    }
    final col = _db.collection('users').doc(readyUserId).collection('halalScans');

    final normalizedBarcode = _normalizeBarcode(product.barcode);
    final docId = normalizedBarcode.isNotEmpty ? normalizedBarcode : DateTime.now().millisecondsSinceEpoch.toString();
    try {
      await col.doc(docId).set({
        'barcode': normalizedBarcode,
        'productName': product.name,
        'ingredients': product.ingredients.join(', '),
        'additives': product.additives.join(', '),
        'halalStatus': product.status.toLowerCase(),
        'resultDetails': product.risk,
        'imageUrl': product.imageUrl,
        'certificationImageUrl': product.certificationImageUrl,
        'scannedAt': FieldValue.serverTimestamp(),
        // Store analysis results as a list of maps
        
        'analysisResults': product.analysisResults?.map((e) => e.toJson()).toList(),
        'source': product.source,
        'moderationStatus': product.moderationStatus,
      }, SetOptions(merge: true));
      print('Halal scan saved successfully: ${product.name}');
    } catch (e) {
      print('Error saving personal halal scan: $e');
    }

    // Keep this independent from the private-history write. A stale rules
    // deployment or a private-write failure must not prevent a new product
    // from reaching the shared catalogue.
    // Any locally analysed/manual product is publishable. Only products that
    // came directly from Open Food Facts should stay external-only.
    if (product.source != 'open_food_facts') {
      await upsertCommunityProduct(product);
    }
  }

  /// Fetches the last scanned products from Firestore
  Future<List<ScannedProduct>> getScanHistory({int limit = 20}) async {
    final readyUserId = await _readyUid();
    if (readyUserId == null) return [];
    final col = _db.collection('users').doc(readyUserId).collection('halalScans');

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

        final ingredients = (data['ingredients'] as String? ?? '')
            .split(', ')
            .where((s) => s.isNotEmpty)
            .toList();
        final additives = (data['additives'] as String? ?? '')
            .split(', ')
            .where((s) => s.isNotEmpty)
            .toList();
        final storedStatus = (data['halalStatus'] as String? ?? 'UNKNOWN').toUpperCase();
        final normalizedStatus = ingredients.isEmpty && additives.isEmpty ? 'UNKNOWN' : storedStatus;

        return ScannedProduct(
          name: data['productName'] ?? 'Unknown',
          barcode: data['barcode'] ?? '',
          scanDate: (data['scannedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: normalizedStatus,
          origin: _inferOrigin(normalizedStatus),
          risk: ingredients.isEmpty && additives.isEmpty
              ? 'No ingredients available for analysis'
              : (data['resultDetails'] ?? ''),
          imageUrl: data['imageUrl'] ?? '',
          certificationImageUrl: data['certificationImageUrl'] ?? '',
          ingredients: ingredients,
          additives: additives,
          analysisResults: analysisResults,
          source: (data['source'] as String?) ?? 'unknown',
          moderationStatus: (data['moderationStatus'] as String?) ?? 'unverified',
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
    if (barcode.isEmpty) return;
    final readyUserId = await _readyUid();
    if (readyUserId == null) return;
    final col = _db.collection('users').doc(readyUserId).collection('halalScans');

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
