import 'package:flutter/material.dart';
import '../screens/halal_scanner/halal_scanner_home.dart';
import 'ingredient_ocr_cleaner.dart';

class IngredientAnalysisResult {
  final String ingredient;
  final String status;
  final String? reason;
  final bool isAdditive;
  final String? source;

  IngredientAnalysisResult({
    required this.ingredient,
    required this.status,
    this.reason,
    this.isAdditive = false,
    this.source,
  });

  Color get statusColor {
    switch (status) {
      case 'HARAM':
        return Colors.red;
      case 'MUSHBOOH':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'HARAM':
        return Icons.cancel;
      case 'MUSHBOOH':
        return Icons.warning;
      default:
        return Icons.check_circle;
    }
  }

  Map<String, dynamic> toJson() => {
    'ingredient': ingredient,
    'status': status,
    'reason': reason,
    'isAdditive': isAdditive,
    'source': source,
  };

  factory IngredientAnalysisResult.fromJson(Map<String, dynamic> json) {
    return IngredientAnalysisResult(
      ingredient: json['ingredient'] ?? '',
      status: json['status'] ?? 'HALAL',
      reason: json['reason'],
      isAdditive: json['isAdditive'] ?? false,
      source: json['source'],
    );
  }
}

class ProductAnalysisResult {
  final String overallStatus;
  final String riskLevel;
  final List<IngredientAnalysisResult> results;
  final List<String> haramIngredients;
  final List<String> mushboohIngredients;
  final List<String> halalIngredients;
  final String? apiResponse;
  final String productName;
  final String barcode;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> additives;

  ProductAnalysisResult({
    required this.overallStatus,
    required this.riskLevel,
    required this.results,
    required this.haramIngredients,
    required this.mushboohIngredients,
    required this.halalIngredients,
    this.apiResponse,
    required this.productName,
    required this.barcode,
    required this.imageUrl,
    required this.ingredients,
    required this.additives,
  });

  bool get hasHaram => haramIngredients.isNotEmpty;
  bool get hasMushbooh => mushboohIngredients.isNotEmpty;
  bool get isHalal => overallStatus == 'HALAL';

  ScannedProduct toScannedProduct() {
    return ScannedProduct(
      name: productName,
      imageUrl: imageUrl,
      barcode: barcode,
      scanDate: DateTime.now(),
      status: overallStatus,
      origin: _determineOrigin(),
      risk: riskLevel,
      ingredients: ingredients,
      additives: additives,
      analysisResults: results,
    );
  }

  String _determineOrigin() {
    if (haramIngredients.isNotEmpty) {
      for (String ingredient in haramIngredients) {
        String lower = ingredient.toLowerCase();
        if (lower.contains('pork') || lower.contains('pig') || 
            lower.contains('bacon') || lower.contains('ham') ||
            lower.contains('gelatin') || lower.contains('tallow') ||
            lower.contains('lard') || lower.contains('suet')) {
          return 'Animal (Haram Pork)';
        }
        if (lower.contains('cochineal') || lower.contains('carmine') || 
            lower.contains('insect') || lower.contains('shellac')) {
          return 'Insect (Haram)';
        }
        if (lower.contains('alcohol') || lower.contains('ethanol') ||
            lower.contains('wine') || lower.contains('beer')) {
          return 'Alcohol (Haram)';
        }
      }
    }

    final halalMeatKeywords = [
      'chicken', 'beef', 'mutton', 'lamb', 'sheep', 'goat', 'turkey', 'duck',
      'poultry', 'meat', 'veal'
    ];
    for (String ingredient in halalIngredients) {
      String lower = ingredient.toLowerCase();
      for (String kw in halalMeatKeywords) {
        if (lower.contains(kw)) {
          return 'Animal (Halal Meat)';
        }
      }
    }

    return overallStatus == 'HALAL' ? 'Plant/Chemical (Halal)' : 'Unclear Origin (Mushbooh)';
  }
}

class HalalAnalyzerService {
  /// Translates multi-language ingredient names into standardized English names.
  static String translateToEnglish(String ingredient) {
    String text = IngredientOcrCleaner.convertBengaliNumerals(ingredient).trim();
    String lower = text.toLowerCase();

    // Comprehensive multi-language ingredient dictionary
    final Map<String, String> dictionary = {
      // Bangla Food Ingredients & Additives
      'ভোজ্য তেল (পাম তেল)': 'Edible Oil (Palm Oil)',
      'ভোজ্য তেল': 'Edible Oil',
      'পাম তেল': 'Palm Oil',
      'সয়াবিন তেল': 'Soybean Oil',
      'সরিষার তেল': 'Mustard Oil',
      'উদ্ভিজ্জ তেল': 'Vegetable Oil',
      'সয়াবিন লেসিথিন': 'Soy Lecithin',
      'সূর্যমুখী লেসিথিন': 'Sunflower Lecithin',
      'সয়া লেসিথিন': 'Soy Lecithin',
      'লেসিথিন': 'Lecithin',
      'ট্যাপিওকা স্টার্চ': 'Tapioca Starch',
      'সোডিয়াম বাইকার্বোনেট (ই ৫০০ (ii))': 'Sodium Bicarbonate (E500(ii))',
      'সোডিয়াম বাইকার্বোনেট (ই ৫০০)': 'Sodium Bicarbonate (E500)',
      'সোডিয়াম বাইকার্বোনেট': 'Sodium Bicarbonate',
      'সাইট্রিক অ্যাসিড (ই ৩৩০)': 'Citric Acid (E330)',
      'সাইট্রিক অ্যাসিড': 'Citric Acid',
      'ই ৫০০ (ii)': 'E500(ii) (Sodium Bicarbonate)',
      'ই ৫০০': 'E500 (Sodium Bicarbonate)',
      'ই ৩৩০': 'E330 (Citric Acid)',
      'বিট লবণ': 'Black Salt',
      'লবণ': 'Salt',
      'মটর': 'Peas',
      'বাদাম': 'Nuts',
      'চিঁড়া': 'Flattened Rice',
      'চিড়া': 'Flattened Rice',
      'মরিচ': 'Chili',
      'এলাচ': 'Cardamom',
      'দারচিনি': 'Cinnamon',
      'জিরা': 'Cumin',
      'লবঙ্গ': 'Clove',
      'হলুদ': 'Turmeric',
      'গোলমরিচ': 'Black Pepper',
      'জোয়ান': 'Carom Seeds (Ajwain)',
      'গমের আটা': 'Wheat Flour',
      'আটা': 'Flour',
      'ময়দা': 'Wheat Flour',
      'সুজি': 'Semolina',
      'পানি': 'Water',
      'চিনি': 'Sugar',
      'দুধ': 'Milk',
      'মাখন': 'Butter',
      'পনির': 'Cheese',
      'ডিম': 'Egg',
      'ঘি': 'Ghee',
      'সরিষা': 'Mustard',
      'তিল': 'Sesame',
      'ধনে': 'Coriander',
      'ধনিয়া': 'Coriander',
      'পেঁয়াজ': 'Onion',
      'রসুন': 'Garlic',
      'আদা': 'Ginger',
      'চাট মসলা': 'Chaat Masala',
      'সিরকা': 'Vinegar',
      'ভিনেগার': 'Vinegar',
      'গুড়': 'Jaggery',
      'শূকরের মাংস': 'Pork',
      'শূকরের চর্বি': 'Pork Lard',
      'শুয়োরের মাংস': 'Pork',
      'মাংস': 'Meat',
      'মুরগি': 'Chicken',
      'গরুর মাংস': 'Beef',
      'মদ': 'Alcohol',
      'অ্যালকোহল': 'Alcohol',
      'জেলটিন': 'Gelatin',
      'সয়াবিন': 'Soybean',
      'উদ্ভিজ্জ': 'Vegetable',
      'ইমালসিফায়ার': 'Emulsifier',
      'অ্যারোমা': 'Flavoring',

      // Arabic
      'ليسيثين الصويا': 'Soy Lecithin',
      'ليسيثين عباد الشمس': 'Sunflower Lecithin',
      'ليسيثين': 'Lecithin',
      'دقيق القمح': 'Wheat Flour',
      'دقيق': 'Flour',
      'زيت النخيل': 'Palm Oil',
      'زيت نباتي': 'Vegetable Oil',
      'ملح': 'Salt',
      'ماء': 'Water',
      'سكر': 'Sugar',
      'حليب': 'Milk',
      'زبدة': 'Butter',
      'جبن': 'Cheese',
      'بيض': 'Egg',
      'لحم الخنزير': 'Pork',
      'دهن الخنزير': 'Pork Lard',
      'كحول': 'Alcohol',
      'جيلاتين': 'Gelatin',
      'مستحلب': 'Emulsifier',

      // French
      'lécithine de soja': 'Soy Lecithin',
      'lécolithine de soja': 'Soy Lecithin',
      'lécithine de tournesol': 'Sunflower Lecithin',
      'lécithine': 'Lecithin',
      'farine de blé': 'Wheat Flour',
      'farine': 'Flour',
      'blé': 'Wheat',
      'huile de palme': 'Palm Oil',
      'huile végétale': 'Vegetable Oil',
      'sucre': 'Sugar',
      'sel': 'Salt',
      'eau': 'Water',
      'lait': 'Milk',
      'beurre': 'Butter',
      'fromage': 'Cheese',
      'porc': 'Pork',
      'viande de porc': 'Pork',
      'saindoux': 'Pork Lard',
      'gélatine': 'Gelatin',
      'alcool': 'Alcohol',
      'émulsifiant': 'Emulsifier',

      // German
      'sojalecithin': 'Soy Lecithin',
      'sonnenblumenlecithin': 'Sunflower Lecithin',
      'lecithin': 'Lecithin',
      'weizenmehl': 'Wheat Flour',
      'weizen': 'Wheat',
      'mehl': 'Flour',
      'palmöl': 'Palm Oil',
      'pflanzenöl': 'Vegetable Oil',
      'zucker': 'Sugar',
      'salz': 'Salt',
      'wasser': 'Water',
      'milch': 'Milk',
      'butter': 'Butter',
      'käse': 'Cheese',
      'schweinefleisch': 'Pork',
      'schweineschmalz': 'Pork Lard',
      'schmalz': 'Lard',
      'gelatine': 'Gelatin',
      'alkohol': 'Alcohol',
      'emulgator': 'Emulsifier',

      // Spanish
      'lecitina de soya': 'Soy Lecithin',
      'lecitina de soja': 'Soy Lecithin',
      'lecitina de girasol': 'Sunflower Lecithin',
      'lecitina': 'Lecithin',
      'harina de trigo': 'Wheat Flour',
      'harina': 'Flour',
      'trigo': 'Wheat',
      'aceite de palma': 'Palm Oil',
      'aceite vegetal': 'Vegetable Oil',
      'aceite': 'Oil',
      'azúcar': 'Sugar',
      'sal': 'Salt',
      'agua': 'Water',
      'leche': 'Milk',
      'mantequilla': 'Butter',
      'queso': 'Cheese',
      'cerdo': 'Pork',
      'carne de cerdo': 'Pork',
      'manteca de cerdo': 'Pork Lard',
      'gelatina': 'Gelatin',
      'alcohol': 'Alcohol',
      'emulsionante': 'Emulsifier',
    };

    // First check exact / phrase match in dictionary
    for (var entry in dictionary.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return text.replaceAll(RegExp(RegExp.escape(entry.key), caseSensitive: false), entry.value);
      }
    }

    return text;
  }

  static bool _containsWord(String text, List<String> words) {
    for (String word in words) {
      RegExp regex = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      if (regex.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsENumber(String text, List<String> eNumbers) {
    for (String e in eNumbers) {
      RegExp regex = RegExp(r'\b' + RegExp.escape(e) + r'\b', caseSensitive: false);
      if (regex.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  /// Contextual single ingredient auditor
  static IngredientAnalysisResult _analyzeSingleIngredient(String ingredient) {
    String lower = ingredient.toLowerCase().trim();

    // 1. Check for plant / vegetable / microbial / synthetic qualifiers FIRST
    final plantQualifiers = [
      'soy', 'soya', 'sunflower', 'rapeseed', 'canola', 'vegetable', 'plant',
      'plant-based', 'vegan', 'microbial', 'fungal', 'synthetic', 'fruit',
      'cottonseed', 'corn', 'coconut', 'halal certified', 'halal', 'palm',
      'tapioca', 'peas', 'nuts', 'rice', 'salt', 'bicarbonate', 'citric', 'cardamom',
      'cinnamon', 'cumin', 'clove', 'turmeric', 'pepper', 'wheat', 'flour'
    ];

    bool hasPlantQualifier = false;
    for (String qual in plantQualifiers) {
      if (lower.contains(qual)) {
        hasPlantQualifier = true;
        break;
      }
    }

    // 2. Porcine / Pork derivatives (HARAM)
    final porkKeywords = [
      'pork', 'pig', 'porcine', 'bacon', 'ham', 'prosciutto', 'pancetta',
      'lard', 'strutto', 'swine', 'pork fat', 'pork belly', 'tallow', 'suet'
    ];

    if (_containsWord(lower, porkKeywords)) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Contains pork / porcine derivative - Strict Haram',
        source: 'Animal (Pork)',
      );
    }

    // 3. Alcohol & Intoxicants (HARAM)
    final alcoholKeywords = [
      'alcohol', 'ethanol', 'wine', 'beer', 'vodka', 'whiskey', 'whisky',
      'rum', 'gin', 'liquor', 'spirits', 'cider', 'mead', 'sake', 'soju', 'brandy'
    ];
    if (_containsWord(lower, alcoholKeywords) &&
        !lower.contains('cetyl alcohol') &&
        !lower.contains('stearyl alcohol') &&
        !lower.contains('fatty alcohol')) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Contains alcohol / intoxicant - Haram',
        source: 'Alcohol',
      );
    }

    // 4. Insects & Carmine E120 / Shellac (HARAM)
    if (_containsWord(lower, ['cochineal', 'carmine', 'crimson', 'shellac']) ||
        _containsENumber(lower, ['e120', 'e904'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Contains insect derivative (Carmine E120 / Shellac E904) - Haram',
        source: 'Insect',
      );
    }

    // 5. Gelatin (Check source)
    if (lower.contains('gelatin') || _containsENumber(lower, ['e441'])) {
      if (lower.contains('pork') || lower.contains('porcine')) {
        return IngredientAnalysisResult(
          ingredient: ingredient,
          status: 'HARAM',
          reason: 'Pork Gelatin - Haram',
          source: 'Animal (Pork)',
        );
      }
      if (lower.contains('fish') || lower.contains('pectin') || lower.contains('halal')) {
        return IngredientAnalysisResult(
          ingredient: ingredient,
          status: 'HALAL',
          reason: 'Halal/Fish/Plant-based Gelatin alternative - Halal',
          source: 'Fish/Plant',
        );
      }
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Gelatin source unstated (Usually porcine/non-dhabiha animal) - Haram/Mushbooh',
        source: 'Animal (Unstated)',
      );
    }

    // 6. Lecithin Context Handling (SOY / SUNFLOWER = HALAL, Unstated = MUSHBOOH)
    if (lower.contains('lecithin') || _containsENumber(lower, ['e322'])) {
      if (hasPlantQualifier) {
        return IngredientAnalysisResult(
          ingredient: ingredient,
          status: 'HALAL',
          reason: 'Plant-derived Lecithin (Soy/Sunflower/Vegetable) - Halal',
          source: 'Plant',
        );
      }
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'MUSHBOOH',
        reason: 'Lecithin source unstated (Often soy, but verify plant source)',
        source: 'Unclear',
      );
    }

    // 7. Glycerin / Glycerol Context Handling (VEGETABLE = HALAL, Unstated = MUSHBOOH)
    if (lower.contains('glycerin') || lower.contains('glycerol') || _containsENumber(lower, ['e422'])) {
      if (hasPlantQualifier) {
        return IngredientAnalysisResult(
          ingredient: ingredient,
          status: 'HALAL',
          reason: 'Vegetable Glycerin/Glycerol - Halal',
          source: 'Plant',
        );
      }
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'MUSHBOOH',
        reason: 'Glycerin source unstated (May be animal or plant fat)',
        source: 'Unclear',
      );
    }

    // 8. E500, E330, E471 Additives
    if (_containsENumber(lower, ['e500', 'e330', 'e500(ii)'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HALAL',
        reason: 'Safe mineral/acid compound (Sodium Bicarbonate / Citric Acid) - Halal',
        source: 'Mineral/Plant',
      );
    }

    // 9. Halal Meat / Poultry (Animal origin)
    final halalMeatKeywords = [
      'chicken', 'beef', 'mutton', 'lamb', 'sheep', 'goat', 'turkey', 'duck',
      'poultry', 'meat', 'veal'
    ];
    if (_containsWord(lower, halalMeatKeywords)) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HALAL',
        reason: 'Halal Meat / Poultry (Verify halal slaughter)',
        source: 'Animal',
      );
    }

    // Default Permissible
    return IngredientAnalysisResult(
      ingredient: ingredient,
      status: 'HALAL',
      reason: 'No haram concerns detected',
      source: 'Plant/General',
    );
  }

  static IngredientAnalysisResult _analyzeSingleAdditive(String additive) {
    String upper = additive.toUpperCase().trim();
    String lower = additive.toLowerCase().trim();

    final haramAdditives = {
      'E120': 'Cochineal/Carmine (Insect derivative - Haram)',
      'E441': 'Gelatin (Animal derivative - Usually Haram)',
      'E542': 'Bone phosphate (Animal derivative - Haram)',
      'E904': 'Shellac (Insect resin - Haram)',
      'E920': 'L-cysteine (May be derived from human hair/feathers - Haram)',
    };

    if (haramAdditives.containsKey(upper)) {
      return IngredientAnalysisResult(
        ingredient: additive,
        status: 'HARAM',
        reason: haramAdditives[upper],
        isAdditive: true,
        source: 'Additive (Haram)',
      );
    }

    final mushboohAdditives = {
      'E322': 'Lecithin (Verify if soy/plant derived)',
      'E422': 'Glycerol (Verify if vegetable derived)',
      'E471': 'Mono- & Diglycerides (Verify if plant derived)',
      'E433': 'Polysorbate 80 (Source unstated)',
    };

    if (mushboohAdditives.containsKey(upper)) {
      if (lower.contains('soy') || lower.contains('plant') || lower.contains('vegetable')) {
        return IngredientAnalysisResult(
          ingredient: additive,
          status: 'HALAL',
          reason: '${mushboohAdditives[upper]} - Plant source specified (Halal)',
          isAdditive: true,
          source: 'Plant Additive',
        );
      }
      return IngredientAnalysisResult(
        ingredient: additive,
        status: 'MUSHBOOH',
        reason: mushboohAdditives[upper],
        isAdditive: true,
        source: 'Additive (Doubtful)',
      );
    }

    return IngredientAnalysisResult(
      ingredient: additive,
      status: 'HALAL',
      reason: 'Safe additive',
      isAdditive: true,
      source: 'Additive (Halal)',
    );
  }

  static ProductAnalysisResult analyzeIngredients({
    required List<String> ingredients,
    required List<String> additives,
    required String productName,
    required String barcode,
    required String imageUrl,
  }) {
    List<IngredientAnalysisResult> results = [];
    List<String> haramIngredients = [];
    List<String> mushboohIngredients = [];
    List<String> halalIngredients = [];

    String nameLower = productName.toLowerCase().trim();

    // Check product title for pork keywords
    final porkKeywords = [
      'bacon', 'pork', 'ham', 'prosciutto', 'pancetta', 'guanciale',
      'speck', 'pepperoni', 'salami', 'chorizo', 'lard', 'strutto', 'pig', 'swine'
    ];

    for (String keyword in porkKeywords) {
      if (_containsWord(nameLower, [keyword])) {
        String porkReason = 'Product title contains $keyword - Haram';
        results.add(IngredientAnalysisResult(
          ingredient: 'Product: $productName',
          status: 'HARAM',
          reason: porkReason,
          source: 'Animal (Pork)',
        ));
        haramIngredients.add('$productName ($porkReason)');

        return ProductAnalysisResult(
          overallStatus: 'HARAM',
          riskLevel: 'Contains pork - Haram',
          results: results,
          haramIngredients: haramIngredients,
          mushboohIngredients: mushboohIngredients,
          halalIngredients: halalIngredients,
          apiResponse: 'Pork product detected in title',
          productName: productName,
          barcode: barcode,
          imageUrl: imageUrl,
          ingredients: ingredients,
          additives: additives,
        );
      }
    }

    // Translate ingredients into English first
    List<String> translatedIngredients = ingredients
        .map((ing) => translateToEnglish(ing))
        .toList();

    List<String> translatedAdditives = additives
        .map((add) => translateToEnglish(add))
        .toList();

    for (int i = 0; i < translatedIngredients.length; i++) {
      String original = translatedIngredients[i];
      if (original.trim().isEmpty) continue;

      IngredientAnalysisResult result = _analyzeSingleIngredient(original);
      results.add(result);

      if (result.status == 'HARAM') {
        haramIngredients.add(original);
      } else if (result.status == 'MUSHBOOH') {
        mushboohIngredients.add(original);
      } else {
        halalIngredients.add(original);
      }
    }

    // Cross-reference: collect E-numbers already confirmed HALAL from ingredients.
    // Maps e.g. 'E322' → 'HALAL' so the additive loop can skip duplicates.
    final Map<String, String> resolvedENumbers = {};
    for (final r in results) {
      final eLower = r.ingredient.toLowerCase();
      // Lecithin → E322
      if (eLower.contains('lecithin')) {
        resolvedENumbers['E322'] = r.status;
      }
      // Glycerin / Glycerol → E422
      if (eLower.contains('glycerin') || eLower.contains('glycerol')) {
        resolvedENumbers['E422'] = r.status;
      }
      // Mono- & Diglycerides → E471
      if (eLower.contains('monoglyceride') || eLower.contains('diglyceride')) {
        resolvedENumbers['E471'] = r.status;
      }
      // Polysorbate 80 → E433
      if (eLower.contains('polysorbate')) {
        resolvedENumbers['E433'] = r.status;
      }
      // Gelatin → E441
      if (eLower.contains('gelatin')) {
        resolvedENumbers['E441'] = r.status;
      }
      // Also capture any bare E-number already in the ingredient text
      final eMatch = RegExp(r'\bE\d{3,4}\b', caseSensitive: false).firstMatch(r.ingredient);
      if (eMatch != null) {
        resolvedENumbers[eMatch.group(0)!.toUpperCase()] = r.status;
      }
    }

    for (int i = 0; i < translatedAdditives.length; i++) {
      String original = translatedAdditives[i];
      if (original.trim().isEmpty) continue;

      // Check if this additive's E-number was already resolved by an ingredient
      final eMatch = RegExp(r'\bE\d{3,4}\b', caseSensitive: false).firstMatch(original);
      if (eMatch != null) {
        final eKey = eMatch.group(0)!.toUpperCase();
        if (resolvedENumbers.containsKey(eKey)) {
          final inheritedStatus = resolvedENumbers[eKey]!;
          // Only skip/upgrade if the ingredient already confirmed HALAL.
          // This prevents bare "E322" from adding a separate MUSHBOOH entry
          // when "Sunflower Lecithin" was already analyzed as HALAL.
          if (inheritedStatus == 'HALAL') {
            results.add(IngredientAnalysisResult(
              ingredient: original,
              status: 'HALAL',
              reason: 'Source confirmed Halal by ingredient list (same compound)',
              isAdditive: true,
              source: 'Plant Additive',
            ));
            halalIngredients.add(original);
            continue;
          }
        }
      }

      IngredientAnalysisResult result = _analyzeSingleAdditive(original);
      results.add(result);

      if (result.status == 'HARAM') {
        haramIngredients.add(original);
      } else if (result.status == 'MUSHBOOH') {
        mushboohIngredients.add(original);
      } else {
        halalIngredients.add(original);
      }
    }

    String overallStatus;
    String riskLevel;

    if (haramIngredients.isNotEmpty) {
      overallStatus = 'HARAM';
      riskLevel = 'Contains ${haramIngredients.length} Haram ingredient(s)';
    } else if (mushboohIngredients.isNotEmpty) {
      overallStatus = 'MUSHBOOH';
      riskLevel = 'Contains ${mushboohIngredients.length} Mushbooh (doubtful) ingredient(s)';
    } else {
      overallStatus = 'HALAL';
      riskLevel = 'All ${halalIngredients.length} ingredients verified Halal';
    }

    return ProductAnalysisResult(
      overallStatus: overallStatus,
      riskLevel: riskLevel,
      results: results,
      haramIngredients: haramIngredients,
      mushboohIngredients: mushboohIngredients,
      halalIngredients: halalIngredients,
      apiResponse: null,
      productName: productName,
      barcode: barcode,
      imageUrl: imageUrl,
      ingredients: translatedIngredients,
      additives: translatedAdditives,
    );
  }

  static String extractCode(String ingredient) {
    RegExp regex = RegExp(r'E\d{1,4}', caseSensitive: false);
    final match = regex.firstMatch(ingredient);
    if (match != null) {
      return match.group(0)!.toUpperCase();
    }
    return 'ING';
  }
}
