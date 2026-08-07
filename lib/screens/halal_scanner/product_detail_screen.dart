import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'halal_scanner_home.dart';
import '../../widgets/auth_header.dart';
import '../../services/halal_analyzer_service.dart';
import '../../l10n/app_localizations.dart';

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