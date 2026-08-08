import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'halal_analyzer_service.dart';

class GeminiHalalService {
  
  static String apiKey = 'AQ.Ab8RN6JA5Vdi1MD1q5RczYdgs2SDNCq1NQQiGg2pwF8pk49Qiw';

  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Set the Gemini API key at runtime if provided.
  static void setApiKey(String key) {
    apiKey = key.trim();
  }

  /// Analyze image directly with Gemini Vision API.
  static Future<ProductAnalysisResult?> analyzeImageWithGemini({
    required File imageFile,
    required String productName,
    required String barcode,
  }) async {
    if (apiKey.isEmpty) {
      debugPrint('[GeminiHalalService] No Gemini API key provided. Falling back to local smart engine.');
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse('$_geminiEndpoint?key=$apiKey');

      final promptText = '''
You are an expert Islamic Halal Food & Ingredient Auditor and Scholar.
Analyze the product packaging image provided.

INSTRUCTIONS:
1. Locate and extract ONLY the ingredient list from the packaging, ignoring all marketing text, net weight, nutrition table numbers, dates, and manufacturer information.
2. The packaging text might be in ANY language (Bangla, French, Arabic, German, Spanish, Italian, Turkish, Urdu, Hindi, Japanese, Chinese, etc.).
3. Translate EVERY single ingredient into standard, clear English.
4. Perform contextual Halal auditing based on authentic Islamic Dietary Laws:
   - Soy Lecithin, Sunflower Lecithin, Plant-based Lecithin, Vegetable Glycerin, Microbial Rennet, Fruit Pectin, Plant Mono/Diglycerides (E471) = HALAL.
   - Pork, Porcine, Pig, Lard, Bacon, Ham, Pork Gelatin, Alcohol, Wine, Beer, Cochineal/Carmine E120, Shellac E904 = HARAM.
   - Unstated/Ambiguous Lecithin, Unstated Gelatin, Unstated Glycerin, Unstated E471, Unstated Rennet = MUSHBOOH (Doubtful).
5. Output strict JSON matching this exact structure:
{
  "overallStatus": "HALAL" | "HARAM" | "MUSHBOOH",
  "riskLevel": "Short summary of findings",
  "ingredients": [
    {
      "ingredient": "Translated English Ingredient Name",
      "status": "HALAL" | "HARAM" | "MUSHBOOH",
      "reason": "Detailed justification explaining origin (plant, animal, pork, alcohol, etc.)",
      "isAdditive": false,
      "source": "Plant / Animal / Insect / Alcohol / Chemical"
    }
  ]
}
Return ONLY valid raw JSON with no markdown formatting around it.
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': promptText},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 1024,
        }
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String textResponse =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        return _parseGeminiJsonResponse(
          textResponse: textResponse,
          productName: productName,
          barcode: barcode,
          imageUrl: imageFile.path,
        );
      } else {
        debugPrint('[GeminiHalalService] Vision API error status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[GeminiHalalService] Vision API exception: $e');
      return null;
    }
  }

  /// Analyze text directly with Gemini AI Text API.
  static Future<ProductAnalysisResult?> analyzeTextWithGemini({
    required String rawText,
    required String productName,
    required String barcode,
    required String imageUrl,
  }) async {
    if (apiKey.isEmpty) {
      debugPrint('[GeminiHalalService] No Gemini API key provided. Falling back to local engine.');
      return null;
    }

    try {
      final url = Uri.parse('$_geminiEndpoint?key=$apiKey');

      final promptText = '''
You are an expert Islamic Halal Food & Ingredient Auditor and Scholar.
Analyze the following extracted text from food packaging:

"$rawText"

INSTRUCTIONS:
1. Extract ONLY food ingredients, discarding net weights, dates, nutrition facts, storage tips.
2. Input text might be in ANY language (Bangla, French, Arabic, German, Spanish, Italian, Turkish, Urdu, Hindi, etc.).
3. Translate ALL ingredients into English.
4. Perform contextual Halal auditing:
   - Soy Lecithin, Sunflower Lecithin, Plant Lecithin, Vegetable Glycerin, Microbial Rennet, Fruit Pectin, Plant E471 = HALAL.
   - Pork, Porcine, Lard, Bacon, Ham, Pork Gelatin, Alcohol, Wine, Carmine E120 = HARAM.
   - Unstated Lecithin, Unstated Gelatin, Unstated Glycerin, Unstated E471 = MUSHBOOH.
5. Return JSON ONLY matching:
{
  "overallStatus": "HALAL" | "HARAM" | "MUSHBOOH",
  "riskLevel": "Short summary",
  "ingredients": [
    {
      "ingredient": "Translated English Ingredient Name",
      "status": "HALAL" | "HARAM" | "MUSHBOOH",
      "reason": "Justification",
      "isAdditive": false,
      "source": "Plant / Animal / Insect / Alcohol / Chemical"
    }
  ]
}
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': promptText}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 1024,
        }
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String textResponse =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        return _parseGeminiJsonResponse(
          textResponse: textResponse,
          productName: productName,
          barcode: barcode,
          imageUrl: imageUrl,
        );
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('[GeminiHalalService] Text API exception: $e');
      return null;
    }
  }

  /// Parses JSON response returned by Gemini into a [ProductAnalysisResult].
  static ProductAnalysisResult? _parseGeminiJsonResponse({
    required String textResponse,
    required String productName,
    required String barcode,
    required String imageUrl,
  }) {
    try {
      String cleanedJson = textResponse.replaceAll(RegExp(r'^```json\s*'), '').replaceAll(RegExp(r'\s*```$'), '').trim();
      final Map<String, dynamic> parsed = jsonDecode(cleanedJson);

      String overallStatus = (parsed['overallStatus'] ?? 'HALAL').toString().toUpperCase();
      String riskLevel = parsed['riskLevel']?.toString() ?? 'AI Analysis Completed';

      List<IngredientAnalysisResult> results = [];
      List<String> haramIngredients = [];
      List<String> mushboohIngredients = [];
      List<String> halalIngredients = [];
      List<String> translatedIngredientsList = [];

      final ingredientsJson = parsed['ingredients'] as List<dynamic>? ?? [];
      for (var item in ingredientsJson) {
        String name = item['ingredient']?.toString() ?? '';
        if (name.isEmpty) continue;

        String status = (item['status']?.toString() ?? 'HALAL').toUpperCase();
        String reason = item['reason']?.toString() ?? 'Analyzed by AI';
        bool isAdditive = item['isAdditive'] == true;
        String source = item['source']?.toString() ?? 'AI Analysis';

        translatedIngredientsList.add(name);

        final ingResult = IngredientAnalysisResult(
          ingredient: name,
          status: status,
          reason: reason,
          isAdditive: isAdditive,
          source: 'AI ($source)',
        );

        results.add(ingResult);

        if (status == 'HARAM') {
          haramIngredients.add(name);
        } else if (status == 'MUSHBOOH') {
          mushboohIngredients.add(name);
        } else {
          halalIngredients.add(name);
        }
      }

      if (results.isEmpty) return null;

      return ProductAnalysisResult(
        overallStatus: overallStatus,
        riskLevel: riskLevel,
        results: results,
        haramIngredients: haramIngredients,
        mushboohIngredients: mushboohIngredients,
        halalIngredients: halalIngredients,
        apiResponse: 'Gemini AI Vision Analysis',
        productName: productName,
        barcode: barcode,
        imageUrl: imageUrl,
        ingredients: translatedIngredientsList,
        additives: const [],
      );
    } catch (e) {
      debugPrint('[GeminiHalalService] Failed to parse Gemini response: $e');
      return null;
    }
  }
}
