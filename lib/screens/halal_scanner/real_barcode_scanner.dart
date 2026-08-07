import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'halal_scanner_home.dart';
import '../../widgets/auth_header.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/halal_analyzer_service.dart';
import '../../l10n/app_localizations.dart';
import 'product_detail_screen.dart';
import 'analyze_product_screen.dart';

// ============================================================
// Configuration
// ============================================================

class ApiConfig {
  static const String apifyApiToken = 'YOUR_APIFY_API_TOKEN_HERE';
  static const String actorId = '42far~halal-ingredient-checker';
  static const bool useApifyApi = true;
}

// ============================================================
// Halal API Service
// ============================================================

class HalalApiService {
  final String apiToken;
  final String actorId;

  HalalApiService(this.apiToken, this.actorId);

  Future<Map<String, String>> checkIngredientsWithApi(List<String> ingredients) async {
    if (apiToken.isEmpty || apiToken == 'YOUR_APIFY_API_TOKEN_HERE') {
      throw Exception('Please set your Apify API token in ApiConfig');
    }

    try {
      final runUrl = 'https://api.apify.com/v2/actors/$actorId/runs?token=$apiToken';
      final input = {'ingredients': ingredients, 'includeECodes': true};

      final response = await http.post(
        Uri.parse(runUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(input),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final runId = data['data']['id'] as String?;
        
        if (runId != null) {
          return await _pollForResults(runId);
        } else {
          return _parseDirectResponse(data);
        }
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API request failed: $e');
    }
  }

  Future<Map<String, String>> _pollForResults(String runId) async {
    int attempts = 0;
    const maxAttempts = 20;
    
    while (attempts < maxAttempts) {
      attempts++;
      await Future.delayed(const Duration(seconds: 2));
      
      final statusUrl = 'https://api.apify.com/v2/actor-runs/$runId?token=$apiToken';
      final response = await http.get(Uri.parse(statusUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']['status'] as String?;
        
        if (status == 'SUCCEEDED') {
          return await _getRunResults(runId);
        } else if (status == 'FAILED' || status == 'ABORTED' || status == 'TIMED_OUT') {
          throw Exception('Actor run failed with status: $status');
        }
      }
    }
    throw Exception('Run timed out');
  }

  Future<Map<String, String>> _getRunResults(String runId) async {
    final datasetUrl = 'https://api.apify.com/v2/actor-runs/$runId/dataset/items?token=$apiToken';
    final response = await http.get(Uri.parse(datasetUrl)).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _parseDatasetResponse(data);
    } else {
      throw Exception('Failed to get dataset items');
    }
  }

  Map<String, String> _parseDatasetResponse(dynamic data) {
    final Map<String, String> results = {};
    try {
      if (data is List) {
        for (var item in data) {
          final ingredient = item['ingredient']?.toString() ?? item['name']?.toString() ?? '';
          final status = item['status']?.toString().toUpperCase() ?? 
                        item['halalStatus']?.toString().toUpperCase() ?? '';
          if (ingredient.isNotEmpty && status.isNotEmpty) {
            results[ingredient] = _mapStatus(status);
          }
        }
      }
    } catch (e) {
      print('Error parsing dataset: $e');
    }
    return results;
  }

  Map<String, String> _parseDirectResponse(dynamic data) {
    final Map<String, String> results = {};
    try {
      if (data['results'] is List) {
        for (var item in data['results']) {
          final ingredient = item['ingredient']?.toString() ?? '';
          final status = item['status']?.toString().toUpperCase() ?? '';
          if (ingredient.isNotEmpty && status.isNotEmpty) {
            results[ingredient] = _mapStatus(status);
          }
        }
      }
    } catch (e) {
      print('Error parsing direct response: $e');
    }
    return results;
  }

  String _mapStatus(String status) {
    final upper = status.toUpperCase();
    if (upper.contains('HARAM') || upper.contains('HARAAM')) return 'HARAM';
    if (upper.contains('MUSHBOOH') || upper.contains('DOUBTFUL')) return 'MUSHBOOH';
    if (upper.contains('HALAL')) return 'HALAL';
    return 'UNKNOWN';
  }
}

// ============================================================
// Main Scanner Screen
// ============================================================

class RealBarcodeScannerScreen extends StatefulWidget {
  final Function(ScannedProduct) onScanComplete;
  final bool isDarkMode;

  const RealBarcodeScannerScreen({
    super.key,
    required this.onScanComplete,
    required this.isDarkMode,
  });

  @override
  State<RealBarcodeScannerScreen> createState() => _RealBarcodeScannerScreenState();
}

class _RealBarcodeScannerScreenState extends State<RealBarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  late final HalalApiService _apiService;
  
  bool _isScanning = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _productNotFound = false;

  @override
  void initState() {
    super.initState();
    _apiService = HalalApiService(ApiConfig.apifyApiToken, ApiConfig.actorId);
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = 'Camera permission is required to scan barcodes.';
        _isScanning = false;
      });
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (!_isScanning || _isLoading) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final code = barcode.rawValue ?? '';
    if (code.isEmpty) return;

    setState(() {
      _isScanning = false;
      _isLoading = true;
      _errorMessage = null;
    });

    _controller.stop();

    try {
      final service = OpenFoodFactsService();
      final productData = await service.fetchProduct(code).timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) return;

      if (productData != null) {
        final analysisResult = await _analyzeProduct(productData, code);
        final product = analysisResult.toScannedProduct();
        widget.onScanComplete(product);

        if (!mounted) return;
        // Navigate directly to ProductDetailScreen — skip the intermediate results page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              isDarkMode: widget.isDarkMode,
              product: product,
              analysisResults: analysisResult.results,
            ),
          ),
        ).then((_) {
          // Resume scanner when user comes back
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isScanning = true;
            });
            _controller.start();
          }
        });

      } else {
        if (mounted) {
          setState(() {
            _productNotFound = true;
            _isLoading = false;
            _isScanning = false;
          });
        }
      }
    } on TimeoutException {
      if (mounted) _showError('Lookup timed out. Check your connection and try again.');
    } catch (e) {
      print('Error: $e');
      if (mounted) _showError('Failed to fetch product data. Please try again.');
    }
  }

  Future<ProductAnalysisResult> _analyzeProduct(ProductData productData, String barcode) async {
    Map<String, String>? apiResults;
    bool apiUsed = false;
    String? apiResponse;

    if (ApiConfig.useApifyApi && ApiConfig.apifyApiToken.isNotEmpty && 
        ApiConfig.apifyApiToken != 'YOUR_APIFY_API_TOKEN_HERE') {
      try {
        final allItems = [...productData.ingredients, ...productData.additives];
        apiResults = await _apiService.checkIngredientsWithApi(allItems);
        apiUsed = true;
        apiResponse = 'AI analysis completed'; // keep internal, not shown directly
      } catch (e) {
        print('API failed: $e');
        apiUsed = false;
        apiResponse = 'Using local detection';
      }
    }

    ProductAnalysisResult result = HalalAnalyzerService.analyzeIngredients(
      ingredients: productData.ingredients,
      additives: productData.additives,
      productName: productData.name,
      barcode: barcode,
      imageUrl: productData.imageUrl,
    );

    if (apiUsed && apiResults != null && apiResults.isNotEmpty) {
      List<IngredientAnalysisResult> updatedResults = [];
      for (var r in result.results) {
        String lower = r.ingredient.toLowerCase().trim();
        String? matchedStatus;
        for (var entry in apiResults.entries) {
          String lowerKey = entry.key.toLowerCase().trim();
          if (lower == lowerKey || 
              lower.contains(lowerKey) || 
              lowerKey.contains(lower) ||
              lower.contains(lowerKey.replaceAll(' ', '')) ||
              lowerKey.replaceAll(' ', '').contains(lower)) {
            matchedStatus = entry.value;
            break;
          }
        }
        if (matchedStatus != null) {
          updatedResults.add(IngredientAnalysisResult(
            ingredient: r.ingredient,
            status: matchedStatus,
            reason: 'AI: $matchedStatus',
            isAdditive: r.isAdditive,
            source: 'api',
          ));
        } else {
          updatedResults.add(r);
        }
      }
      
      List<String> haramIngredients = [];
      List<String> mushboohIngredients = [];
      List<String> halalIngredients = [];
      
      for (var r in updatedResults) {
        if (r.status == 'HARAM') {
          haramIngredients.add(r.ingredient);
        } else if (r.status == 'MUSHBOOH') {
          mushboohIngredients.add(r.ingredient);
        } else {
          halalIngredients.add(r.ingredient);
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
        riskLevel = productData.additives.length > 5 ? 'Safe - Few additives' : 'Safe - No concerns';
      }
      
      return ProductAnalysisResult(
        overallStatus: overallStatus,
        riskLevel: riskLevel,
        results: updatedResults,
        haramIngredients: haramIngredients,
        mushboohIngredients: mushboohIngredients,
        halalIngredients: halalIngredients,
        apiResponse: apiResponse,
        productName: productData.name,
        barcode: barcode,
        imageUrl: productData.imageUrl,
        ingredients: result.ingredients,
        additives: result.additives,
      );
    }

    return result;
  }

  Widget _buildProductNotFoundUI(Color textColor, Color? secondaryTextColor) {
    final isDark = widget.isDarkMode;
    final cardColor = isDark ? const Color(0xFF1A2633) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.15);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 52,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Product Not Found',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              'We couldn\'t find this barcode in our database.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryTextColor, fontSize: 14),
            ),
            const SizedBox(height: 28),

            // Suggestion card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.midTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.document_scanner_rounded,
                          color: AppColors.midTeal,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Try Ingredient Scan',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You can scan the ingredient list on the packaging to analyze the food.',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Scan Ingredients button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalyzeProductScreen(
                              isDarkMode: widget.isDarkMode,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Scan Ingredients',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midTeal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Try again button
            TextButton.icon(
              onPressed: _scanAgain,
              icon: Icon(Icons.qr_code_scanner_rounded, color: secondaryTextColor, size: 18),
              label: Text(
                'Try Another Barcode',
                style: TextStyle(color: secondaryTextColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isScanning = true;
      _isLoading = false;
      _controller.start();
    });
  }

  void _scanAgain() {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _productNotFound = false;
    });
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = widget.isDarkMode ? Colors.white70 : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1A2E40) : AppColors.navyBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
         title: Text(
          AppLocalizations.of(context)!.tr('scan_code'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (ApiConfig.useApifyApi && ApiConfig.apifyApiToken.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  const Text('AI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: _productNotFound
          ? _buildProductNotFoundUI(textColor, secondaryTextColor)
          : _errorMessage != null && !_isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 64, color: secondaryTextColor),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final status = await Permission.camera.request();
                        if (status.isGranted && mounted) {
                          setState(() {
                            _errorMessage = null;
                            _isScanning = true;
                          });
                          _controller.start();
                        }
                      },
                      icon: Icon(Icons.camera, color: Colors.white),
                      label: Text('Grant Permission', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.midTeal),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.tr('analyzing_product'),
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.tr('checking_each_ingredient'),
                        style: TextStyle(color: secondaryTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : Stack(
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _handleBarcode,
                        ),
                        Center(
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withValues(alpha: 0.5),
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.5),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const [0.0, 0.2, 1.0],
                                      ),
                                    ),
                                  ),
                                  _buildCornerIndicators(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 120,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                               Text(
                                AppLocalizations.of(context)!.tr('align_barcode_frame'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(height: 8),
                               Text(
                                AppLocalizations.of(context)!.tr('keep_steady'),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4)],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: IconButton(
                            icon: Icon(
                              _controller.torchEnabled ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                            ),
                            onPressed: () => _controller.toggleTorch(),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildCornerIndicators() {
    return Stack(
      children: [
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white, width: 3),
                left: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white, width: 3),
                right: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 3),
                left: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 3),
                right: BorderSide(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
