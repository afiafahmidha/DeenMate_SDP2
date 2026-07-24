import 'package:flutter/material.dart';
import 'additives_list_screen.dart';
import 'halal_scanner_home.dart';

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
}

class ProductDetailScreen extends StatelessWidget {
  final ScannedProduct product;

  const ProductDetailScreen({super.key, required this.product});

  static List<ProductIngredient> sampleIngredientsFor(ScannedProduct product) {
    if (product.status == 'HARAM') {
      return const [
        ProductIngredient(
          code: 'E120',
          name: 'Cochineal / Carmine',
          status: 'HARAM',
          riskText: 'Toxic',
          riskScore: 0.65,
          origin: 'insect',
        ),
        ProductIngredient(
          code: 'E428',
          name: 'Gelatin',
          status: 'HARAM',
          riskText: 'Do not abuse',
          riskScore: 0.25,
          origin: 'animal',
        ),
        ProductIngredient(
          code: 'E330',
          name: 'Citric acid',
          status: 'HALAL',
          riskText: 'Safe',
          riskScore: 0.05,
          origin: 'plant',
        ),
      ];
    }
    if (product.status == 'MUSHBOOH') {
      return const [
        ProductIngredient(
          code: 'E471',
          name: 'Mono- and diglycerides',
          status: 'MUSHBOOH',
          riskText: 'Safe',
          riskScore: 0.1,
          origin: 'animal',
        ),
        ProductIngredient(
          code: 'E322',
          name: 'Lecithin',
          status: 'MUSHBOOH',
          riskText: 'Do not abuse',
          riskScore: 0.3,
          origin: 'plant',
        ),
        ProductIngredient(
          code: 'E500',
          name: 'Sodium carbonates',
          status: 'HALAL',
          riskText: 'Safe',
          riskScore: 0.05,
          origin: 'chemical',
        ),
      ];
    }
    return const [
      ProductIngredient(
        code: 'E300',
        name: 'Ascorbic acid (Vitamin C)',
        status: 'HALAL',
        riskText: 'Safe',
        riskScore: 0.05,
        origin: 'plant',
      ),
      ProductIngredient(
        code: 'E440',
        name: 'Pectins',
        status: 'HALAL',
        riskText: 'Safe',
        riskScore: 0.08,
        origin: 'plant',
      ),
      ProductIngredient(
        code: 'E330',
        name: 'Citric acid',
        status: 'HALAL',
        riskText: 'Safe',
        riskScore: 0.05,
        origin: 'plant',
      ),
    ];
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

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);
    final statusColor = _statusColor(product.status);
    final ingredients = sampleIngredientsFor(product);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FA),
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Product details',
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
                SnackBar(content: Text('Sharing ${product.name}...')),
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
                  Icon(_statusIcon(product.status), color: Colors.white, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    product.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Barcode: ${product.barcode}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
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
                          label: 'Origin',
                          value: product.origin,
                          color: tealColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.health_and_safety_outlined,
                          label: 'Risk level',
                          value: product.risk,
                          color: product.risk == 'Safe'
                              ? Colors.green
                              : product.risk == 'Toxic'
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detected additives',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${ingredients.length} items',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Ingredient list
                  ...ingredients.map((ing) => _buildIngredientCard(ing)),

                  const SizedBox(height: 16),

                  // Report / analyze actions
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
                          const SnackBar(content: Text('Report submitted. Thank you!')),
                        );
                      },
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Report incorrect status'),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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

  Widget _buildIngredientCard(ProductIngredient ing) {
    final badgeColor = _statusColor(ing.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ing.code,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ing.name,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 14,
                      child: CustomPaint(
                        painter: GaugeArcPainter(
                          score: ing.riskScore,
                          color: ing.riskScore < 0.4
                              ? Colors.green
                              : ing.riskScore < 0.7
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(ing.riskText, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ing.status,
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          CustomPaint(
            size: const Size(24, 24),
            painter: OriginPainter(origin: ing.origin),
          ),
        ],
      ),
    );
  }
}
