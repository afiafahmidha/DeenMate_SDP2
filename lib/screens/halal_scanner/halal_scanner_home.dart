// Halal Scanner — merged screen file.
// Consolidates: Home, Scanned History, Additives List + Detail, Guide/Walkthrough,
// Health Tips + Detail, Analyze/Report Product, Product Detail, Barcode Scanner, Drawer.
// Theming unified with AppColors (navyBlue / midTeal / coralOrange) to match
// the Zakat Manager and Qurbani & Aqiqah Planner screens.
//
// NOTE: AdditivesPreferencesScreen was intentionally dropped from this merge —
// it was not reachable from the drawer or any other screen (dead/unused code).
// Backend services (OpenFoodFactsService, HalalAnalyzerService, GeminiHalalService,
// IngredientOcrCleaner) are kept as separate files per your request.



import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;   // <-- add this line
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../services/gemini_halal_service.dart';
import '../../services/halal_analyzer_service.dart';
import '../../services/halal_scanner_service.dart';
import '../../services/ingredient_ocr_cleaner.dart';
import '../../services/open_food_facts_service.dart';
import '../../widgets/auth_header.dart';

// ============================================================
// From: home
// ============================================================
class ScannedProduct {
  final String name;
  final String barcode;
  final DateTime scanDate;
  final String status; // 'HALAL', 'HARAM', 'MUSHBOOH'
  final String origin; // 'Plant', 'Animal', 'Chemical', etc.
  final String risk;   // 'Safe', 'Toxic', 'Do not abuse'
  final List<String> ingredients;
  final List<String> additives;
  final String imageUrl;
  final List<IngredientAnalysisResult>? analysisResults;

  ScannedProduct({
    required this.name,
    required this.barcode,
    required this.scanDate,
    required this.status,
    required this.origin,
    required this.risk,
    this.ingredients = const [],
    this.additives = const [],
    this.imageUrl = '',
    this.analysisResults,
  });
}

class HalalScannerState {
  static int halalCount = 0;
  static int haramCount = 0;
  static int mushboohCount = 0;
  static int remainingScans = 7;
  static List<ScannedProduct> history = [];
  static bool isLoaded = false;

  static Future<void> addProduct(ScannedProduct product) async {
    // Remove existing duplicate if present
    final existingIndex = history.indexWhere((h) {
      if (product.barcode.isNotEmpty && h.barcode.isNotEmpty) {
        return h.barcode == product.barcode;
      }
      return h.name.trim().toLowerCase() == product.name.trim().toLowerCase();
    });

    if (existingIndex != -1) {
      final oldProduct = history.removeAt(existingIndex);
      _decrementCount(oldProduct.status);
    }

    history.insert(0, product);
    _incrementCount(product.status);

    if (remainingScans > 0) remainingScans--;

    // Save to Firestore
    await HalalScannerService.instance.saveScan(product);
  }

  static void _incrementCount(String status) {
    if (status == 'HALAL') {
      halalCount++;
    } else if (status == 'HARAM') {
      haramCount++;
    } else {
      mushboohCount++;
    }
  }

  static void _decrementCount(String status) {
    if (status == 'HALAL' && halalCount > 0) {
      halalCount--;
    } else if (status == 'HARAM' && haramCount > 0) {
      haramCount--;
    } else if (mushboohCount > 0) {
      mushboohCount--;
    }
  }

  static Future<void> loadHistory() async {
    final remoteHistory = await HalalScannerService.instance.getScanHistory();
    history = remoteHistory;

    halalCount = 0;
    haramCount = 0;
    mushboohCount = 0;

    for (var product in history) {
      _incrementCount(product.status);
    }

    isLoaded = true;
  }

  static Future<void> clearHistory() async {
    history.clear();
    halalCount = 0;
    haramCount = 0;
    mushboohCount = 0;
    remainingScans = 7;
    await HalalScannerService.instance.clearHistory();
  }

  static void reset() {
    history = [];
    halalCount = 0;
    haramCount = 0;
    mushboohCount = 0;
    remainingScans = 7;
    isLoaded = false;
  }
}

class HalalScannerHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  const HalalScannerHomeScreen({super.key, required this.isDarkMode});

  @override
  State<HalalScannerHomeScreen> createState() => _HalalScannerHomeScreenState();
}

class _HalalScannerHomeScreenState extends State<HalalScannerHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (HalalScannerState.isLoaded) return;
    setState(() => _isLoadingHistory = true);
    await HalalScannerState.loadHistory();
    await HalalScannerService.instance.getAdditiveOverrides();
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  void _showScanIngredientsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: widget.isDarkMode ? BorderSide(color: Colors.white.withValues(alpha: 0.12)) : BorderSide.none,
      ),
      builder: (context) {
        final primaryTextColor = widget.isDarkMode ? Colors.white : Colors.black87;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                 Text(
                AppLocalizations.of(context)!.tr('scan_ingredients_instead'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: AppColors.midTeal, size: 28),
                                 title: Text(AppLocalizations.of(context)!.tr('take_photo'), style: TextStyle(fontSize: 16, color: primaryTextColor)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                       builder: (context) => AnalyzeProductScreen(
                        isDarkMode: widget.isDarkMode,
                        prefillType: AppLocalizations.of(context)!.tr('ingredient_camera'),
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
              Divider(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.2)),
              ListTile(
                leading: Icon(Icons.image_outlined, color: AppColors.midTeal, size: 28),
                                 title: Text(AppLocalizations.of(context)!.tr('choose_from_gallery'), style: TextStyle(fontSize: 16, color: primaryTextColor)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                       builder: (context) => AnalyzeProductScreen(
                        isDarkMode: widget.isDarkMode,
                        prefillType: AppLocalizations.of(context)!.tr('ingredient_gallery'),
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _simulateBarcodeScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RealBarcodeScannerScreen(
          onScanComplete: (product) async {
            await HalalScannerState.addProduct(product);
            if (mounted) setState(() {});
          },
          isDarkMode: widget.isDarkMode,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _openProductDetail(ScannedProduct product) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProductDetailScreen(
        isDarkMode: widget.isDarkMode,
        product: product,
        analysisResults: product.analysisResults, // Pass analysis results
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    const tealColor = AppColors.midTeal;
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F7F5);

    return Container(
      color: bgColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: bgColor,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildQuickAccessSection(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            icon: Icons.check_circle_rounded,
                            iconColor: Colors.green[400]!,
                            count: HalalScannerState.halalCount,
                             label: AppLocalizations.of(context)!.tr('halal_products'),
                            subtitle: AppLocalizations.of(context)!.tr('safe'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusCard(
                            icon: Icons.cancel_rounded,
                            iconColor: Colors.red[400]!,
                            count: HalalScannerState.haramCount,
                             label: AppLocalizations.of(context)!.tr('haram_avoided'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusCard(
                            icon: Icons.warning_rounded,
                            iconColor: Colors.orange[400]!,
                            count: HalalScannerState.mushboohCount,
                             label: AppLocalizations.of(context)!.tr('mushbooh_avoided'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _simulateBarcodeScan,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.navyBlue,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navyBlue.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                  AppLocalizations.of(context)!.tr('scan_code'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    AppLocalizations.of(context)!.tr('by_barcode'),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showScanIngredientsSheet,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          border: Border.all(
                            color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.15) : AppColors.navyBlue.withValues(alpha: 0.2),
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: widget.isDarkMode ? Colors.black.withValues(alpha: 0.3) : AppColors.navyBlue.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.navyBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.document_scanner_outlined,
                                color: widget.isDarkMode ? Colors.white : AppColors.navyBlue,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text(
                                  AppLocalizations.of(context)!.tr('scan_ingredients'),
                                    style: TextStyle(
                                      color: widget.isDarkMode ? Colors.white : AppColors.navyBlue,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppLocalizations.of(context)!.tr('ingredient_list'),
                                    style: TextStyle(
                                      color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: widget.isDarkMode ? Colors.white : AppColors.navyBlue,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.tr('last_scanned'),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode ? Colors.white : AppColors.navyBlue,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScannedHistoryScreen(isDarkMode: widget.isDarkMode),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          child: Text(
                             AppLocalizations.of(context)!.tr('see_more'),
                            style: GoogleFonts.poppins(
                              color: tealColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingHistory)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: AppColors.midTeal),
                              const SizedBox(height: 12),
                              Text(
                                'Loading history...',
                                style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (HalalScannerState.history.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: HalalScannerState.history.length > 5
                            ? 5
                            : HalalScannerState.history.length,
                        itemBuilder: (context, index) {
                          final product = HalalScannerState.history[index];
                          return _buildProductListItem(product);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withValues(alpha: 0.3) : AppColors.navyBlue.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: widget.isDarkMode ? Colors.white : AppColors.navyBlue, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : AppColors.navyBlue.withValues(alpha: 0.08),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.tr('halal_scanner'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.tr('scan_and_learn'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.7) : AppColors.navyBlue.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    final items = [
      _QuickAccessItem(
        title: AppLocalizations.of(context)!.tr('additives_list'),
        icon: Icons.list_alt_rounded,
        color: AppColors.midTeal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdditivesListScreen(isDarkMode: widget.isDarkMode)),
        ),
      ),
      _QuickAccessItem(
        title: AppLocalizations.of(context)!.tr('scanned_history'),
        icon: Icons.history_rounded,
        color: AppColors.coralOrange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ScannedHistoryScreen(isDarkMode: widget.isDarkMode)),
        ),
      ),
      _QuickAccessItem(
        title: AppLocalizations.of(context)!.tr('guide'),
        icon: Icons.menu_book_rounded,
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GuidesAndWalkthroughScreen()),
        ),
      ),
      _QuickAccessItem(
        title: AppLocalizations.of(context)!.tr('health_tips'),
        icon: Icons.health_and_safety_rounded,
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HealthTipsScreen(isDarkMode: widget.isDarkMode)),
        ),
      ),
    ];

    final primaryTextColor = widget.isDarkMode ? Colors.white : AppColors.navyBlue;
    final cardBg = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
           AppLocalizations.of(context)!.tr('quick_access'),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: items.map((item) => Expanded(child: _buildQuickAccessTab(item))).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessTab(_QuickAccessItem item) {
    final iconColor = widget.isDarkMode ? Colors.white70 : AppColors.navyBlue;
    final inactiveColor = widget.isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(item.icon, size: 16, color: iconColor),
              const SizedBox(height: 2),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
    String? subtitle,
  }) {
    final surfaceColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.grey[600];
    final borderColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1);
    final shadowColor = widget.isDarkMode ? Colors.black.withValues(alpha: 0.3) : AppColors.navyBlue.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: secondaryTextColor,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[  
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: secondaryTextColor,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 64,
              color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
                AppLocalizations.of(context)!.tr('no_scanned_products'),
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
                AppLocalizations.of(context)!.tr('scan_first_product'),
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(ScannedProduct product) {
    Color badgeColor;
    if (product.status == 'HALAL') {
      badgeColor = Colors.green;
    } else if (product.status == 'HARAM') {
      badgeColor = Colors.red;
    } else {
      badgeColor = Colors.orange;
    }

    final surfaceColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final borderColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1);
    final secondaryTextColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.grey[500];
    final chevronColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.3) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        title: Text(
          product.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor),
        ),
         subtitle: Text(
          '${AppLocalizations.of(context)!.tr("barcode")}: ${product.barcode}',
          style: TextStyle(color: secondaryTextColor, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                product.status,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: chevronColor),
          ],
        ),
        onTap: () => _openProductDetail(product),
      ),
    );
  }
}

class _QuickAccessItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// ============================================================
// From: history
// ============================================================
class ScannedHistoryScreen extends StatefulWidget {
  final bool isDarkMode;
  const ScannedHistoryScreen({super.key, this.isDarkMode = false});

  @override
  State<ScannedHistoryScreen> createState() => _ScannedHistoryScreenState();
}

class _ScannedHistoryScreenState extends State<ScannedHistoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkHistory();
  }

  Future<void> _checkHistory() async {
    if (HalalScannerState.isLoaded) return;
    setState(() => _isLoading = true);
    await HalalScannerState.loadHistory();
    if (mounted) setState(() => _isLoading = false);
  }

  List<ScannedProduct> get _filteredHistory {
    return HalalScannerState.history.where((product) {
      final query = _searchQuery.toLowerCase().trim();

      bool matchesFilter = true;
      if (_selectedFilter != 'ALL') {
        matchesFilter = product.status.toUpperCase() == _selectedFilter;
      }

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return product.name.toLowerCase().contains(query) ||
          product.barcode.contains(query) ||
          product.status.toLowerCase().contains(query);
    }).toList();
  }

  void _clearAllHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Scan History?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('This will delete all scanned products from your local storage. This action cannot be undone.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await HalalScannerState.clearHistory();
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History successfully cleared!')),
                );
              }
            },
            child: Text('Clear All', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF101923) : const Color(0xFFF8FAF9);
    final cardColor = widget.isDarkMode ? const Color(0xFF1A2633) : Colors.white;
    final primaryTextColor = widget.isDarkMode ? Colors.white : AppColors.navyBlue;
    final historyList = _filteredHistory;

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
          'Scanned History',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        actions: [
          if (HalalScannerState.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          if (HalalScannerState.history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: GoogleFonts.poppins(color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: 'Search scanned products...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.midTeal),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All (${HalalScannerState.history.length})', cardColor, primaryTextColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('HALAL', 'Halal (${HalalScannerState.halalCount})', cardColor, primaryTextColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('MUSHBOOH', 'Mushbooh (${HalalScannerState.mushboohCount})', cardColor, primaryTextColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('HARAM', 'Haram (${HalalScannerState.haramCount})', cardColor, primaryTextColor),
                ],
              ),
            ),
          ],

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.midTeal))
                : historyList.isEmpty
                    ? _buildEmptyState(cardColor, primaryTextColor)
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                        itemCount: historyList.length,
                        itemBuilder: (context, index) {
                          final product = historyList[index];
                          return _buildProductCard(product, cardColor, primaryTextColor);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Color cardColor, Color textColor) {
    bool isSelected = _selectedFilter == filterKey;
    Color activeColor = AppColors.navyBlue;
    if (filterKey == 'HALAL') activeColor = Colors.green;
    if (filterKey == 'MUSHBOOH') activeColor = AppColors.coralOrange;
    if (filterKey == 'HARAM') activeColor = Colors.redAccent;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : textColor,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filterKey;
          });
        }
      },
      selectedColor: activeColor,
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState(Color cardColor, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.midTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.manage_history_rounded, size: 54, color: AppColors.midTeal),
            ),
            const SizedBox(height: 16),
            Text(
              'No scan history found',
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? 'Products scanned by you will automatically appear here.'
                  : 'No products match your search query or filter.',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ScannedProduct product, Color cardColor, Color textColor) {
    Color badgeColor;
    IconData statusIcon;
    if (product.status == 'HALAL') {
      badgeColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else if (product.status == 'HARAM') {
      badgeColor = Colors.redAccent;
      statusIcon = Icons.cancel_rounded;
    } else {
      badgeColor = AppColors.coralOrange;
      statusIcon = Icons.warning_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: badgeColor, size: 24),
        ),
        title: Text(
          product.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Barcode: ${product.barcode}',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
            ),
            Text(
              'Scanned: ${_formatDate(product.scanDate)}',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            product.status,
            style: GoogleFonts.poppins(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product, isDarkMode: widget.isDarkMode),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// From: additives
// ============================================================
// ---------------------------------------------------------------------------
// Shared colors (matches the app's teal / green / red / orange palette)
// ---------------------------------------------------------------------------

const Color kTeal = AppColors.midTeal;
const Color kHalalGreen = Color(0xFF2E7D32);     // strong, readable dark green
const Color kHaramRed = Color(0xFFD32F2F);       // true red
const Color kMushboohOrange = Color(0xFFF57C00); // true orange
const Color kBg = Color(0xFFF6F7F8);
Color statusColorOf(String status) {
  switch (status) {
    case 'HALAL':
      return kHalalGreen;
    case 'HARAM':
      return kHaramRed;
    default:
      return kMushboohOrange;
  }
}

Color riskColorOf(String riskText) {
  switch (riskText) {
    case 'Very toxic':
      return const Color(0xFFE6483A);
    case 'Toxic':
      return const Color(0xFFF08A24);
    case 'Do not abuse':
      return const Color(0xFFB5B335);
    case 'Safe':
      return kHalalGreen;
    default:
      return Colors.grey;
  }
}

// ---------------------------------------------------------------------------
// Wraps a screen so it only ever looks like a real phone.
// - On an actual Android/iOS device (or any narrow window) the screen
//   width is already <= 480, so this widget does nothing and the screen
//   fills the device exactly like a normal app.
// - On a wide desktop window / web browser (e.g. `flutter run -d chrome`)
//   the content is centered at a fixed phone width instead of stretching
//   across the whole browser window.
// ---------------------------------------------------------------------------
class MobileFrame extends StatelessWidget {
  final Widget child;
  final bool isDarkMode;
  const MobileFrame({super.key, required this.child, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width <= 480) {
      return child;
    }
    return Container(
      color: isDarkMode ? const Color(0xFF0F1216) : const Color(0xFFE7E9EB),
      child: Center(
        child: Container(
          width: 430,
          height: size.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class Additive {
  final String code;
  final String name;
  final String category; // 'Colour', 'Preservative', 'Emulsifier'...
  final String status; // 'HALAL', 'HARAM', 'MUSHBOOH'
  final String riskText; // 'Do not abuse', 'Very toxic', 'Toxic', 'Safe'
  final double riskScore; // 0.0 to 1.0
  final String origin; // 'animal', 'plant', 'chemical', 'insect'
  final List<String> flags; // 'EU', 'US', 'AU'
  final List<String> bannedFlags; // 'EU', 'US'
  final String description;
  final String? mushboohNote;
  final List<String> certifications; // 'VEGAN', 'JECFA'

  Additive({
    required this.code,
    required this.name,
    required this.category,
    required this.status,
    required this.riskText,
    required this.riskScore,
    required this.origin,
    required this.flags,
    this.bannedFlags = const [],
    this.description = '',
    this.mushboohNote,
    this.certifications = const [],
  });

  Additive copyWith({String? status}) {
    return Additive(
      code: code,
      name: name,
      category: category,
      status: status ?? this.status,
      riskText: riskText,
      riskScore: riskScore,
      origin: origin,
      flags: flags,
      bannedFlags: bannedFlags,
      description: description,
      mushboohNote: mushboohNote,
      certifications: certifications,
    );
  }
}

class AdditivesListScreen extends StatefulWidget {
  final bool isDarkMode;
  const AdditivesListScreen({super.key, this.isDarkMode = false});

  @override
  State<AdditivesListScreen> createState() => _AdditivesListScreenState();
}

class _AdditivesListScreenState extends State<AdditivesListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Halal', 'Haram'

  // Master database of additives
  final List<Additive> _allAdditives = [
    Additive(
      code: 'E100',
      name: 'Curcumina',
      category: 'Colour',
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.35,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Curcumin is a natural yellow-orange dye extracted from turmeric root. It is used as a colouring agent in food products such as mustard, cheese and confectionery.',
      mushboohNote:
          'This additive is Mushbooh. It is usually plant based, but the capsule or carrier used to stabilise it can sometimes contain gelatin, which would make it Haram.',
      certifications: ['JECFA'],
    ),
    Additive(
      code: 'E101',
      name: 'Riboflavin (Vitamin B2)',
      category: 'Colour',
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Natural riboflavin is the vitamin B2 found in wheat bran, eggs, meat and milk, among other things. They are used as natural coloring agents in food products.\n\n'
          'These dyes are naturally produced in the liver, kidney, eggs, milk and vegetables. They can also be prepared industrially by the synthesis of certain yeasts. E101 gives food a yellow color, but its use is limited by its low solubility.',
      mushboohNote:
          'Go carefully with this additive, sometimes it can come from pig liver and kidney then it would be Haram. But sometimes it comes from vegetable places.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E102',
      name: 'Tartrazine',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.8,
      origin: 'plant',
      flags: ['EU', 'US', 'AU'],
      description:
          'Tartrazine is a synthetic lemon-yellow azo dye used widely in soft drinks, sweets and snack foods. It is entirely plant/petrochemical derived, so it carries no animal-origin concerns.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E103',
      name: 'Chrysoine Resocinol',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.85,
      origin: 'plant',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Chrysoine Resocinol is a synthetic orange-yellow dye. It has been banned in most regions due to toxicity concerns, although it remains plant/chemical derived.',
      certifications: ['VEGAN'],
    ),
    Additive(
      code: 'E104',
      name: 'Quinoline Yellow',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.75,
      origin: 'chemical',
      flags: ['EU', 'AU'],
      bannedFlags: ['US'],
      description:
          'Quinoline Yellow is a synthetic coal-tar derived dye used to colour drinks, sweets and medicines. It is fully synthetic with no animal origin.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E107',
      name: 'Yellow 2G',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Toxic',
      riskScore: 0.6,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Yellow 2G is a synthetic azo dye, now banned in most countries because of links to hyperactivity and allergic reactions. It is synthetic, not animal derived.',
      certifications: ['VEGAN'],
    ),
    Additive(
      code: 'E110',
      name: 'Sunset Yellow FCF',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Toxic',
      riskScore: 0.55,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'Sunset Yellow FCF is a synthetic orange azo dye used in soft drinks, sweets, sauces and desserts. It is fully synthetic and carries no animal-origin concerns, though it has been linked to hyperactivity in children.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E111',
      name: 'Orange GGN',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Very toxic',
      riskScore: 0.9,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Orange GGN is an obsolete synthetic dye, banned worldwide because of severe toxicity. It is no longer permitted in any food supply.',
    ),
    Additive(
      code: 'E120',
      name: 'Cochineal or Carminic Acid',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Toxic',
      riskScore: 0.65,
      origin: 'insect',
      flags: ['EU', 'US', 'AU'],
      description:
          'Cochineal (Carmine) is a red dye extracted by crushing dried female cochineal insects. Because it is derived from insects, its ruling is disputed among scholars and treated here as Haram.',
    ),
    Additive(
      code: 'E122',
      name: 'Azorubine (Carmoisine)',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Toxic',
      riskScore: 0.55,
      origin: 'chemical',
      flags: ['EU', 'AU'],
      bannedFlags: ['US'],
      description:
          'Azorubine is a synthetic red azo dye used in jams, sweets and marzipan. It is fully synthetic and vegan, but banned in the US and linked to hyperactivity in sensitive children.',
      certifications: ['VEGAN'],
    ),
    Additive(
      code: 'E150A',
      name: 'Plain Caramel',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Safe',
      riskScore: 0.15,
      origin: 'plant',
      flags: ['EU', 'US', 'AU'],
      description:
          'Plain caramel colour is made by heating sugars (caramelisation) without ammonia or sulphite compounds. It is plant derived and considered safe at normal intake levels.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E160A',
      name: 'Carotenes',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Safe',
      riskScore: 0.1,
      origin: 'plant',
      flags: ['EU', 'US', 'AU'],
      description:
          'Carotenes are natural orange-yellow pigments found in carrots, pumpkins and other plants, used to colour margarine, juices and cheese.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E161I',
      name: 'Citranaxanthin',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.4,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Citranaxanthin is a synthetic carotenoid colourant, banned in most countries and classified as Haram in this listing due to unresolved sourcing concerns.',
    ),
    Additive(
      code: 'E161J',
      name: 'Astaxanthin',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.35,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Astaxanthin is a reddish-pink carotenoid pigment, often produced from algae or synthetically, but also sometimes from crustacean shells.',
    ),
    Additive(
      code: 'E200',
      name: 'Sorbic Acid',
      category: 'Preservative',
      status: 'HALAL',
      riskText: 'Safe',
      riskScore: 0.1,
      origin: 'plant',
      flags: ['EU', 'US', 'AU'],
      description:
          'Sorbic acid is a naturally occurring preservative found in berries, and is also produced synthetically. It is used to prevent mould and yeast growth in cheese, wine and baked goods.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E202',
      name: 'Potassium Sorbate',
      category: 'Preservative',
      status: 'HALAL',
      riskText: 'Safe',
      riskScore: 0.1,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'Potassium sorbate is the potassium salt of sorbic acid, widely used as a preservative in cheese, yogurt, wine and baked goods. It is fully synthetic/plant derived.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E211',
      name: 'Sodium Benzoate',
      category: 'Preservative',
      status: 'HALAL',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'Sodium benzoate is a widely used preservative in soft drinks, pickles and sauces. It is synthetic and vegan, though it can form benzene when combined with vitamin C in some drinks.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E220',
      name: 'Sulphur Dioxide',
      category: 'Preservative',
      status: 'MUSHBOOH',
      riskText: 'Toxic',
      riskScore: 0.5,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'Sulphur dioxide is used to preserve dried fruits, wine and juices. It is chemically produced, but some traditional production routes have raised concerns among certifying bodies.',
      mushboohNote:
          'This additive is Mushbooh in some rulings because of trace-processing concerns and its strong link to alcoholic fermentation control in wine-making, even though the compound itself is not alcohol.',
      certifications: ['VEGAN'],
    ),
    Additive(
      code: 'E249',
      name: 'Potassium Nitrite',
      category: 'Preservative',
      status: 'MUSHBOOH',
      riskText: 'Toxic',
      riskScore: 0.6,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'Potassium nitrite is used to cure meats such as sausages, ham and bacon, giving them their pink colour and preventing botulism.',
      mushboohNote:
          'This additive itself is chemical and not animal derived, but because it is almost always used specifically in meat curing, its status depends entirely on whether the meat it is used on is Halal-slaughtered.',
    ),
    Additive(
      code: 'E250',
      name: 'Sodium Nitrite',
      category: 'Preservative',
      status: 'MUSHBOOH',
      riskText: 'Toxic',
      riskScore: 0.6,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'Sodium nitrite is a common curing agent for processed meats, used to inhibit bacterial growth and preserve colour.',
      mushboohNote:
          'This additive is chemical in origin, but since it is used almost exclusively in meat products, its ruling depends on the Halal status of the meat it is added to.',
    ),
    Additive(
      code: 'E322',
      name: 'Lecithin',
      category: 'Emulsifier',
      status: 'MUSHBOOH',
      riskText: 'Safe',
      riskScore: 0.15,
      origin: 'plant',
      flags: ['EU', 'US', 'AU'],
      description:
          'Lecithin is an emulsifier commonly extracted from soybeans or sunflowers, used in chocolate, margarine and baked goods, though it can occasionally be sourced from egg yolk.',
      mushboohNote:
          'This additive is usually plant based (soy or sunflower) and Halal, but it can occasionally be derived from egg yolk or, more rarely, animal sources, so the exact origin should be checked.',
      certifications: ['JECFA'],
    ),
    Additive(
      code: 'E325',
      name: 'Sodium Lactate',
      category: 'Preservative',
      status: 'MUSHBOOH',
      riskText: 'Safe',
      riskScore: 0.15,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Sodium lactate is a salt of lactic acid, used as a preservative and flavour enhancer in processed meats, bread and dairy alternatives.',
      mushboohNote:
          'The lactic acid used to make sodium lactate can be produced by plant/microbial fermentation (Halal) or, less commonly, from animal-derived sources, so verification is recommended.',
      certifications: ['JECFA'],
    ),
    Additive(
      code: 'E422',
      name: 'Glycerol (Glycerin)',
      category: 'Humectant',
      status: 'MUSHBOOH',
      riskText: 'Safe',
      riskScore: 0.15,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Glycerol is used to retain moisture in baked goods, sweets and cosmetics. It can be derived from plant oils, animal fat, or produced synthetically from petroleum.',
      mushboohNote:
          'This additive is Mushbooh because glycerin can come from plant oils (Halal), animal fat (depends on the animal and slaughter method), or petrochemical synthesis (Halal), and the source is not always disclosed.',
      certifications: ['JECFA'],
    ),
    Additive(
      code: 'E428',
      name: 'Gelatin',
      category: 'Gelling agent',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.25,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Gelatin is a protein obtained by boiling skin, tendons, ligaments and/or bones with water, most commonly from pigs or cattle. Unless certified halal-slaughtered, it is treated as Haram.',
    ),
    Additive(
      code: 'E441',
      name: 'Superglycerinated hydrogenated rapeseed',
      category: 'Emulsifier',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'A modified rapeseed-oil emulsifier. It is classified Haram here because processing aids used in its manufacture cannot always be verified as animal-free.',
    ),
    Additive(
      code: 'E471',
      name: 'Mono- and diglycerides of fatty acids',
      category: 'Emulsifier',
      status: 'MUSHBOOH',
      riskText: 'Safe',
      riskScore: 0.1,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'E471 is an emulsifier used in breads, margarine and desserts. It can be produced from either plant oils or animal fat.',
      mushboohNote:
          'This additive is Mushbooh. The fatty acids can come from vegetable oil (Halal) or animal fat (Haram depending on the animal and slaughter method), so the source cannot always be confirmed.',
      certifications: ['JECFA'],
    ),
    Additive(
      code: 'E542',
      name: 'Bone Phosphate',
      category: 'Anti-caking agent',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'animal',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Bone phosphate is derived by processing animal bones, typically from cattle. Unless the source animal is confirmed Halal-slaughtered, it is treated as Haram.',
    ),
    Additive(
      code: 'E631',
      name: 'Disodium Inosinate',
      category: 'Flavour enhancer',
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.35,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'A flavour enhancer often used alongside MSG in savoury snacks, instant noodles and soups. It is commonly produced from fish or meat, though microbial/plant fermentation sources also exist.',
      mushboohNote:
          'This additive is Mushbooh because it can be derived from fish or meat by-products (which may or may not be Halal) or from plant/microbial fermentation, and manufacturers rarely disclose the exact source.',
    ),
    Additive(
      code: 'E904',
      name: 'Shellac',
      category: 'Glazing agent',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'insect',
      flags: ['EU', 'US', 'AU'],
      description:
          'Shellac is a resin secreted by the female lac insect, used to give a shiny coating to sweets, fruit and pills. Because it is an insect secretion, most scholars classify it as Haram.',
    ),
    Additive(
      code: 'E920',
      name: 'L-Cysteine',
      category: 'Flour treatment agent',
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.4,
      origin: 'animal',
      flags: ['EU', 'US'],
      bannedFlags: ['AU'],
      description:
          'L-Cysteine is used as a dough conditioner in bread and bakery products. It has historically been produced from human hair, duck feathers or pig bristles, though synthetic/fermentation-derived versions now also exist.',
      mushboohNote:
          'This additive is Mushbooh because L-cysteine can be produced from animal-derived sources (feathers, bristles, hair) or by microbial fermentation (Halal), and the source is rarely stated on packaging.',
    ),
    Additive(
      code: 'E1105',
      name: 'Lysozyme',
      category: 'Preservative',
      status: 'MUSHBOOH',
      riskText: 'Safe',
      riskScore: 0.2,
      origin: 'animal',
      flags: ['EU'],
      bannedFlags: ['US', 'AU'],
      description:
          'Lysozyme is an enzyme extracted from egg white, used as a natural preservative in cheese and wine to inhibit bacterial growth.',
      mushboohNote:
          'This additive is derived from egg white, which is generally Halal, but some scholars flag it as Mushbooh depending on the certification of the eggs and extraction process used.',
    ),
  ];

  List<Additive> get _filteredAdditives {
    return _allAdditives.where((additive) {
      // Filter by status
      if (_selectedFilter == 'Halal' && additive.status != 'HALAL') return false;
      if (_selectedFilter == 'Haram' && additive.status != 'HARAM') return false;

      // Filter by search query
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;

      return additive.code.toLowerCase().contains(query) ||
          additive.name.toLowerCase().contains(query);
    }).toList();
  }

  void _openDetail(Additive additive) async {
    final updated = await Navigator.push<Additive>(
      context,
      MaterialPageRoute(builder: (context) => AdditiveDetailScreen(additive: additive, isDarkMode: widget.isDarkMode)),
    );
    if (updated != null) {
      setState(() {
        final index = _allAdditives.indexWhere((a) => a.code == updated.code);
        if (index != -1) _allAdditives[index] = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAdditives;

    return MobileFrame(
      isDarkMode: widget.isDarkMode,
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : kBg,
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'List additives',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search additives (E100, E471...)',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${list.length} additives',
                  style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Row(
                  children: [
                    _buildFilterChip('All', kTeal),
                    const SizedBox(width: 10),
                    _buildFilterChip('Halal', kHalalGreen),
                    const SizedBox(width: 10),
                    _buildFilterChip('Haram', kHaramRed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Additives List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final additive = list[index];
                return _buildAdditiveCard(additive);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Color activeColor) {
    final bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (label == 'All' ? (widget.isDarkMode ? Colors.white70 : Colors.grey[600]) : activeColor),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAdditiveCard(Additive additive) {
    final badgeColor = statusColorOf(additive.status);
    final riskColor = riskColorOf(additive.riskText);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () => _openDetail(additive),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: E-code + flags stacked
              SizedBox(
                width: 66,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                       additive.code,
                       style: TextStyle(
                         fontSize: 19,
                         fontWeight: FontWeight.bold,
                         color: widget.isDarkMode ? Colors.white : Colors.black87,
                       ),
                     ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 0,
                      runSpacing: 3,
                      children: [
                        ...additive.flags.map((f) => _buildFlagIcon(f, false)),
                        ...additive.bannedFlags.map((f) => _buildFlagIcon(f, true)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Middle: name + risk row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                       additive.name,
                       style: TextStyle(
                         fontSize: 16,
                         fontWeight: FontWeight.w500,
                         color: widget.isDarkMode ? Colors.white : Colors.black87,
                         height: 1.2,
                       ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildRiskGauge(),
                        const SizedBox(width: 6),
                        Text(
                          additive.riskText,
                          style: TextStyle(
                            fontSize: 13,
                            color: riskColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: status badge + origin icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      additive.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomPaint(
                    size: const Size(32, 32),
                    painter: OriginPainter(origin: additive.origin),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlagIcon(String flagCode, bool isBanned) {
    return Container(
      margin: const EdgeInsets.only(right: 3, bottom: 3),
      width: 17,
      height: 13,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300]!, width: 0.5),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              flagCode == 'EU' ? '🇪🇺' : flagCode == 'US' ? '🇺🇸' : '🇦🇺',
              style: const TextStyle(fontSize: 9),
            ),
          ),
          if (isBanned)
            Container(
              color: Colors.red.withValues(alpha: 0.45),
              child: const Center(
                child: Icon(
                  Icons.block_flipped,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskGauge() {
    return SizedBox(
      width: 24,
      height: 13,
      child: CustomPaint(painter: RainbowGaugePainter()),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail screen — full page matching the reference design
// ---------------------------------------------------------------------------
class AdditiveDetailScreen extends StatefulWidget {
  final Additive additive;
  final bool isDarkMode;
  const AdditiveDetailScreen({super.key, required this.additive, this.isDarkMode = false});

  @override
  State<AdditiveDetailScreen> createState() => _AdditiveDetailScreenState();
}

class _AdditiveDetailScreenState extends State<AdditiveDetailScreen> {
  late Additive _additive;

  @override
  void initState() {
    super.initState();
    _additive = widget.additive;
  }

  void _showOverrideDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String currentStatus = _additive.status;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final color = statusColorOf(currentStatus);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_additive.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_additive.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Customize status for your country:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusButton(
                        label: 'Halal',
                        color: kHalalGreen,
                        isActive: currentStatus == 'HALAL',
                        onTap: () => setDialogState(() => currentStatus = 'HALAL'),
                      ),
                      _buildStatusButton(
                        label: 'Haram',
                        color: kHaramRed,
                        isActive: currentStatus == 'HARAM',
                        onTap: () => setDialogState(() => currentStatus = 'HARAM'),
                      ),
                      _buildStatusButton(
                        label: 'Mushbooh',
                        color: kMushboohOrange,
                        isActive: currentStatus == 'MUSHBOOH',
                        onTap: () => setDialogState(() => currentStatus = 'MUSHBOOH'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    setState(() {
                      _additive = _additive.copyWith(status: currentStatus);
                    });
                    await HalalScannerService.instance.saveAdditiveOverride(_additive.code, currentStatus);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Status of ${_additive.code} updated to $currentStatus!')),
                      );
                    }
                  },
                  child: const Text('Save Override', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusButton({
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = statusColorOf(_additive.status);
    final riskColor = riskColorOf(_additive.riskText);

    return MobileFrame(
      child: WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _additive);
        return false;
      },
      child: Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.navyBlue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _additive),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _additive.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _additive.code,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
              ),
              onPressed: _showOverrideDialog,
              tooltip: 'Customize status',
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status banner
              Container(
                width: double.infinity,
                color: statusColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _additive.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 14),
                    CustomPaint(
                      size: const Size(30, 30),
                      painter: OriginPainter(origin: _additive.origin),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    Text(
                      _additive.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A6CF7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _additive.category,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFD6499B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                     Text(
                       _additive.description,
                       textAlign: TextAlign.left,
                       style: TextStyle(fontSize: 15, color: widget.isDarkMode ? Colors.white : Colors.black87, height: 1.5),
                     ),

                    if (_additive.mushboohNote != null) ...[
                      const SizedBox(height: 18),
                       Text(
                         'This additive is ${_additive.status == 'MUSHBOOH' ? 'Mushbooh' : _additive.status[0]}${_additive.status.substring(1).toLowerCase()},',
                         style: TextStyle(fontSize: 15, color: widget.isDarkMode ? Colors.white : Colors.black87, height: 1.5),
                       ),
                       Text(
                         _additive.mushboohNote!,
                         style: TextStyle(fontSize: 15, color: widget.isDarkMode ? Colors.white : Colors.black87, height: 1.5),
                       ),
                    ],

                    if (_additive.certifications.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final cert in _additive.certifications) ...[
                            _buildCertBadge(cert),
                            const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 26),

                    // Flags approval rows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildApprovalRow('EU', 'Approved in European Union',
                                approved: _additive.flags.contains('EU')),
                            const SizedBox(height: 10),
                            _buildRiskRow(riskColor),
                            const SizedBox(height: 10),
                            _buildApprovalRow('US', 'Approved in United States',
                                approved: _additive.flags.contains('US')),
                            const SizedBox(height: 10),
                            _buildApprovalRow('AU', 'Approved in Australia and New Zealand',
                                approved: _additive.flags.contains('AU')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildRiskRow(Color riskColor) {
    return Row(
      children: [
        SizedBox(width: 26, height: 15, child: CustomPaint(painter: RainbowGaugePainter())),
        const SizedBox(width: 12),
        Text(
          _additive.riskText,
          style: TextStyle(fontSize: 14, color: riskColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildApprovalRow(String flagCode, String label, {required bool approved}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey[300]!, width: 0.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                flagCode,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              ),
              if (!approved)
                Container(
                  color: Colors.red.withValues(alpha: 0.45),
                  child: const Icon(Icons.block_flipped, color: Colors.white, size: 13),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: widget.isDarkMode ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildCertBadge(String type) {
    final isVegan = type == 'VEGAN';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isVegan ? const Color(0xFFE9573F) : const Color(0xFF43B77B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isVegan ? Icons.eco : Icons.verified, color: Colors.white, size: 18),
          const SizedBox(height: 2),
          Text(
            type,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rainbow risk-meter icon (green -> yellow -> orange -> red arc)
// ---------------------------------------------------------------------------
class RainbowGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 1.5;
    const colors = [
      Color(0xFF43B77B),
      Color(0xFFD8D93A),
      Color(0xFFF08A24),
      Color(0xFFE6483A),
    ];

    final sweepEach = 3.1415926 / colors.length;
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.1415926 + sweepEach * i,
        sweepEach,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Legacy single-color speedometer gauge — kept for backward compatibility
// with other screens in the project (e.g. product_detail_screen.dart) that
// still reference GaugeArcPainter directly.
// ---------------------------------------------------------------------------
class GaugeArcPainter extends CustomPainter {
  final double score;
  final Color color;

  GaugeArcPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.1415,
      3.1415,
      false,
      paint,
    );

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.1415,
      3.1415 * score,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Custom Origin Painter for drawing Pig, Leaf, Chemical Beaker, Bug
// ---------------------------------------------------------------------------
class OriginPainter extends CustomPainter {
  final String origin;

  OriginPainter({required this.origin});

  @override
  void paint(Canvas canvas, Size size) {
    if (origin == 'plant') {
      _paintLeaf(canvas, size);
    } else if (origin == 'animal') {
      _paintPig(canvas, size);
    } else if (origin == 'chemical') {
      _paintBeaker(canvas, size);
    } else if (origin == 'insect') {
      _paintBug(canvas, size);
    }
  }

  void _paintLeaf(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green[400]!
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, size.height * 0.1);
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.2,
      size.width * 0.8,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.9,
      size.width / 2,
      size.height * 0.9,
    );
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.9,
      size.width * 0.2,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.2,
      size.width / 2,
      size.height * 0.1,
    );
    canvas.drawPath(path, paint);

    final stemPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.9),
      Offset(size.width / 2, size.height * 0.2),
      stemPaint,
    );
  }

  void _paintPig(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.pink[100]!
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.pink[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.55),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.55),
      linePaint,
    );

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.45, size.width * 0.3, size.height * 0.22),
      Paint()..color = Colors.pink[200]!,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.45, size.width * 0.3, size.height * 0.22),
      linePaint,
    );
    canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.56), 1.5, Paint()..color = Colors.pink[400]!);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.56), 1.5, Paint()..color = Colors.pink[400]!);

    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.4), 1.5, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.4), 1.5, Paint()..color = Colors.black);

    final earPath1 = Path();
    earPath1.moveTo(size.width * 0.25, size.height * 0.3);
    earPath1.lineTo(size.width * 0.2, size.height * 0.15);
    earPath1.lineTo(size.width * 0.38, size.height * 0.25);
    earPath1.close();
    canvas.drawPath(earPath1, bodyPaint);
    canvas.drawPath(earPath1, linePaint);

    final earPath2 = Path();
    earPath2.moveTo(size.width * 0.75, size.height * 0.3);
    earPath2.lineTo(size.width * 0.8, size.height * 0.15);
    earPath2.lineTo(size.width * 0.62, size.height * 0.25);
    earPath2.close();
    canvas.drawPath(earPath2, bodyPaint);
    canvas.drawPath(earPath2, linePaint);
  }

  void _paintBeaker(Canvas canvas, Size size) {
    final flaskPaint = Paint()
      ..color = Colors.blue[300]!
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.blue[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(size.width * 0.4, size.height * 0.15);
    path.lineTo(size.width * 0.6, size.height * 0.15);
    path.lineTo(size.width * 0.6, size.height * 0.45);
    path.lineTo(size.width * 0.85, size.height * 0.85);
    path.lineTo(size.width * 0.15, size.height * 0.85);
    path.lineTo(size.width * 0.4, size.height * 0.45);
    path.close();

    canvas.drawPath(path, flaskPaint);
    canvas.drawPath(path, linePaint);

    final bubblePaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.75), 2.5, bubblePaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.65), 1.5, bubblePaint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.78), 2.0, bubblePaint);
  }

  void _paintBug(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.red[400]!
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final blackPaint = Paint()..color = Colors.black87;

    canvas.drawCircle(Offset(size.width / 2, size.height * 0.22), size.width * 0.13, blackPaint);

    canvas.drawCircle(Offset(size.width / 2, size.height * 0.58), size.width * 0.3, bodyPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.58), size.width * 0.3, linePaint);

    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.28),
      Offset(size.width / 2, size.height * 0.88),
      linePaint,
    );

    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.48), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.48), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.65), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.65), 2, blackPaint);

    canvas.drawLine(Offset(size.width * 0.45, size.height * 0.12), Offset(size.width * 0.38, size.height * 0.05), linePaint);
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.12), Offset(size.width * 0.62, size.height * 0.05), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// From: guides
// ============================================================
const tealColor = AppColors.midTeal;

// Keeps the screen phone-width on desktop/web (Chrome) by centering it on a
// grey backdrop, same trick used elsewhere in the app (e.g. QurbaniPlannerPage).
// On an actual Android device the screen width is already <= 430, so this
// has no visible effect there — it only kicks in on wide desktop windows.
class GuidesAndWalkthroughScreen extends StatefulWidget {
  final bool isDarkMode;
  const GuidesAndWalkthroughScreen({super.key, this.isDarkMode = false});

  @override
  State<GuidesAndWalkthroughScreen> createState() => _GuidesAndWalkthroughScreenState();
}

class _GuidesAndWalkthroughScreenState extends State<GuidesAndWalkthroughScreen> {
  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      isDarkMode: widget.isDarkMode,
      child: Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Guide',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3 Custom action guide buttons
              _buildGuideLinkButton(
                icon: Icons.qr_code_scanner_rounded,
                label: 'HOW DO I SCAN BY BARCODE?',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalkthroughCarousel(groupIndex: 0, isDarkMode: widget.isDarkMode),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildGuideLinkButton(
                icon: Icons.document_scanner_outlined,
                label: 'HOW DO I SCAN BY INGREDIENT TEXT?',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalkthroughCarousel(groupIndex: 1, isDarkMode: widget.isDarkMode),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildGuideLinkButton(
                icon: Icons.tune_rounded,
                label: 'HOW CAN I CONFIGURE AN ADDITIVE STATUS TO MY PREFERENCE OR BELIEF?',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalkthroughCarousel(groupIndex: 2, isDarkMode: widget.isDarkMode),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              Text(
                'What is Halal?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildArticleBox(
                text: 'Term that encompasses everything that is allowed, and therefore is beneficial and healthy for humans,promoting improved quality of life and reducing health risks.\n\n It could be translated as authorized, recommended, healthy, ethical or not abusive.\n\n Muslims understand the term Halal, as a lifestyle, a global and comprehensive concept that influences and affects everyday issues, such as food, hygiene, health, economy, fashion, commerce and tourism.',
              ),
              const SizedBox(height: 20),

              Text(
                'What is Haram?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildArticleBox(
                text: 'Term that refers to anything that is prohibited, not allowed, it is harmful or abusive. Are considered Haram, according to Islamic rules:\n'
                    '\u25b8 The meat of carrion.\n'
                    '\u25b8 The blood.\n'
                    '\u25b8 Pork and wild boar meat, as well as their derivatives.\n'
                    '\u25b8 Animals slaughtered without invoking the name of God.\n'
                    '\u25b8 Carnivorous and scavengers animals and birds with claws.\n'
                    '\u25b8 Alcohol, alcoholic beverages, harmful or poisonous substances and toxic plants or drinks.\n'
                    '\u25b8 Ingredients from Haram animals or products, such as pork gelatin. Additives, preservatives, colorings, flavorings, etc., produced from Haram ingredients.\n'
                    '\u25b8 Interest, usury and abusive speculation.\n'
                    '\u25b8 Wagering on the game.\n'
                    '\u25b8 Pornography.',
              ),
              const SizedBox(height: 20),

              Text(
                'What is Musbooh?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildArticleBox(
                text: 'A concept that refers to all things for which you can not clearly determine their origin or there are differences in valuation in the different Quranic traditions, in which case every Muslim decides his personal position before them.',
              ),
              const SizedBox(height: 24),

              Text(
                'Level of toxicity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              _buildIconGridBox(
                items: const [
                  _GuideGridItem(label: 'No/little toxic'),
                  _GuideGridItem(label: 'Do not abuse'),
                  _GuideGridItem(label: 'Doubtful'),
                  _GuideGridItem(label: 'Toxic'),
                  _GuideGridItem(label: 'Very toxic'),
                ],
                iconBuilder: (item, index, total) => _GaugeIcon(level: index, totalLevels: total),
              ),
              const SizedBox(height: 24),

              Text(
                'Origin of the additive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              _buildIconGridBox(
                items: const [
                  _GuideGridItem(label: 'Pork', emoji: '\ud83d\udc16'),
                  _GuideGridItem(label: 'Vegetable', emoji: '\ud83c\udf43'),
                  _GuideGridItem(label: 'Petroleum', emoji: '\ud83d\udee2'),
                  _GuideGridItem(label: 'Insects', emoji: '\ud83d\udc1e'),
                  _GuideGridItem(label: 'Alcohol', emoji: '\ud83c\udf77'),
                  _GuideGridItem(label: 'Synthetic', emoji: '\ud83e\uddea'),
                ],
                iconBuilder: (item, index, total) => Text(item.emoji!, style: const TextStyle(fontSize: 30)),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGuideLinkButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: tealColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tealColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: tealColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: tealColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: tealColor, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleBox({required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.grey[400]!, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildIconGridBox({
    required List<_GuideGridItem> items,
    required Widget Function(_GuideGridItem item, int index, int total) iconBuilder,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.grey[600]!, width: 2),
      ),
      child: Wrap(
        alignment: WrapAlignment.start,
        runSpacing: 24,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return SizedBox(
            width: MediaQuery.of(context).size.width / 2 - 30,
            child: Row(
              children: [
                SizedBox(width: 44, height: 44, child: Center(child: iconBuilder(item, index, items.length))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(fontSize: 14, color: widget.isDarkMode ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GuideGridItem {
  final String label;
  final String? emoji;
  const _GuideGridItem({required this.label, this.emoji});
}

// Small flat gauge/speedometer icon used in the "Level of toxicity" grid.
// Each toxicity level (0 = safest ... totalLevels-1 = most toxic) now gets
// its own needle position AND its own dominant color, so the five rows are
// visually distinguishable instead of all reusing one identical glyph.
class _GaugeIcon extends StatelessWidget {
  final int level;
  final int totalLevels;
  const _GaugeIcon({required this.level, required this.totalLevels});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 24),
      painter: _GaugePainter(level: level, totalLevels: totalLevels),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int level;
  final int totalLevels;
  _GaugePainter({required this.level, required this.totalLevels});

  static const gradientColors = [
    Color(0xFF4CAF50), // safe / no-little toxic
    Color(0xFF9FCB3C), // do not abuse
    Color(0xFFF4C430), // doubtful
    Color(0xFFEF8C1F), // toxic
    Color(0xFFE84A3D), // very toxic
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);

    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: gradientColors,
        startAngle: 3.1416,
        endAngle: 3.1416 * 2,
        center: Alignment.center,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 3.1416, 3.1416, false, arcPaint);

    // Needle angle sweeps from the far-left (safe) to the far-right (very
    // toxic) depending on this row's level, so every level looks different.
    final t = totalLevels > 1 ? level / (totalLevels - 1) : 0.0;
    final angle = 3.1416 + (3.1416 * t); // 180deg .. 360deg
    final center = Offset(size.width / 2, size.height);
    final needleLength = size.height * 0.85;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    // Needle colored to match this level's position on the gradient.
    final needleColor = gradientColors[level.clamp(0, gradientColors.length - 1)];
    final needlePaint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.grey[800]!);

    // Small colored dot at the needle tip to reinforce which level this is.
    canvas.drawCircle(needleEnd, 3, Paint()..color = needleColor);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.totalLevels != totalLevels;
}

// ============================================================
// Swipeable Walkthrough Onboarding Carousel (3 groups)
// ============================================================

class _SlideData {
  final String title;
  final String subtitle;
  final CustomPainter Function() painterBuilder;
  const _SlideData({required this.title, required this.subtitle, required this.painterBuilder});
}

final List<List<_SlideData>> _slideGroups = [
  // Group 0 — "HOW DO I SCAN BY BARCODE?" (3 slides)
  [
    _SlideData(
      title: 'Scan by barcode',
      subtitle: 'Look for the barcode on the product you want to know if it is Halal.',
      painterBuilder: () => BarcodeIllustrationPainter(),
    ),
    _SlideData(
      title: 'Scan the barcode',
      subtitle: 'Click the scan button and point the camera at the barcode.',
      painterBuilder: () => ScanTargetIllustrationPainter(),
    ),
    _SlideData(
      title: 'Ready!',
      subtitle: 'The app will tell you if the product is Halal, Haram or Mushbooh (makruh).',
      painterBuilder: () => ReadyStatusIllustrationPainter(),
    ),
  ],
  // Group 1 — "HOW DO I SCAN BY INGREDIENT TEXT?" (4 slides)
  [
    _SlideData(
      title: 'SEARCH INGREDIENT',
      subtitle: 'Search the product for the ingredients part.',
      painterBuilder: () => IngredientIllustrationPainter(),
    ),
    _SlideData(
      title: 'ENSURE',
      subtitle: 'Make sure the ingredients part of the product.',
      painterBuilder: () => EnsureLabelIllustrationPainter(),
    ),
    _SlideData(
      title: 'SCAN',
      subtitle: 'Launch the product scan (Camera Button) and point a few seconds to the ingredients part of the product.',
      painterBuilder: () => ScanIngredientIllustrationPainter(),
    ),
    _SlideData(
      title: 'ADDITIVES',
      subtitle: 'It is done! If there are additives in the product, the application will notify you if it is Halal, Haram or Mushbooh. Remember you have the responsibility to decide !!',
      painterBuilder: () => AdditivesResultIllustrationPainter(),
    ),
  ],
  // Group 2 — "HOW CAN I CONFIGURE AN ADDITIVE STATUS...?" (3 slides)
  [
    _SlideData(
      title: 'Customize your states in each additives',
      subtitle: 'If you think an additive is not the correct status for you or in your country. You can change the status to Halal, Haram or Mushbooh (makruh).',
      painterBuilder: () => CustomizeIllustrationPainter(),
    ),
    _SlideData(
      title: 'Access to the list of my states',
      subtitle: 'From the menu, select "My status additives".',
      painterBuilder: () => AccessListIllustrationPainter(),
    ),
    _SlideData(
      title: 'Add your state',
      subtitle: 'From the list you can add all the additives that you consider to be Halal, Haram or Mushbooh (makruh) for you. Your states will be taken into account in all the scans of your products.',
      painterBuilder: () => AddStateIllustrationPainter(),
    ),
  ],
];

class WalkthroughCarousel extends StatefulWidget {
  final int groupIndex;
  final bool isDarkMode;
  const WalkthroughCarousel({super.key, required this.groupIndex, this.isDarkMode = false});

  @override
  State<WalkthroughCarousel> createState() => _WalkthroughCarouselState();
}

class _WalkthroughCarouselState extends State<WalkthroughCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<_SlideData> _slides;

  @override
  void initState() {
    super.initState();
    _slides = _slideGroups[widget.groupIndex];
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastIndex = _slides.length - 1;

    return MobileFrame(
      isDarkMode: widget.isDarkMode,
      child: Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: _slides.map((slide) {
                return _buildSlide(
                  title: slide.title,
                  subtitle: slide.subtitle,
                  painter: slide.painterBuilder(),
                );
              }).toList(),
            ),
          ),

          // Pagination Dots and action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text back
                TextButton(
                  onPressed: _currentPage == 0
                      ? null
                      : () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        },
                  child: Text(
                    'BACK',
                    style: TextStyle(
                      color: _currentPage == 0 ? Colors.transparent : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Dot Indicators
                Row(
                  children: List.generate(_slides.length, (index) {
                    final isSelected = _currentPage == index;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? tealColor : (widget.isDarkMode ? Colors.white.withValues(alpha: 0.3) : Colors.grey[300]),
                      ),
                    );
                  }),
                ),

                // Text next / Finish
                TextButton(
                  onPressed: () {
                    if (_currentPage == lastIndex) {
                      Navigator.pop(context);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    _currentPage == lastIndex ? 'FINISH' : 'NEXT',
                    style: const TextStyle(
                      color: tealColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSlide({
    required String title,
    required String subtitle,
    required CustomPainter painter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tealColor.withValues(alpha: 0.15), width: 3),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(180, 180),
                painter: painter,
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: tealColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: widget.isDarkMode ? Colors.white70 : Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Shared helper: draws a rounded speech-bubble with bold white text,
// used by the "Ready!" and "ADDITIVES" slides.
void _drawSpeechBubble(Canvas canvas, Offset center, String text, Color color, {double fontSize = 12}) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final bubbleWidth = textPainter.width + 20;
  final bubbleHeight = textPainter.height + 12;
  final rect = Rect.fromCenter(center: center, width: bubbleWidth, height: bubbleHeight);

  final bubblePaint = Paint()..color = color..style = PaintingStyle.fill;
  canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), bubblePaint);

  textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
}

// ============================================================
// Simulation/Walkthrough painters
// ============================================================

class BarcodeIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw box illustration with magnifying glass looking at barcode
    final boxPaint = Paint()..color = Colors.amber[200]!..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = Colors.grey[400]!..style = PaintingStyle.stroke..strokeWidth = 1.5;

    // Draw Box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, size.height * 0.3, size.width * 0.45, size.width * 0.45),
        const Radius.circular(8),
      ),
      boxPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, size.height * 0.3, size.width * 0.45, size.width * 0.45),
        const Radius.circular(8),
      ),
      strokePaint,
    );

    // Draw Barcode lines inside
    final barPaint = Paint()..color = Colors.grey[700]!..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      double w = (i == 1 || i == 4) ? 4.0 : 1.5;
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.28 + (i * 7), size.height * 0.45, w, size.height * 0.15),
        barPaint,
      );
    }

    // Magnifying glass
    final glassPaint = Paint()..color = Colors.blue[100]!..style = PaintingStyle.fill;
    final glassBorder = Paint()..color = Colors.grey[600]!..style = PaintingStyle.stroke..strokeWidth = 3;
    final handlePaint = Paint()..color = Colors.grey[700]!..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.6), 24, glassPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.6), 24, glassBorder);
    canvas.drawLine(
      Offset(size.width * 0.77, size.height * 0.72),
      Offset(size.width * 0.9, size.height * 0.85),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "Scan the barcode": box + hand-held phone with a barcode on-screen,
// plus a small dark scan-icon badge.
class ScanTargetIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()..color = Colors.amber[100]!..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.3, size.width * 0.4, size.width * 0.4),
        const Radius.circular(8),
      ),
      boxPaint,
    );

    // Phone
    final phonePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final phoneBorder = Paint()..color = Colors.grey[800]!..style = PaintingStyle.stroke..strokeWidth = 3;
    final phoneRect = Rect.fromLTWH(size.width * 0.42, size.height * 0.28, size.width * 0.32, size.height * 0.42);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(14));
    canvas.drawRRect(phoneRRect, phonePaint);
    canvas.drawRRect(phoneRRect, phoneBorder);

    // Barcode label on phone screen
    final labelPaint = Paint()..color = Colors.amber[600]!..style = PaintingStyle.fill;
    final labelRect = Rect.fromLTWH(phoneRect.left + 6, phoneRect.top + phoneRect.height * 0.32, phoneRect.width - 12, phoneRect.height * 0.36);
    canvas.drawRect(labelRect, labelPaint);
    final barPaint = Paint()..color = Colors.grey[900]!..style = PaintingStyle.fill;
    for (int i = 0; i < 7; i++) {
      double w = (i % 3 == 0) ? 3.0 : 1.2;
      canvas.drawRect(Rect.fromLTWH(labelRect.left + 4 + (i * 5), labelRect.top + 4, w, labelRect.height - 8), barPaint);
    }

    // Hand (simple rounded shape below phone)
    final handPaint = Paint()..color = const Color(0xFFF2C29A)..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(phoneRect.left - 6, phoneRect.bottom - 10, phoneRect.width + 12, size.height * 0.18),
        const Radius.circular(18),
      ),
      handPaint,
    );

    // Small scan badge (bottom left)
    final badgePaint = Paint()..color = const Color(0xFF2B2B2B)..style = PaintingStyle.fill;
    final badgeCenter = Offset(size.width * 0.22, size.height * 0.78);
    canvas.drawCircle(badgeCenter, 22, badgePaint);
    final badgeIconPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromCenter(center: badgeCenter, width: 20, height: 16), badgeIconPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "Ready!": phone with a red/orange/green result strip and 3 speech
// bubbles (HALAL / HARAM / MUSBOOH) branching off it.
class ReadyStatusIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Phone body
    final phonePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final phoneBorder = Paint()..color = Colors.grey[800]!..style = PaintingStyle.stroke..strokeWidth = 3;
    final phoneRect = Rect.fromLTWH(size.width * 0.36, size.height * 0.32, size.width * 0.3, size.height * 0.46);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(14));
    canvas.drawRRect(phoneRRect, phonePaint);
    canvas.drawRRect(phoneRRect, phoneBorder);

    // Tri-colour result strip inside phone
    final stripHeight = phoneRect.height / 3;
    canvas.drawRect(Rect.fromLTWH(phoneRect.left + 4, phoneRect.top + 4, phoneRect.width - 8, stripHeight - 2), Paint()..color = Colors.red);
    canvas.drawRect(Rect.fromLTWH(phoneRect.left + 4, phoneRect.top + 4 + stripHeight, phoneRect.width - 8, stripHeight - 2), Paint()..color = Colors.orange);
    canvas.drawRect(Rect.fromLTWH(phoneRect.left + 4, phoneRect.top + 4 + stripHeight * 2, phoneRect.width - 8, stripHeight - 4), Paint()..color = Colors.green);

    // Speech bubbles
    _drawSpeechBubble(canvas, Offset(size.width * 0.22, size.height * 0.18), 'HALAL', Colors.green);
    _drawSpeechBubble(canvas, Offset(size.width * 0.78, size.height * 0.18), 'HARAM', Colors.red);
    _drawSpeechBubble(canvas, Offset(size.width * 0.8, size.height * 0.6), 'MUSBOOH', Colors.orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class IngredientIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw carton/bottle with label selector region
    final bottlePaint = Paint()..color = Colors.blue[50]!..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.blue[300]!..style = PaintingStyle.stroke..strokeWidth = 2;

    // Milk Carton Shape
    final path = Path();
    path.moveTo(size.width * 0.35, size.height * 0.15);
    path.lineTo(size.width * 0.65, size.height * 0.15);
    path.lineTo(size.width * 0.7, size.height * 0.28);
    path.lineTo(size.width * 0.7, size.height * 0.85);
    path.lineTo(size.width * 0.3, size.height * 0.85);
    path.lineTo(size.width * 0.3, size.height * 0.28);
    path.close();

    canvas.drawPath(path, bottlePaint);
    canvas.drawPath(path, borderPaint);

    // Label with red dotted select border
    final labelPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.38, size.height * 0.45, size.width * 0.24, size.height * 0.3), labelPaint);

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw simulated red dotted line
    canvas.drawRect(Rect.fromLTWH(size.width * 0.36, size.height * 0.43, size.width * 0.28, size.height * 0.34), dotPaint);

    // Mock text lines inside label
    final textPaint = Paint()..color = Colors.grey[400]!..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.4, size.height * 0.48 + (i * 6), size.width * 0.2, 2),
        textPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "ENSURE": close-up half of the carton with a green ingredient label
// showing readable text lines.
class EnsureLabelIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Left grey half + right blue half (close-up carton)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.4, size.height), Paint()..color = Colors.grey[300]!);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.6, 0, size.width * 0.4, size.height), Paint()..color = Colors.blue[400]!);

    // Green ingredient label in the middle
    final labelRect = Rect.fromLTWH(size.width * 0.32, size.height * 0.32, size.width * 0.36, size.height * 0.36);
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(4)), Paint()..color = AppColors.midTeal);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Ingredient:\nCochineal or\nCarminic Acid,\nE140,\nE-150,E161H,\nAstaxanthin....',
        style: TextStyle(color: Colors.white, fontSize: 6, height: 1.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelRect.width - 8);
    textPainter.paint(canvas, Offset(labelRect.left + 4, labelRect.top + 4));

    // Drip drop above
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.12), 4, Paint()..color = Colors.blue[400]!);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "SCAN": same close-up carton + a phone mirroring the ingredient label,
// with a small scan badge.
class ScanIngredientIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.4, size.height), Paint()..color = Colors.grey[300]!);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.6, 0, size.width * 0.4, size.height), Paint()..color = Colors.blue[400]!);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.12), 4, Paint()..color = Colors.blue[400]!);

    // Phone showing the label
    final phonePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final phoneBorder = Paint()..color = Colors.grey[800]!..style = PaintingStyle.stroke..strokeWidth = 3;
    final phoneRect = Rect.fromLTWH(size.width * 0.32, size.height * 0.28, size.width * 0.36, size.height * 0.44);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(14));
    canvas.drawRRect(phoneRRect, phonePaint);
    canvas.drawRRect(phoneRRect, phoneBorder);

    final labelRect = Rect.fromLTWH(phoneRect.left + 4, phoneRect.top + 4, phoneRect.width - 8, phoneRect.height - 8);
    canvas.drawRect(labelRect, Paint()..color = AppColors.midTeal);
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Ingredient:\nCochineal or\nCarminic A...\nE140,\nE-150,E161H\nAstaxanthin',
        style: TextStyle(color: Colors.white, fontSize: 6, height: 1.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelRect.width - 6);
    textPainter.paint(canvas, Offset(labelRect.left + 3, labelRect.top + 3));

    // Scan badge (bottom left)
    final badgeCenter = Offset(size.width * 0.16, size.height * 0.78);
    canvas.drawCircle(badgeCenter, 22, Paint()..color = const Color(0xFF2B2B2B));
    final iconPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromCenter(center: badgeCenter, width: 16, height: 20), iconPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "ADDITIVES": carton + phone + 3 speech bubbles (HALAL / HARAM / MUSBOOH).
class AdditivesResultIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.15, size.width * 0.36, size.height * 0.6), Paint()..color = Colors.grey[300]!);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.56, size.height * 0.15, size.width * 0.36, size.height * 0.6), Paint()..color = Colors.blue[400]!);

    final phonePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final phoneBorder = Paint()..color = Colors.grey[800]!..style = PaintingStyle.stroke..strokeWidth = 3;
    final phoneRect = Rect.fromLTWH(size.width * 0.3, size.height * 0.28, size.width * 0.32, size.height * 0.4);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(12));
    canvas.drawRRect(phoneRRect, phonePaint);
    canvas.drawRRect(phoneRRect, phoneBorder);
    canvas.drawRect(
      Rect.fromLTWH(phoneRect.left + 3, phoneRect.top + 3, phoneRect.width - 6, phoneRect.height - 6),
      Paint()..color = AppColors.midTeal,
    );

    _drawSpeechBubble(canvas, Offset(size.width * 0.24, size.height * 0.15), 'HALAL', Colors.green, fontSize: 10);
    _drawSpeechBubble(canvas, Offset(size.width * 0.76, size.height * 0.13), 'HARAM', Colors.red, fontSize: 10);
    _drawSpeechBubble(canvas, Offset(size.width * 0.76, size.height * 0.78), 'MUSBOOH', Colors.orange, fontSize: 10);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CustomizeIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Person icon in circle, paths branching out to different 471 statuses
    final circlePaint = Paint()..color = Colors.grey[100]!..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.45, circlePaint);

    // Center avatar
    final avatarPaint = Paint()..color = Colors.grey[700]!..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.52), 12, avatarPaint);
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.4, size.height * 0.65, size.width * 0.2, size.height * 0.16),
      avatarPaint,
    );

    // 3 Status flags branching out
    _drawStatusBubble(canvas, size, Offset(size.width * 0.25, size.height * 0.3), '471', Colors.green);
    _drawStatusBubble(canvas, size, Offset(size.width * 0.5, size.height * 0.2), '471', Colors.orange);
    _drawStatusBubble(canvas, size, Offset(size.width * 0.75, size.height * 0.3), '471', Colors.red);

    // Connecting arrows
    final arrowPaint = Paint()..color = Colors.grey[400]!..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width / 2, size.height * 0.45), Offset(size.width * 0.35, size.height * 0.35), arrowPaint);
    canvas.drawLine(Offset(size.width / 2, size.height * 0.45), Offset(size.width / 2, size.height * 0.28), arrowPaint);
    canvas.drawLine(Offset(size.width / 2, size.height * 0.45), Offset(size.width * 0.65, size.height * 0.35), arrowPaint);
  }

  void _drawStatusBubble(Canvas canvas, Size size, Offset offset, String text, Color color) {
    final bubblePaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: offset, radius: 14),
        const Radius.circular(6),
      ),
      bubblePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "Access to the list of my states": sliders icon above a phone showing
// a settings-style list.
class AccessListIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sliders icon
    final sliderPaint = Paint()..color = Colors.grey[700]!..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    final knobPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final knobBorder = Paint()..color = Colors.grey[700]!..style = PaintingStyle.stroke..strokeWidth = 2.5;

    final sliderYs = [size.height * 0.08, size.height * 0.18, size.height * 0.28];
    final knobXs = [size.width * 0.65, size.width * 0.4, size.width * 0.6];
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(Offset(size.width * 0.25, sliderYs[i]), Offset(size.width * 0.75, sliderYs[i]), sliderPaint);
      canvas.drawCircle(Offset(knobXs[i], sliderYs[i]), 5, knobPaint);
      canvas.drawCircle(Offset(knobXs[i], sliderYs[i]), 5, knobBorder);
    }

    // Phone with a small list
    final phonePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final phoneBorder = Paint()..color = Colors.grey[800]!..style = PaintingStyle.stroke..strokeWidth = 3;
    final phoneRect = Rect.fromLTWH(size.width * 0.3, size.height * 0.4, size.width * 0.4, size.height * 0.5);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(14));
    canvas.drawRRect(phoneRRect, phonePaint);
    canvas.drawRRect(phoneRRect, phoneBorder);

    // Header bar
    canvas.drawRect(
      Rect.fromLTWH(phoneRect.left + 3, phoneRect.top + 3, phoneRect.width - 6, phoneRect.height * 0.14),
      Paint()..color = AppColors.midTeal,
    );

    // List rows
    final rowPaint = Paint()..color = Colors.grey[300]!..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          phoneRect.left + 6,
          phoneRect.top + phoneRect.height * 0.24 + (i * phoneRect.height * 0.16),
          phoneRect.width - 12,
          phoneRect.height * 0.1,
        ),
        rowPaint,
      );
    }

    // Hand under the phone
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(phoneRect.left - 6, phoneRect.bottom - 10, phoneRect.width + 12, size.height * 0.16),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFFF2C29A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "Add your state": phone with a status list + magnifying glass with an
// "M" (Mushbooh) badge, matching the final onboarding slide.
class AddStateIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final phonePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final phoneBorder = Paint()..color = Colors.grey[800]!..style = PaintingStyle.stroke..strokeWidth = 3;
    final phoneRect = Rect.fromLTWH(size.width * 0.28, size.height * 0.22, size.width * 0.44, size.height * 0.56);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(14));
    canvas.drawRRect(phoneRRect, phonePaint);
    canvas.drawRRect(phoneRRect, phoneBorder);

    canvas.drawRect(
      Rect.fromLTWH(phoneRect.left + 3, phoneRect.top + 3, phoneRect.width - 6, phoneRect.height * 0.12),
      Paint()..color = AppColors.midTeal,
    );

    final statusColors = [Colors.green, Colors.red, Colors.orange, Colors.green];
    for (int i = 0; i < statusColors.length; i++) {
      final rowTop = phoneRect.top + phoneRect.height * 0.2 + (i * phoneRect.height * 0.18);
      canvas.drawRect(
        Rect.fromLTWH(phoneRect.left + 6, rowTop, phoneRect.width * 0.5, 6),
        Paint()..color = Colors.grey[300]!,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(phoneRect.right - 26, rowTop - 3, 18, 12),
          const Radius.circular(3),
        ),
        Paint()..color = statusColors[i],
      );
    }

    // Hand under phone
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(phoneRect.left - 6, phoneRect.bottom - 10, phoneRect.width + 12, size.height * 0.16),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFFF2C29A),
    );

    // Magnifying glass with "M" badge, overlapping top-right of the phone
    final glassCenter = Offset(phoneRect.right - 6, phoneRect.top + 4);
    canvas.drawCircle(glassCenter, 22, Paint()..color = Colors.orange[300]!);
    canvas.drawCircle(glassCenter, 22, Paint()..color = Colors.grey[700]!..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawLine(
      Offset(glassCenter.dx + 15, glassCenter.dy + 15),
      Offset(glassCenter.dx + 28, glassCenter.dy + 28),
      Paint()..color = Colors.grey[700]!..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    final mPainter = TextPainter(
      text: const TextSpan(text: 'M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    mPainter.paint(canvas, Offset(glassCenter.dx - mPainter.width / 2, glassCenter.dy - mPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// From: health
// ============================================================
class HealthTipArticle {
  final String title;
  final String description;
  final String date;
  final IconData icon;
  final List<Color> gradient;
  final String content;
  // Path to the article's image, e.g. 'assets/images/health_tips/xxx.jpg'.
  // Drop your downloaded image at this path (and register the folder in
  // pubspec.yaml under flutter/assets) — if the file isn't there yet, a
  // gradient + icon placeholder is shown instead so nothing crashes.
  final String imagePath;

  HealthTipArticle({
    required this.title,
    required this.description,
    required this.date,
    required this.icon,
    required this.gradient,
    required this.content,
    required this.imagePath,
  });
}

class HealthTipsScreen extends StatefulWidget {
  final bool isDarkMode;
  const HealthTipsScreen({super.key, this.isDarkMode = false});

  @override
  State<HealthTipsScreen> createState() => _HealthTipsScreenState();
}

class _HealthTipsScreenState extends State<HealthTipsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<HealthTipArticle> _articles = [
    HealthTipArticle(
      title: 'The impact of what we eat on our spirit...',
      description: 'In Islam, food is not only a physical necessity, it also influences the heart and faith. E...',
      date: 'Yesterday',
      icon: Icons.spa_outlined,
      gradient: const [Color(0xFF8E9EAB), Color(0xFFEEF2F3)],
      imagePath: 'assets/images/health_tips/impact_of_food.jpg',
      content: 'In Islam, food is not only a physical necessity, it also influences the heart and faith. Eating Halal and tayyib (pure and wholesome) strengthens the connection with Allah and brings spiritual peace.\n\nKey aspects:\n\n\ud83d\udd45 Obedience to Allah: choosing Halal is fulfilling a divine command.\n\n\u2764\ufe0f Inner purity: what we consume directly affects our spiritual state.\n\n\ud83c\udf3f Balance of the soul: healthy and natural foods promote calmness and gratitude.\n\n\ud83d\udc6a Example for the family: teaching Halal eating transmits faith and values.\n\nEvery bite can bring us closer or farther from spirituality. That\u2019s why consciously choosing what we eat is part of living Islam every day.\n\ud83d\udc49 With Tag Halal you can ensure what you consume is truly Halal and beneficial for both body and soul.',
    ),
    HealthTipArticle(
      title: 'Are Vinegars Halal? Discover the Truth...',
      description: 'Specialty vinegars such as balsamic, wine, or apple cider vinegar generate many doubts in...',
      date: '20 Jul',
      icon: Icons.liquor_outlined,
      gradient: const [Color(0xFFE1533B), Color(0xFFE9967A)],
      imagePath: 'assets/images/health_tips/vinegars_halal.jpg',
      content: 'Vinegar produced by natural fermentation of alcohol is halal, as the chemical structure changes entirely from an intoxicant to an acid. However, wine vinegar requires scrutiny to ensure no residual wine remains. Balsamic and cider vinegars are generally halal unless synthetic alcohol is artificially introduced.',
    ),
    HealthTipArticle(
      title: '\ud83e\uddc0 Not All Cheese Is Halal! The Truth A...',
      description: 'Cheese is one of the most deceptive foods for Muslims because its key ingredient, rennet, ...',
      date: '17 Jul',
      icon: Icons.breakfast_dining_outlined,
      gradient: const [Color(0xFFFFB347), Color(0xFFFFCC33)],
      imagePath: 'assets/images/health_tips/cheese_halal.jpg',
      content: 'The primary concern in cheese production is the source of "rennet"\u2014the enzyme used to coagulate milk. If the rennet is extracted from an animal slaughtered according to Islamic law, or is of microbial/vegetable origin, the cheese is Halal. Otherwise, if sourced from non-halal animal sources, it is Haram.',
    ),
    HealthTipArticle(
      title: 'Healthy alternatives to ultra-processed ...',
      description: 'You don\'t need to give up taste to avoid ultra-processed foods. There are many healthy and...',
      date: '14 Jul',
      icon: Icons.local_dining_outlined,
      gradient: const [Color(0xFF83a4d4), Color(0xFFb6fbff)],
      imagePath: 'assets/images/health_tips/ultra_processed_alternatives.jpg',
      content: 'Replace processed snacks with wholesome alternatives like dates, figs, almonds, or honey. These are traditional foods recommended in the Sunnah that support gut health, lower blood pressure, and supply clean energy without toxic preservatives or synthetic additives.',
    ),
    HealthTipArticle(
      title: 'Seasonal Vegetables in the Month of Ju...',
      description: 'With the summer just beginning, the vegetables that thrive in the heat are now in full swi...',
      date: '08 Jul',
      icon: Icons.eco_outlined,
      gradient: const [Color(0xFF56AB2F), Color(0xFFA8E063)],
      imagePath: 'assets/images/health_tips/seasonal_vegetables.jpg',
      content: 'Summertime brings nutrient-rich vegetables like zucchini, peppers, and cucumbers. Consuming seasonal produce ensures high vitamin intake, boosts hydration levels naturally, and aligns our diet with local natural cycles.',
    ),
    HealthTipArticle(
      title: '\ud83e\uddec Live Longer and Better: How Fasting...',
      description: 'Modern science has discovered something revolutionary: fasting not only helps you live mor...',
      date: '02 Jul',
      icon: Icons.insights_outlined,
      gradient: const [Color(0xFF30CFD0), Color(0xFF330867)],
      imagePath: 'assets/images/health_tips/fasting_live_longer.jpg',
      content: 'Intermittent fasting triggers autophagy\u2014a cellular cleaning process where the body breaks down and recycles damaged cells. Following the Sunnah by fasting on Mondays and Thursdays delivers immense biological benefits, helping to regulate sugar levels, reduce inflammation, and prolong healthy lifespan.',
    ),
    HealthTipArticle(
      title: '\u26a0\ufe0f WARNING! This red insect is in your ...',
      description: 'What is E120? E120 or Carmine is a RED dye made by crushing live insects called cochineal....',
      date: '29 Jun',
      icon: Icons.bug_report_outlined,
      gradient: const [Color(0xFFED213A), Color(0xFF93291E)],
      imagePath: 'assets/images/health_tips/red_insect_e120.jpg',
      content: 'E120, also known as Carmine, is a popular red coloring extracted from cochineal insects. In Islamic jurisprudence, many scholars consider insect consumption forbidden (Haram) because they are not permissible land animals, except under very specific medical necessity. Check labels on candies, yogurts, and juices!',
    ),
    HealthTipArticle(
      title: '\u2764\ufe0f Your Invisible Shield: How Fasting Pr...',
      description: 'Prophet Muhammad \ufdfa described fasting as a shield (junnah) against the fire of hell and the...',
      date: '26 Jun',
      icon: Icons.favorite_border_rounded,
      gradient: const [Color(0xFFEF32D9), Color(0xFF89FFFD)],
      imagePath: 'assets/images/health_tips/fasting_shield.jpg',
      content: 'Fasting provides a spiritual and psychological defense system. It shields the mind from evil inclinations, reduces anger, increases empathy for the poor, and acts as a barrier protecting the believer from physical illnesses and spiritual negligence.',
    ),
    HealthTipArticle(
      title: '\ud83c\udf77 Hidden alcohol in common products \ud83c\udf77 ...',
      description: 'Alcohol doesn\'t always appear under its direct name on...',
      date: '23 Jun',
      icon: Icons.warning_amber_rounded,
      gradient: const [Color(0xFF232526), Color(0xFF414345)],
      imagePath: 'assets/images/health_tips/hidden_alcohol.jpg',
      content: 'Alcohol can hide behind terms like "flavor carriers," "vanilla extract," "soy sauce fermenters," or chemical names like ethanol, ethyl alcohol, and propylene glycol. Always review the extraction carrier used in liquid supplements, desserts, and bakery products.',
    ),
  ];

  void _openArticle(HealthTipArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HealthTipDetailScreen(article: article, isDarkMode: widget.isDarkMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = AppColors.midTeal;

    return MobileFrame(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9FA),
        drawer: HalalDrawer(
          activeRoute: 'Health tips',
          isDarkMode: widget.isDarkMode,
        ),
        appBar: AppBar(
          backgroundColor: AppColors.navyBlue,
          elevation: 0,
         
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
     ),
          title: const Text(
            'Health tips',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: ListView.builder(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0),
          itemCount: _articles.length,
          itemBuilder: (context, index) {
            final article = _articles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
              ),
              child: InkWell(
                onTap: () => _openArticle(article),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Left thumbnail — shows the real image once you drop
                      // it at article.imagePath; falls back to the gradient
                      // + icon placeholder until then.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            article.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: article.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(article.icon, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Right text column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    article.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  article.date,
                                  style: TextStyle(
                                    color: widget.isDarkMode ? Colors.white70 : Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              article.description,
                              style: TextStyle(
                                color: widget.isDarkMode ? Colors.white70 : Colors.grey[600],
                                fontSize: 12,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Full-page article detail — matches the "Tag Halal Food" reference design:
// back + share app bar, a boxed image, a boxed title, and a boxed content
// paragraph, all on a light mint background.
class HealthTipDetailScreen extends StatelessWidget {
  final HealthTipArticle article;
  final bool isDarkMode;

  const HealthTipDetailScreen({super.key, required this.article, this.isDarkMode = false});

  static const Color tealColor = AppColors.midTeal;
  static const Color pageBg = Color(0xFFE3F2EC);

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : pageBg,
        appBar: AppBar(
          backgroundColor: AppColors.navyBlue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Tag Halal Food',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sharing "${article.title}"...')),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Boxed hero image — drop your image at article.imagePath.
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tealColor, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        article.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: article.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(article.icon, color: Colors.white, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tealColor, width: 1.2),
                  ),
                  child: Text(
                    article.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Content box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tealColor, width: 1.2),
                  ),
                  child: Text(
                    article.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// From: analyze
// ============================================================
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
        final finalAiResult = aiResult.copyWithOverrides(HalalScannerService.instance.additiveOverrides);
        setState(() {
          _analysisResult = finalAiResult;
          _cleanIngredientsList = finalAiResult.ingredients;
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
        final finalAiResult = textAiResult.copyWithOverrides(HalalScannerService.instance.additiveOverrides);
        setState(() {
          _analysisResult = finalAiResult;
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
        overrides: HalalScannerService.instance.additiveOverrides,
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

    Future.delayed(const Duration(seconds: 1), () async {
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
        await HalalScannerState.addProduct(_analysisResult!.toScannedProduct());
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

// ============================================================
// From: product_detail
// ============================================================
class ProductIngredient {
  final String code;
  final String name;
  final String status;
  final String riskText;
  final double riskScore;
  final String origin;

  const ProductIngredient({
    required this.code,
    required this.name,
    required this.status,
    required this.riskText,
    required this.riskScore,
    required this.origin,
  });

  Color get statusColor {
    switch (status) {
      case 'HARAM':
        return Colors.redAccent;
      case 'MUSHBOOH':
        return AppColors.coralOrange;
      default:
        return Colors.green;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'HARAM':
        return Icons.cancel_rounded;
      case 'MUSHBOOH':
        return Icons.warning_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }
}

class ProductDetailScreen extends StatefulWidget {
  final ScannedProduct product;
  final bool isDarkMode;
  final List<IngredientAnalysisResult>? analysisResults;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.isDarkMode = false,
    this.analysisResults,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  List<ProductIngredient>? _ingredients;

  List<ProductIngredient> _buildIngredients() {
    if (widget.analysisResults != null && widget.analysisResults!.isNotEmpty) {
      return widget.analysisResults!.map((result) {
        return ProductIngredient(
          code: HalalAnalyzerService.extractCode(result.ingredient),
          name: result.ingredient,
          status: result.status,
          riskText: _getRiskText(result.status),
          riskScore: _getRiskScore(result.status),
          origin: _getOriginFromIngredient(result.ingredient, result.status),
        );
      }).toList();
    }

    final analysis = HalalAnalyzerService.analyzeIngredients(
      ingredients: widget.product.ingredients,
      additives: widget.product.additives,
      productName: widget.product.name,
      barcode: widget.product.barcode,
      imageUrl: widget.product.imageUrl,
      overrides: HalalScannerService.instance.additiveOverrides,
    );

    return analysis.results.map((result) {
      return ProductIngredient(
        code: HalalAnalyzerService.extractCode(result.ingredient),
        name: result.ingredient,
        status: result.status,
        riskText: _getRiskText(result.status),
        riskScore: _getRiskScore(result.status),
        origin: _getOriginFromIngredient(result.ingredient, result.status),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsList = _ingredients ??= _buildIngredients();
    final statusColor = _statusColor(widget.product.status);
    final bgColor = widget.isDarkMode ? const Color(0xFF101923) : const Color(0xFFF8FAF9);
    final cardColor = widget.isDarkMode ? const Color(0xFF1A2633) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.navyBlue;

    final haramCount = ingredientsList.where((i) => i.status == 'HARAM').length;
    final mushboohCount = ingredientsList.where((i) => i.status == 'MUSHBOOH').length;
    final halalCount = ingredientsList.where((i) => i.status == 'HALAL').length;

    final halalMeatKeywords = [
      'chicken', 'beef', 'mutton', 'lamb', 'sheep', 'goat', 'turkey', 'duck',
      'poultry', 'meat', 'veal'
    ];
    final hasHalalMeat = ingredientsList.any((ing) {
      final nameLower = ing.name.toLowerCase();
      return halalMeatKeywords.any((kw) => nameLower.contains(kw));
    }) || halalMeatKeywords.any((kw) => widget.product.name.toLowerCase().contains(kw));

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
          AppLocalizations.of(context)!.tr('product_details'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing ${widget.product.name}...')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor,
                    statusColor.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Product image
                  _buildProductImage(statusColor),
                  const SizedBox(height: 14),
                  Text(
                    widget.product.status,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.product.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${AppLocalizations.of(context)!.tr("barcode")}: ${widget.product.barcode}',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Summary stats cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Halal',
                      count: halalCount,
                      color: Colors.green,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Mushbooh',
                      count: mushboohCount,
                      color: AppColors.coralOrange,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Haram',
                      count: haramCount,
                      color: Colors.redAccent,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ingredients list section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_rounded, color: AppColors.midTeal, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${AppLocalizations.of(context)!.tr("ingredients")} (${ingredientsList.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: ingredientsList.length,
              itemBuilder: (context, index) {
                final ing = ingredientsList[index];
                return _buildIngredientCard(ing, cardColor, textColor, widget.isDarkMode);
              },
            ),
            if (hasHalalMeat) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: widget.isDarkMode ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: widget.isDarkMode ? 0.4 : 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.tr('halal_slaughter_note'),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: widget.isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(
    ProductIngredient ing,
    Color cardColor,
    Color textColor,
    bool isDarkMode,
  ) {
    Color badgeColor = ing.statusColor;
    IconData originIcon = _getOriginIcon(ing.origin);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(ing.statusIcon, color: badgeColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ing.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(originIcon, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ing.origin,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Risk: ${ing.riskText}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                        ),
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
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ing.status,
              style: GoogleFonts.poppins(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getOriginIcon(String origin) {
    String lower = origin.toLowerCase();
    final animalStr = AppLocalizations.of(context)!.tr('animal').toLowerCase();
    if (lower.contains('animal') || lower.contains('pork') || lower == animalStr) {
      return Icons.pets_rounded;
    }
    if (lower.contains('plant') || lower.contains('vegetable') || lower.contains('fruit')) {
      return Icons.eco_rounded;
    }
    if (lower.contains('alcohol')) {
      return Icons.local_bar_rounded;
    }
    if (lower.contains('insect')) {
      return Icons.bug_report_rounded;
    }
    return Icons.science_rounded;
  }

  String _getRiskText(String status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 'HARAM':
        return l10n.tr('avoid');
      case 'MUSHBOOH':
        return l10n.tr('do_not_abuse');
      default:
        return l10n.tr('safe');
    }
  }

  double _getRiskScore(String status) {
    switch (status) {
      case 'HARAM':
        return 0.8;
      case 'MUSHBOOH':
        return 0.4;
      default:
        return 0.1;
    }
  }

  String _getOriginFromIngredient(String ingredient, String status) {
    final l10n = AppLocalizations.of(context);
    String lower = ingredient.toLowerCase();

    final animalKeywords = [
      'chicken', 'beef', 'mutton', 'lamb', 'sheep', 'goat', 'turkey', 'duck',
      'poultry', 'meat', 'veal', 'pork', 'pig', 'bacon', 'ham', 'gelatin',
      'tallow', 'lard', 'suet', 'bone'
    ];

    for (String kw in animalKeywords) {
      if (lower.contains(kw)) {
        return l10n.tr('animal');
      }
    }

    if (status == 'HARAM') {
      if (lower.contains('cochineal') || lower.contains('carmine') || lower.contains('insect')) {
        return l10n.tr('insect');
      }
      if (lower.contains('alcohol') || lower.contains('ethanol') || lower.contains('beer') ||
          lower.contains('wine') || lower.contains('vodka')) {
        return l10n.tr('alcohol');
      }
      return l10n.tr('animal');
    }
    if (status == 'MUSHBOOH') {
      return l10n.tr('unknown');
    }
    return l10n.tr('plant_chemical');
  }

  /// Builds the product image widget for the hero banner.
  /// Handles: network URL, local file path, and empty/missing image.
  Widget _buildProductImage(Color statusColor) {
    final imageUrl = widget.product.imageUrl;
    final isNetwork = imageUrl.startsWith('http');
    final isLocalFile = imageUrl.isNotEmpty && !isNetwork;

    Widget imageChild;

    if (isNetwork) {
      imageChild = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        },
        errorBuilder: (_, _a, _b) => _imageFallbackIcon(statusColor),
      );
    } else if (isLocalFile) {
      imageChild = Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, _a, _b) => _imageFallbackIcon(statusColor),
      );
    } else {
      imageChild = _imageFallbackIcon(statusColor);
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2.5,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: imageChild,
    );
  }

  Widget _imageFallbackIcon(Color statusColor) {
    return Container(
      color: statusColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          _statusIcon(widget.product.status),
          color: statusColor,
          size: 52,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'HALAL') return Colors.green;
    if (status == 'HARAM') return Colors.redAccent;
    return AppColors.coralOrange;
  }

  IconData _statusIcon(String status) {
    if (status == 'HALAL') return Icons.check_circle_rounded;
    if (status == 'HARAM') return Icons.cancel_rounded;
    return Icons.warning_rounded;
  }
}

// ============================================================
// From: scanner
// ============================================================
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

  bool _isScanning = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _productNotFound = false;

  @override
  void initState() {
    super.initState();
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
    // Rule-based Halal analysis (dictionary + E-number lookups) run locally.
    return HalalAnalyzerService.analyzeIngredients(
      ingredients: productData.ingredients,
      additives: productData.additives,
      productName: productData.name,
      barcode: barcode,
      imageUrl: productData.imageUrl,
      overrides: HalalScannerService.instance.additiveOverrides,
    );
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
        actions: const [],
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

// ============================================================
// From: drawer
// ============================================================
class HalalDrawer extends StatelessWidget {
  final String activeRoute;
  final bool isDarkMode;

  const HalalDrawer({
    super.key,
    required this.activeRoute,
    required this.isDarkMode,
  });

  void _navigateTo(BuildContext context, Widget screen, String routeName) {
    Navigator.of(context).pop(); // Close drawer
    if (activeRoute == routeName) return;

    if (routeName == 'Home') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HalalScannerHomeScreen(isDarkMode: isDarkMode)),
        (route) => route.isFirst,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = AppColors.navyBlue;
    final drawerBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Drawer(
      child: Container(
        color: drawerBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header
            DrawerHeader(
              decoration: const BoxDecoration(
                color: tealColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'حلال',
                      style: TextStyle(
                        color: tealColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tag Halal Food (v 204)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // General Items
            _buildDrawerItem(
              context,
              icon: Icons.local_offer_outlined,
              label: 'Home',
              routeName: 'Home',
              destination: HalalScannerHomeScreen(isDarkMode: isDarkMode),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.list_alt_rounded,
              label: 'List additives',
              routeName: 'List additives',
              destination: AdditivesListScreen(isDarkMode: isDarkMode),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.history_rounded,
              label: 'Scanned history',
              routeName: 'Scanned history',
              destination: ScannedHistoryScreen(isDarkMode: isDarkMode),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.report_problem_outlined,
              label: 'Report product',
              routeName: 'Report product',
              destination: AnalyzeProductScreen(isDarkMode: isDarkMode),
            ),

            Divider(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
            _buildSectionHeader('Health & Wellness'),

            _buildDrawerItem(
              context,
              icon: Icons.notifications_none_rounded,
              label: 'Health tips',
              routeName: 'Health tips',
              destination: HealthTipsScreen(isDarkMode: isDarkMode),
            ),


            _buildDrawerItem(
              context,
              icon: Icons.help_outline_rounded,
              label: 'Guide',
              routeName: 'Guide',
              destination: GuidesAndWalkthroughScreen(isDarkMode: isDarkMode),
            ),


            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String routeName,
    required Widget destination,
  }) {
    final bool isSelected = activeRoute == routeName;
    const tealColor = AppColors.midTeal;
    final unselectedIconColor =
        isDarkMode ? Colors.white70 : Colors.grey[700];
    final unselectedTextColor = isDarkMode ? Colors.white : Colors.black87;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? tealColor : unselectedIconColor,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? tealColor : unselectedTextColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: tealColor.withValues(alpha: 0.08),
      onTap: () => _navigateTo(context, destination, routeName),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final unselectedIconColor =
        isDarkMode ? Colors.white70 : Colors.grey[700];
    final unselectedTextColor = isDarkMode ? Colors.white : Colors.black87;
    return ListTile(
      leading: Icon(
        icon,
        color: unselectedIconColor,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: unselectedTextColor,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Go Premium'),
          ],
        ),
        content: const Text(
          'Unlock unlimited scans, custom additives overrides, ad-free experience, and advanced ingredient AI analysis for only \$1.99/month!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.midTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Successfully subscribed to DeenMate Premium!')),
              );
            },
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }
}