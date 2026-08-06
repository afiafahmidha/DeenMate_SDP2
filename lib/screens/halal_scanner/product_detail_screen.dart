import 'package:flutter/material.dart';
import 'halal_scanner_home.dart';
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
        return Colors.red;
      case 'MUSHBOOH':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'HARAM':
        return Icons.cancel;
      case 'MUSHBOOH':
        return Icons.warning;
      default:
        return Icons.check_circle;
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
  late List<ProductIngredient> _ingredients;

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
    _ingredients ??= _buildIngredients();
    const tealColor = Color(0xFF55A498);
    final statusColor = _statusColor(widget.product.status);
    final isDarkMode = widget.isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final haramCount = _ingredients.where((i) => i.status == 'HARAM').length;
    final mushboohCount = _ingredients.where((i) => i.status == 'MUSHBOOH').length;
    final halalCount = _ingredients.where((i) => i.status == 'HALAL').length;

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
          AppLocalizations.of(context)!.tr('product_details'),
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
                SnackBar(content: Text('Sharing ${widget.product.name}...')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Icon(_statusIcon(widget.product.status), color: Colors.white, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    widget.product.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                     '${AppLocalizations.of(context)!.tr("barcode")}: ${widget.product.barcode}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                  if (_ingredients.isNotEmpty)
                    Text(
                        '${_ingredients.length} ${AppLocalizations.of(context)!.tr("ingredients_analyzed")}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                ],
              ),
            ),
            if (widget.product.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.product.imageUrl,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Origin & risk summary row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.public,
                           label: AppLocalizations.of(context)!.tr('origin'),
                          value: widget.product.origin,
                          color: tealColor,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.health_and_safety_outlined,
                           label: AppLocalizations.of(context)!.tr('risk_level'),
                          value: widget.product.risk,
                          color: widget.product.risk == 'Safe' || widget.product.risk.contains('Safe')
                              ? Colors.green
                              : widget.product.risk.contains('Haram')
                                  ? Colors.red
                                  : Colors.orange,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // INGREDIENTS LIST
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                     Text(
                        AppLocalizations.of(context)!.tr('ingredients'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                         '${_ingredients.length} ${AppLocalizations.of(context)!.tr("items")}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_ingredients.isEmpty)
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
                              AppLocalizations.of(context)!.tr('no_ingredients'),
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                             AppLocalizations.of(context)!.tr('no_ingredient_data'),
                            style: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._ingredients.map((ing) => _buildIngredientCard(ing, isDarkMode)),

                  const SizedBox(height: 16),

                  // SUMMARY CARDS
                  if (haramCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
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
                              '$haramCount ${AppLocalizations.of(context)!.tr("haram_ingredients_found")}',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (mushboohCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
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
                              '$mushboohCount ${AppLocalizations.of(context)!.tr("mushbooh_ingredients_found")}',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_ingredients.isNotEmpty && halalCount == _ingredients.length)
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
                           '✅ All $halalCount ${AppLocalizations.of(context)!.tr("all_halal_ingredients")}',
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

                  // Report button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tealColor,
                        side: BorderSide(color: tealColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(AppLocalizations.of(context)!.tr('report_submitted'))),
                           );
                      },
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(AppLocalizations.of(context)!.tr('report_incorrect')),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(ProductIngredient ing, bool isDarkMode) {
    final badgeColor = ing.statusColor;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ing.statusIcon,
              color: badgeColor,
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
                      ing.code,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ing.name,
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
                const SizedBox(height: 2),
                Text(
                  ing.riskText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white54 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              ing.status,
              style: TextStyle(
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
    if (status == 'HARAM') {
      if (lower.contains('pork') || lower.contains('pig') || lower.contains('bacon') ||
          lower.contains('ham') || lower.contains('gelatin') || lower.contains('tallow')) {
        return l10n.tr('animal');
      }
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

  Color _statusColor(String status) {
    if (status == 'HALAL') return Colors.green;
    if (status == 'HARAM') return Colors.red;
    return Colors.orange;
  }

  IconData _statusIcon(String status) {
    if (status == 'HALAL') return Icons.check_circle_rounded;
    if (status == 'HARAM') return Icons.cancel_rounded;
    return Icons.warning_rounded;
  }
}