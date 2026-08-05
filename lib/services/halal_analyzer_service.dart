import 'package:flutter/material.dart';
import '../screens/halal_scanner/halal_scanner_home.dart';

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
          return 'Animal (Haram)';
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
    return overallStatus == 'HALAL' ? 'Plant/Chemical (Halal)' : 'Unknown/Unclear';
  }
}

class HalalAnalyzerService {
  static String _translateToEnglish(String ingredient) {
    final Map<String, String> translations = {
      'tarwegluten': 'Wheat Gluten',
      'tarwemeel': 'Wheat Flour',
      'palmolie': 'Palm Oil',
      'zout': 'Salt',
      'water': 'Water',
      'suiker': 'Sugar',
      'zetmeel': 'Starch',
      'verdikkingsmiddel': 'Thickener',
      'emulgator': 'Emulsifier',
      'conserveermiddel': 'Preservative',
      'kleurstof': 'Colorant',
      'antioxidant': 'Antioxidant',
      'zuurteregelaar': 'Acidity Regulator',
      'gist': 'Yeast',
      'boter': 'Butter',
      'melk': 'Milk',
      'kaas': 'Cheese',
      'vlees': 'Meat',
      'kip': 'Chicken',
      'rundvlees': 'Beef',
      'varkensvlees': 'Pork',
      'vis': 'Fish',
      'farine': 'Flour',
      'blé': 'Wheat',
      'sucre': 'Sugar',
      'sel': 'Salt',
      'huile': 'Oil',
      'beurre': 'Butter',
      'lait': 'Milk',
      'fromage': 'Cheese',
      'viande': 'Meat',
      'poulet': 'Chicken',
      'bœuf': 'Beef',
      'porc': 'Pork',
      'poisson': 'Fish',
      'eau': 'Water',
      'épaississant': 'Thickener',
      'émulsifiant': 'Emulsifier',
      'conservateur': 'Preservative',
      'colorant': 'Colorant',
      'weizen': 'Wheat',
      'mehl': 'Flour',
      'zucker': 'Sugar',
      'salz': 'Salt',
      'öl': 'Oil',
      'butter': 'Butter',
      'milch': 'Milk',
      'käse': 'Cheese',
      'fleisch': 'Meat',
      'huhn': 'Chicken',
      'rindfleisch': 'Beef',
      'schweinefleisch': 'Pork',
      'fisch': 'Fish',
      'wasser': 'Water',
       'verdickungsmittel': 'Thickener',
       'konservierungsmittel': 'Preservative',
      'farbstoff': 'Colorant',
      'harina': 'Flour',
      'trigo': 'Wheat',
      'azúcar': 'Sugar',
      'sal': 'Salt',
      'aceite': 'Oil',
      'mantequilla': 'Butter',
      'leche': 'Milk',
      'queso': 'Cheese',
      'carne': 'Meat',
      'pollo': 'Chicken',
      'cerdo': 'Pork',
      'pescado': 'Fish',
      'agua': 'Water',
      'espesante': 'Thickener',
      'emulsionante': 'Emulsifier',
      'conservante': 'Preservative',
      'colorante': 'Colorant',
      'farina': 'Flour',
      'grano': 'Wheat',
      'zucchero': 'Sugar',
      'sale': 'Salt',
      'olio': 'Oil',
      'burro': 'Butter',
      'latte': 'Milk',
      'formaggio': 'Cheese',
      'maiale': 'Pork',
      'pesce': 'Fish',
       'acqua': 'Water',
       'addensante': 'Thickener',
       'mąka': 'Flour',
      'pszenica': 'Wheat',
      'cukier': 'Sugar',
      'sól': 'Salt',
      'olej': 'Oil',
      'masło': 'Butter',
      'mleko': 'Milk',
      'ser': 'Cheese',
      'mięso': 'Meat',
      'kurczak': 'Chicken',
      'wieprzowina': 'Pork',
      'ryba': 'Fish',
       'woda': 'Water',
       'zagęszczacz': 'Thickener',
       'konserwant': 'Preservative',
       'barwnik': 'Colorant',
    };

    String lower = ingredient.toLowerCase().trim();
    for (var entry in translations.entries) {
      if (lower.contains(entry.key) || lower == entry.key) {
        return ingredient.replaceFirst(RegExp(entry.key, caseSensitive: false), entry.value);
      }
    }

    return ingredient;
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

  static IngredientAnalysisResult _analyzeSingleIngredient(String ingredient) {
    String lower = ingredient.toLowerCase().trim();

    if (_containsWord(lower, ['pork', 'pig', 'bacon', 'ham', 'lard', 'tallow', 'suet', 'gelatin', 'collagen'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Contains pork/animal derivative',
        source: 'local',
      );
    }

    if (_containsWord(lower, ['alcohol', 'ethanol', 'wine', 'beer', 'vodka', 'whiskey', 'whisky',
                              'rum', 'gin', 'liquor', 'booze', 'spirits', 'cider', 'mead', 'sake', 'soju', 'brandy'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Contains alcohol',
        source: 'local',
      );
    }

    if (_containsWord(lower, ['cochineal', 'carmine', 'crimson', 'insect', 'beetle', 'shellac'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Contains insect product',
        source: 'local',
      );
    }

    if (_containsWord(lower, ['rennet', 'pepsin', 'lipase', 'trypsin', 'chymosin'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Contains animal enzyme',
        source: 'local',
      );
    }

    if (_containsENumber(lower, ['e120', 'e441', 'e542', 'e901', 'e904', 'e1105', 'e422', 'e471', 'e920'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'HARAM',
        reason: 'Haram additive',
        source: 'local',
      );
    }

    if (_containsWord(lower, ['lecithin', 'glycerin', 'glycerol', 'natural flavor', 'natural flavour',
                              'artificial flavor', 'artificial flavour', 'enzyme', 'emulsifier', 'stabilizer', 'thickener'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'MUSHBOOH',
        reason: 'Source unclear',
        source: 'local',
      );
    }

    if (_containsENumber(lower, ['e322', 'e433', 'e434', 'e435', 'e436'])) {
      return IngredientAnalysisResult(
        ingredient: ingredient,
        status: 'MUSHBOOH',
        reason: 'Source unclear',
        source: 'local',
      );
    }

    return IngredientAnalysisResult(
      ingredient: ingredient,
      status: 'HALAL',
      reason: 'No concerns detected',
      source: 'local',
    );
  }

  static IngredientAnalysisResult _analyzeSingleAdditive(String additive) {
    String upper = additive.toUpperCase().trim();
    String lower = additive.toLowerCase().trim();

    final haramAdditives = {
      'E120': 'Cochineal/Carmine (insect)',
      'E441': 'Gelatin (animal)',
      'E542': 'Bone phosphate (animal)',
      'E901': 'Beeswax (insect)',
      'E904': 'Shellac (insect)',
      'E1105': 'Lysozyme (may be from eggs)',
      'E422': 'Glycerol (may be animal)',
      'E471': 'Mono- and diglycerides (may be animal)',
      'E920': 'L-cysteine (may be from hair/feathers)',
    };

    if (haramAdditives.containsKey(upper)) {
      return IngredientAnalysisResult(
        ingredient: additive,
        status: 'HARAM',
        reason: haramAdditives[upper],
        isAdditive: true,
        source: 'local',
      );
    }

    final mushboohAdditives = {
      'E322': 'Lecithin (source unclear)',
      'E433': 'Polysorbate 80 (source unclear)',
      'E434': 'Polysorbate 40 (source unclear)',
      'E435': 'Polysorbate 60 (source unclear)',
      'E436': 'Polysorbate 65 (source unclear)',
    };

    if (mushboohAdditives.containsKey(upper)) {
      return IngredientAnalysisResult(
        ingredient: additive,
        status: 'MUSHBOOH',
        reason: mushboohAdditives[upper],
        isAdditive: true,
        source: 'local',
      );
    }

    if (_containsWord(lower, ['gelatin', 'cochineal', 'carmine', 'insect', 'shellac'])) {
      return IngredientAnalysisResult(
        ingredient: additive,
        status: 'HARAM',
        reason: 'Contains haram ingredient',
        isAdditive: true,
        source: 'local',
      );
    }

    return IngredientAnalysisResult(
      ingredient: additive,
      status: 'HALAL',
      reason: 'No concerns detected',
      isAdditive: true,
      source: 'local',
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

    final porkKeywords = [
      'bacon', 'pork', 'ham', 'prosciutto', 'pancetta', 'guanciale',
      'speck', 'pepperoni', 'salami', 'chorizo', 'sausage',
      'hot dog', 'frankfurter', 'bratwurst', 'kielbasa',
      'lard', 'tallow', 'suet', 'strutto', 'pig', 'swine', 'porcine',
      'cured meat', 'smoked meat', 'pork meat', 'pork belly'
    ];

    bool isPorkProduct = false;
    String porkReason = '';

    for (String keyword in porkKeywords) {
      if (nameLower.contains(keyword)) {
        isPorkProduct = true;
        if (keyword == 'bacon') {
          porkReason = 'Bacon is pork - Haram';
        } else if (keyword == 'ham') {
          porkReason = 'Ham is pork - Haram';
        } else if (keyword == 'pork') {
          porkReason = 'Pork product - Haram';
        } else {
          porkReason = 'Product contains $keyword - Haram';
        }
        break;
      }
    }

    if (isPorkProduct) {
      results.add(IngredientAnalysisResult(
        ingredient: '⚠️ Product: $productName',
        status: 'HARAM',
        reason: porkReason,
        source: 'local',
      ));
      haramIngredients.add('$productName ($porkReason)');

      return ProductAnalysisResult(
        overallStatus: 'HARAM',
        riskLevel: 'Contains pork - Haram',
        results: results,
        haramIngredients: haramIngredients,
        mushboohIngredients: mushboohIngredients,
        halalIngredients: halalIngredients,
        apiResponse: 'Pork product detected',
        productName: productName,
        barcode: barcode,
        imageUrl: imageUrl,
        ingredients: ingredients,
        additives: additives,
      );
    }

    final alcoholKeywords = ['beer', 'wine', 'vodka', 'whiskey', 'whisky', 'rum', 'gin', 'liquor',
                             'ale', 'lager', 'stout', 'champagne', 'brandy', 'cider', 'mead', 'sake', 'soju'];
    bool isAlcoholProduct = false;
    String alcoholReason = '';

    for (String keyword in alcoholKeywords) {
      if (nameLower.contains(keyword)) {
        isAlcoholProduct = true;
        alcoholReason = 'Product contains alcohol - Haram';
        break;
      }
    }

    if (isAlcoholProduct) {
      results.add(IngredientAnalysisResult(
        ingredient: '⚠️ Product: $productName',
        status: 'HARAM',
        reason: alcoholReason,
        source: 'local',
      ));
      haramIngredients.add('$productName (Alcohol product)');

      return ProductAnalysisResult(
        overallStatus: 'HARAM',
        riskLevel: 'Contains alcohol - Haram',
        results: results,
        haramIngredients: haramIngredients,
        mushboohIngredients: mushboohIngredients,
        halalIngredients: halalIngredients,
        apiResponse: 'Alcohol product detected',
        productName: productName,
        barcode: barcode,
        imageUrl: imageUrl,
        ingredients: ingredients,
        additives: additives,
      );
    }

    List<String> translatedIngredients = ingredients
        .map((ing) => _translateToEnglish(ing))
        .toList();

    List<String> translatedAdditives = additives
        .map((add) => _translateToEnglish(add))
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

    for (int i = 0; i < translatedAdditives.length; i++) {
      String original = translatedAdditives[i];
      if (original.trim().isEmpty) continue;

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
      riskLevel = 'Contains Haram ingredients';
    } else if (mushboohIngredients.isNotEmpty) {
      overallStatus = 'MUSHBOOH';
      riskLevel = 'Contains Mushbooh ingredients';
    } else {
      overallStatus = 'HALAL';
      riskLevel = additives.length > 5 ? 'Safe - Few additives' : 'Safe - No concerns';
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
