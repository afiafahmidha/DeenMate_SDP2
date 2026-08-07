import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'analyze_product_screen.dart';
import 'guides_and_walkthrough.dart';
import 'product_detail_screen.dart';
import 'scanned_history_screen.dart';
import 'health_tips_screen.dart';
import 'additives_list_screen.dart';
import 'real_barcode_scanner.dart';
import '../../widgets/auth_header.dart';
import '../../services/halal_analyzer_service.dart';
import '../../l10n/app_localizations.dart';

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

  static void addProduct(ScannedProduct product) {
    // Remove existing duplicate if present
    final existingIndex = history.indexWhere((h) {
      if (product.barcode.isNotEmpty && h.barcode.isNotEmpty) {
        return h.barcode == product.barcode;
      }
      return h.name.trim().toLowerCase() == product.name.trim().toLowerCase();
    });

    if (existingIndex != -1) {
      final oldProduct = history.removeAt(existingIndex);
      if (oldProduct.status == 'HALAL' && halalCount > 0) {
        halalCount--;
      } else if (oldProduct.status == 'HARAM' && haramCount > 0) {
        haramCount--;
      } else if (mushboohCount > 0) {
        mushboohCount--;
      }
    }

    history.insert(0, product);
    if (product.status == 'HALAL') {
      halalCount++;
    } else if (product.status == 'HARAM') {
      haramCount++;
    } else {
      mushboohCount++;
    }
    if (remainingScans > 0) remainingScans--;
  }

  static void clearHistory() {
    history.clear();
    halalCount = 0;
    haramCount = 0;
    mushboohCount = 0;
    remainingScans = 7;
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
                leading: Icon(Icons.camera_alt_outlined, color: const Color(0xFF55A498), size: 28),
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
                leading: Icon(Icons.image_outlined, color: const Color(0xFF55A498), size: 28),
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
          onScanComplete: (product) {
            setState(() {
              HalalScannerState.addProduct(product);
            });
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
                          color: tealColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: tealColor.withValues(alpha: 0.22),
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
                                color: Colors.white.withValues(alpha: 0.2),
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
                          border: Border.all(color: tealColor.withValues(alpha: 0.25), width: 1.4),
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
                                color: tealColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.document_scanner_outlined,
                                color: tealColor,
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
                                      color: widget.isDarkMode ? Colors.white : tealColor,
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
                              color: tealColor,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildQuickAccessSection(),
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
                    if (HalalScannerState.history.isEmpty)
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
              color: AppColors.midTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.midTeal, size: 20),
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
          MaterialPageRoute(builder: (_) => GuidesAndWalkthroughScreen(isDarkMode: widget.isDarkMode)),
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: items.map((item) => _buildQuickAccessCard(item)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(_QuickAccessItem item) {
    final surfaceColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = widget.isDarkMode ? Colors.white : AppColors.navyBlue;
    final borderColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1);
    final shadowColor = widget.isDarkMode ? Colors.black.withValues(alpha: 0.3) : AppColors.navyBlue.withValues(alpha: 0.04);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const Spacer(),
              Text(
                item.title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
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