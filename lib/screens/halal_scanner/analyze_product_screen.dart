import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'halal_scanner_home.dart';
import '../../services/halal_analyzer_service.dart';

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

  Future<void> _pickImage(ImageSource source) async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = 'Camera permission is required to scan ingredients.';
      });
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );

    if (!mounted || image == null) return;

    setState(() {
      _selectedImage = File(image.path);
      _errorMessage = null;
      _analysisResult = null;
      _recognizedText = null;
    });

    await _recognizeText(image.path);
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
          _errorMessage = 'No text found in image. Please try again with a clearer photo.';
        });
        return;
      }

      await _analyzeRecognizedText(fullText);
    } catch (e) {
      print('OCR error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Failed to recognize text. Please try again.';
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
          _errorMessage = 'Could not detect ingredients from text. Please enter them manually.';
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
          _errorMessage = 'Failed to analyze ingredients. Please try again.';
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
        const SnackBar(content: Text('Please scan ingredients or enter a barcode.')),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF55A498)),
              SizedBox(width: 20),
              Text('Submitting analysis...'),
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
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Request Submitted'),
            ],
          ),
          content: const Text(
            'Thank you! Our expert food scientists will analyze your product and notify you once it\'s added to our database.',
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
          _analysisResult != null ? 'Analysis Results' : 'Scan Ingredients',
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
                      hintText: 'Barcode number (optional)',
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
                      'Scan ingredient list',
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
                        label: const Text('Take Photo'),
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
                        label: Text('Gallery', style: TextStyle(color: primaryTextColor)),
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
                          'Recognized Text:',
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
                      'Anything you would like to tell us?',
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
                    hintText: 'Email',
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
                    hintText: 'Explain us here...',
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
            '${analysis.results.length} ingredients analyzed',
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
        ],
      ),
    );
  }
}
