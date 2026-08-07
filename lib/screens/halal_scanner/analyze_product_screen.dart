import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'halal_scanner_home.dart';
import '../../widgets/auth_header.dart';
import '../../services/halal_analyzer_service.dart';
import '../../services/ingredient_ocr_cleaner.dart';
import '../../services/gemini_halal_service.dart';
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
  List<String> _cleanIngredientsList = [];
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
        imageQuality: 90,
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
        _cleanIngredientsList = [];
      });

      await _processImageAndAnalyze(imagePath);
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
      compressQuality: 90,
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

  Future<void> _processImageAndAnalyze(String imagePath) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final imageFile = File(imagePath);
      final barcode = _barcodeController.text.trim().isEmpty ? 'N/A' : _barcodeController.text.trim();

      // 1. Try Gemini Vision AI analysis first (if key set)
      final aiResult = await GeminiHalalService.analyzeImageWithGemini(
        imageFile: imageFile,
        productName: 'Scanned Ingredients',
        barcode: barcode,
      );

      if (aiResult != null && mounted) {
        setState(() {
          _analysisResult = aiResult;
          _cleanIngredientsList = aiResult.ingredients;
          _isAnalyzing = false;
        });
        return;
      }

      // 2. Perform ML Kit Text Recognition
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String rawText = recognizedText.text;
      await textRecognizer.close();

      if (!mounted) return;

      setState(() {
        _recognizedText = rawText;
      });

      if (rawText.trim().isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = AppLocalizations.of(context)!.tr('no_text_found');
        });
        return;
      }

      // 3. Clean OCR text with IngredientOcrCleaner
      List<String> cleanedIngredients = IngredientOcrCleaner.cleanAndExtract(rawText);
      _cleanIngredientsList = cleanedIngredients;

      if (cleanedIngredients.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = AppLocalizations.of(context)!.tr('could_not_detect');
        });
        return;
      }

      // 4. Try Gemini Text AI analysis
      final textAiResult = await GeminiHalalService.analyzeTextWithGemini(
        rawText: cleanedIngredients.join(', '),
        productName: 'Scanned Ingredients',
        barcode: barcode,
        imageUrl: imagePath,
      );

      if (textAiResult != null && mounted) {
        setState(() {
          _analysisResult = textAiResult;
          _isAnalyzing = false;
        });
        return;
      }

      // 5. Fallback to Enhanced Rule-Based HalalAnalyzerService
      ProductAnalysisResult result = HalalAnalyzerService.analyzeIngredients(
        ingredients: cleanedIngredients,
        additives: const [],
        productName: 'Scanned Ingredients',
        barcode: barcode,
        imageUrl: imagePath,
      );

      if (!mounted) return;

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      print('OCR Analysis error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = AppLocalizations.of(context)!.tr('analysis_failed');
        });
      }
    }
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
              const CircularProgressIndicator(color: AppColors.midTeal),
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
              const Icon(Icons.check_circle_rounded, color: Colors.green),
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
                backgroundColor: AppColors.navyBlue,
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
    final bgColor = widget.isDarkMode ? const Color(0xFF101923) : const Color(0xFFF8FAF9);
    final cardColor = widget.isDarkMode ? const Color(0xFF1A2633) : Colors.white;
    final primaryTextColor = widget.isDarkMode ? Colors.white : AppColors.navyBlue;
    final borderColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
    final textFieldBg = widget.isDarkMode ? const Color(0xFF243447) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _analysisResult != null
              ? AppLocalizations.of(context)!.tr('analysis_results')
              : AppLocalizations.of(context)!.tr('scan_ingredients'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            onPressed: _submitAnalysis,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),

              if (_analysisResult != null) ...[
                _buildResultsCard(_analysisResult!, primaryTextColor, cardColor),
                const SizedBox(height: 24),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: primaryTextColor),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.qr_code_2_rounded, color: AppColors.midTeal),
                      hintText: AppLocalizations.of(context)!.tr('barcode_optional'),
                      hintStyle: GoogleFonts.poppins(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: textFieldBg,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: AppColors.midTeal, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.tr('scan_ingredient_list'),
                      style: GoogleFonts.poppins(
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
                        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                        label: Text(AppLocalizations.of(context)!.tr('take_photo'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, color: AppColors.midTeal, size: 20),
                        label: Text(AppLocalizations.of(context)!.tr('gallery'), style: GoogleFonts.poppins(color: primaryTextColor, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.midTeal,
                          side: const BorderSide(color: AppColors.midTeal),
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
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
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
                      color: AppColors.midTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppColors.midTeal, strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Analyzing & translating ingredients...',
                          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),

                if (_cleanIngredientsList.isNotEmpty && _analysisResult == null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.dustyBlueTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clean Extracted Ingredients (${_cleanIngredientsList.length}):',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _cleanIngredientsList
                              .map((ing) => Chip(
                                    label: Text(ing, style: GoogleFonts.poppins(fontSize: 11.5)),
                                    backgroundColor: cardColor,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, color: AppColors.midTeal, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.tr('tell_us'),
                      style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.tr('email'),
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: textFieldBg,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.midTeal),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _explainController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.tr('explain_here'),
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: textFieldBg,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.midTeal),
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

  Widget _buildResultsCard(ProductAnalysisResult analysis, Color textColor, Color cardColor) {
    Color statusColor;
    IconData statusIcon;
    if (analysis.overallStatus == 'HALAL') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else if (analysis.overallStatus == 'MUSHBOOH') {
      statusColor = AppColors.coralOrange;
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.overallStatus,
                      style: GoogleFonts.poppins(
                        color: statusColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      analysis.riskLevel,
                      style: GoogleFonts.poppins(
                        color: statusColor.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Translated Ingredients Analysis (in English):',
            style: GoogleFonts.poppins(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 10),
          if (analysis.haramIngredients.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${analysis.haramIngredients.length} Haram Ingredient(s) Detected',
                      style: GoogleFonts.poppins(color: Colors.red.shade800, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          if (analysis.mushboohIngredients.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${analysis.mushboohIngredients.length} Mushbooh (Doubtful) Ingredient(s)',
                      style: GoogleFonts.poppins(color: Colors.orange.shade900, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          if (analysis.halalIngredients.isNotEmpty && analysis.overallStatus == 'HALAL')
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All ${analysis.halalIngredients.length} Ingredient(s) Verified Halal',
                      style: GoogleFonts.poppins(color: Colors.green.shade800, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context)!.tr('all_ingredients'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          ...analysis.results.map((result) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: result.statusColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(result.statusIcon, color: result.statusColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result.ingredient,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: result.statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        result.status,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (result.reason != null && result.reason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '• ${result.reason}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          )),
        ],
      ),
    );
  }
}
