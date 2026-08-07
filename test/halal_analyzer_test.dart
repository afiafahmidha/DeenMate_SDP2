import 'package:flutter_test/flutter_test.dart';
import 'package:deenmate_sdp2/services/halal_analyzer_service.dart';
import 'package:deenmate_sdp2/services/ingredient_ocr_cleaner.dart';

void main() {
  group('Bengali Ingredient Translation & OCR Tests', () {
    test('Translates Bengali package ingredients to English', () {
      final banglaIngredients = [
        'মটর',
        'ভোজ্য তেল (পাম তেল)',
        'বাদাম',
        'চিঁড়া',
        'ট্যাপিওকা স্টার্চ',
        'মরিচ',
        'বিট লবণ',
        'লবণ',
        'সোডিয়াম বাইকার্বোনেট (ই ৫০০ (ii))',
        'সাইট্রিক অ্যাসিড (ই ৩৩০)',
        'এলাচ',
        'দারচিনি',
        'জিরা',
        'লবঙ্গ',
        'হলুদ',
        'গোলমরিচ',
        'জোয়ান',
      ];

      final result = HalalAnalyzerService.analyzeIngredients(
        ingredients: banglaIngredients,
        additives: [],
        productName: 'Bangla Chanachur',
        barcode: '890123456',
        imageUrl: '',
      );

      expect(result.overallStatus, equals('HALAL'));
      expect(result.ingredients, contains('Peas'));
      expect(result.ingredients, contains('Edible Oil (Palm Oil)'));
      expect(result.ingredients, contains('Nuts'));
      expect(result.ingredients, contains('Flattened Rice'));
      expect(result.ingredients, contains('Tapioca Starch'));
      expect(result.ingredients, contains('Chili'));
      expect(result.ingredients, contains('Salt'));
      expect(result.ingredients, contains('Turmeric'));
    });

    test('Strips ML Kit Latin OCR garbage tokens', () {
      String rawText = '''
fsyt
bytfrs t 15
xfs
fR ayrs ( ( co0 (ii), 000), q5, iatbfP, forst, K,
উপাদান: মটর, ভোজ্য তেল (পাম তেল), বাদাম।
      ''';

      List<String> cleaned = IngredientOcrCleaner.cleanAndExtract(rawText);
      expect(cleaned, contains('মটর'));
      expect(cleaned, contains('ভোজ্য তেল (পাম তেল)'));
      expect(cleaned, contains('বাদাম'));
      expect(cleaned, isNot(contains('fsyt')));
      expect(cleaned, isNot(contains('xfs')));
    });
  });
}
