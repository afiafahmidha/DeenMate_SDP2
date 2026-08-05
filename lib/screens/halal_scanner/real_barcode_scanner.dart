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
import 'product_detail_screen.dart';

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
  ProductAnalysisResult? _analysisResult;
  bool _showResults = false;

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
      _showResults = false;
      _analysisResult = null;
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
        
        setState(() {
          _analysisResult = analysisResult;
          _isLoading = false;
          _showResults = true;
        });
        
        final product = analysisResult.toScannedProduct();
        widget.onScanComplete(product);
        
      } else {
        _showError('Product not found in database. Try a different barcode.');
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
        apiResponse = 'AI analysis completed';
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

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isScanning = true;
      _isLoading = false;
      _showResults = false;
      _controller.start();
    });
  }

  void _scanAgain() {
    setState(() {
      _showResults = false;
      _analysisResult = null;
      _isScanning = true;
      _errorMessage = null;
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
          _showResults ? 'Results' : 'Scan Barcode',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_showResults)
            IconButton(
              icon: Icon(Icons.qr_code_scanner, color: Colors.white),
              onPressed: _scanAgain,
              tooltip: 'Scan Again',
            ),
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
      body: _errorMessage != null && !_isLoading && !_showResults
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
                        'Analyzing product...',
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Checking each ingredient individually',
                        style: TextStyle(color: secondaryTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : _showResults && _analysisResult != null
                  ? _buildResultsView()
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
                                'Align barcode within frame',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Keep the phone steady to auto-focus',
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

  Widget _buildResultsView() {
    final analysis = _analysisResult!;
    final isDarkMode = widget.isDarkMode;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    Color statusColor;
    IconData statusIcon;
    if (analysis.overallStatus == 'HALAL') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (analysis.overallStatus == 'MUSHBOOH') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(statusIcon, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  analysis.overallStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  analysis.riskLevel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${analysis.results.length} ingredients analyzed',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                if (analysis.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      analysis.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analysis.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Barcode: ${analysis.barcode}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (analysis.apiResponse != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    analysis.apiResponse!,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          Text(
            'All Ingredients',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),

          if (analysis.results.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'No ingredients found',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This product may not have ingredient data available',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...analysis.results.map((result) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: result.statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: result.statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.statusIcon,
                      color: result.statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              HalalAnalyzerService.extractCode(result.ingredient),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                result.ingredient,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: result.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: result.statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      result.status,
                      style: TextStyle(
                        color: result.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )),

          const SizedBox(height: 16),

          if (analysis.haramIngredients.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${analysis.haramIngredients.length} Haram ingredient(s) found',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),

          if (analysis.mushboohIngredients.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${analysis.mushboohIngredients.length} Mushbooh ingredient(s) found',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),

          if (analysis.halalIngredients.isNotEmpty && analysis.overallStatus == 'HALAL')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ All ${analysis.halalIngredients.length} ingredients are Halal',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scanAgain,
                  icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('Scan Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(
                          isDarkMode: isDarkMode,
                          product: analysis.toScannedProduct(),
                          analysisResults: analysis.results,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.info_outline, color: AppColors.midTeal),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.midTeal,
                    side: BorderSide(color: AppColors.midTeal),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
