import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0';

  Future<ProductData?> fetchProduct(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/product/$barcode.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1 && data['product'] != null) {
          return ProductData.fromJson(data['product'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class ProductData {
  final String name;
  final String brand;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> additives;
  final String? allergens;
  final String? packaging;
  final String? countries;
  final String? traces;

  ProductData({
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.ingredients,
    required this.additives,
    this.allergens,
    this.packaging,
    this.countries,
    this.traces,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    final productName = json['product_name'] as String? ?? 'Unknown Product';
    final brands = json['brands'] as String? ?? '';
    final imageUrl = json['image_url'] as String? ?? '';

    final ingredientsText = json['ingredients_text'] as String? ?? '';
    final ingredients = ingredientsText.isNotEmpty
        ? ingredientsText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final additivesTags = json['additives_tags'] as List<dynamic>? ?? [];
    final additives = additivesTags
        .map((e) {
          final tag = e.toString();
          return tag.replaceAll('en:', '').replaceAll('-', ' ').toUpperCase();
        })
        .toList();

    final allergens = json['allergens'] as String?;
    final packaging = json['packaging'] as String?;
    final countries = json['countries'] as String?;
    final traces = json['traces'] as String?;

    return ProductData(
      name: productName,
      brand: brands,
      imageUrl: imageUrl,
      ingredients: ingredients,
      additives: additives,
      allergens: allergens,
      packaging: packaging,
      countries: countries,
      traces: traces,
    );
  }
}
