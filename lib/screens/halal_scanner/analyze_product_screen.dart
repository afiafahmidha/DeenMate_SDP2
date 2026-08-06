import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'halal_scanner_home.dart';
import '../../services/halal_analyzer_service.dart';
import '../../l10n/app_localizations.dart';

class AnalyzeProductScreen extends StatefulWidget {
  final String? prefillType;
  final bool isDarkMode;

  const AnalyzeProductScreen({super.key, this.prefillType, this.isDarkMode = false});

  @override
  State<AnalyzeProductScreen> createState() => _AnalyzeProductScreenState();
}

class _AnalyzeProductScreenState extends State<AnalyzeProductScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _explainController = TextEditingController();

  File? _selectedImage;
  String? _recognizedText;
  bool _isAnalyzing = false;
  ProductAnalysisResult? _analysisResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.prefillType != null) {
      _explainController.text = 'Attached photo via ${widget.prefillType}. Please analyze the ingredients.';
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _emailController.dispose();
    _explainController.dispose();
    super.dispose();
  }

  bool _isPicking = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      _isPicking = false;
      if (!mounted || image == null) return;

      String imagePath = image.path;

      if (source == ImageSource.camera) {
        final CroppedFile? cropped = await _cropImage(image.path);
        if (cropped == null) return;
        imagePath = cropped.path;
      }

      setState(() {
        _selectedImage = File(imagePath);
        _errorMessage = null;
        _analysisResult = null;
        _recognizedText = null;
      });

      await _recognizeText(imagePath);
    } catch (e) {
      _isPicking = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e')),
        );
      }
    }
  }

  Future<CroppedFile?> _cropImage(String sourcePath) async {
    return await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressQuality: 85,
      maxWidth: 1920,
      uiSettings: [
        AndroidUiSettings(
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: true,
        ),
      ],
    );
  }

  Future<void> _recognizeText(String imagePath) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String fullText = recognizedText.text;
      await textRecognizer.close();

      if (!mounted) return;

      setState(() {
        _recognizedText = fullText;
        _isAnalyzing = false;
      });

      if (fullText.trim().isEmpty) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.tr('no_text_found');
        });
        return;
      }

      await _analyzeRecognizedText(fullText);
    } catch (e) {
      print('OCR error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = AppLocalizations.of(context)!.tr('recognition_failed');
        });
      }
    }
  }

  Future<void> _analyzeRecognizedText(String text) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      List<String> ingredients = _parseIngredientsFromText(text);
      
      if (ingredients.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = AppLocalizations.of(context)!.tr('could_not_detect');
        });
        return;
      }

      ProductAnalysisResult result = HalalAnalyzerService.analyzeIngredients(
        ingredients: ingredients,
        additives: const [],
        productName: 'Scanned Ingredients',
        barcode: _barcodeController.text.trim().isEmpty ? 'N/A' : _barcodeController.text.trim(),
        imageUrl: _selectedImage != null ? _selectedImage!.path : '',
      );

      if (!mounted) return;

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      print('Analysis error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = AppLocalizations.of(context)!.tr('analysis_failed');
        });
      }
    }
  }

  List<String> _parseIngredientsFromText(String text) {
    List<String> ingredients = [];
    
    String cleaned = text.replaceAll(RegExp(r'\*+'), ' ').replaceAll(RegExp(r'\n+'), '\n');
    
    List<String> lines = cleaned.split('\n');
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      if (line.toLowerCase().contains('ingredient') && 
          (line.toLowerCase().contains(':') || line.toLowerCase().contains('list'))) {
        continue;
      }
      
      List<String> parts = line.split(RegExp(r'[,;•\-\*]'));
      for (String part in parts) {
        String ingredient = part.trim();
        if (ingredient.isNotEmpty && ingredient.length > 1) {
          ingredients.add(ingredient);
        }
      }
    }

    if (ingredients.isEmpty) {
      List<String> words = cleaned.split(RegExp(r'\s+'));
      for (String word in words) {
        word = word.trim();
        if (word.isNotEmpty && word.length > 2 && !_isCommonWord(word)) {
          ingredients.add(word);
        }
      }
    }

    return ingredients;
  }

  bool _isCommonWord(String word) {
    final commonWords = {
      'ingredients', 'contains', 'product', 'list', 'per', 'serving', 'size',
      'nutrition', 'facts', 'information', 'manufactured', 'distributed', 'by',
      'the', 'and', 'for', 'with', 'from', 'may', 'contain', 'allergen',
      'warning', 'caution', 'store', 'keep', 'refrigerated', 'after', 'opening',
    };
    return commonWords.contains(word.toLowerCase());
  }

  void _submitAnalysis() {
    if (_barcodeController.text.trim().isEmpty && _analysisResult == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.tr('scan_or_enter'))),
        );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.tr('valid_email_entry'))),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFF55A498)),
              const SizedBox(width: 20),
              Text(AppLocalizations.of(context)!.tr('submitting')),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.tr('request_submitted')),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)!.tr('thank_you'),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF55A498),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (_analysisResult != null) {
        HalalScannerState.addProduct(_analysisResult!.toScannedProduct());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.white;
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = widget.isDarkMode ? Colors.white54 : Colors.grey;
    final borderColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey[300]!;
    final textFieldBg = widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _analysisResult != null
              ? AppLocalizations.of(context)!.tr('analysis_results')
              : AppLocalizations.of(context)!.tr('scan_ingredients'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _submitAnalysis,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),

              if (_analysisResult != null) ...[
                _buildResultsCard(_analysisResult!, tealColor, primaryTextColor, cardColor),
                const SizedBox(height: 24),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tealColor.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.qr_code_2_rounded, color: tealColor),
                      hintText: AppLocalizations.of(context)!.tr('barcode_optional'),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: textFieldBg,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Icon(Icons.camera_alt_outlined, color: secondaryTextColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.tr('scan_ingredient_list'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                         label: Text(AppLocalizations.of(context)!.tr('take_photo')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: Icon(Icons.image_outlined, color: tealColor),
                        label: Text(AppLocalizations.of(context)!.tr('gallery'), style: TextStyle(color: primaryTextColor)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tealColor,
                          side: BorderSide(color: tealColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_selectedImage != null)
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                if (_selectedImage != null) const SizedBox(height: 12),

                if (_isAnalyzing)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tealColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        CircularProgressIndicator(color: tealColor, strokeWidth: 2),
                        SizedBox(width: 16),
                        Text('Analyzing ingredients...', style: TextStyle(color: tealColor)),
                      ],
                    ),
                  ),

                if (_recognizedText != null && _analysisResult == null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                           AppLocalizations.of(context)!.tr('recognized_text_label'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _recognizedText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: secondaryTextColor, size: 22),
                    const SizedBox(width: 8),
                     Text(
                       AppLocalizations.of(context)!.tr('tell_us'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                     hintText: AppLocalizations.of(context)!.tr('email'),
                    hintStyle: TextStyle(color: secondaryTextColor),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: textFieldBg,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: tealColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _explainController,
                  maxLines: 3,
                  decoration: InputDecoration(
                     hintText: AppLocalizations.of(context)!.tr('explain_here'),
                    hintStyle: TextStyle(color: secondaryTextColor),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: textFieldBg,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: tealColor),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsCard(ProductAnalysisResult analysis, Color tealColor, Color textColor, Color cardColor) {
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.overallStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      analysis.riskLevel,
                      style: TextStyle(
                        color: statusColor.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
             AppLocalizations.of(context)!.tr('ingredients_analyzed'),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (analysis.haramIngredients.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${analysis.haramIngredients.length} Haram',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          if (analysis.mushboohIngredients.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${analysis.mushboohIngredients.length} Mushbooh',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (analysis.halalIngredients.isNotEmpty && analysis.overallStatus == 'HALAL') ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All ${analysis.halalIngredients.length} Halal',
                      style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.tr('all_ingredients'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.results.map((result) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(result.statusIcon, color: result.statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.ingredient,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  result.status,
                  style: TextStyle(
                    color: result.statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
