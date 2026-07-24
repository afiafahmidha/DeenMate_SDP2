import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'halal_drawer.dart';

class AuthoritySource {
  final String name;
  final String label;
  final String description;

  AuthoritySource({
    required this.name,
    required this.label,
    required this.description,
  });
}

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<AuthoritySource> _sources = [
    AuthoritySource(
      name: 'JACFA',
      label: 'Joint FAO/WHO Committee',
      description: 'The Joint FAO/WHO Expert Committee on Food Additives is an international expert scientific committee that is administered jointly by the Food and Agriculture Organization of the United Nations (FAO) and the World Health Organization (WHO).',
    ),
    AuthoritySource(
      name: 'EFSA',
      label: 'European Food Safety Authority',
      description: 'The European Food Safety Authority is the agency of the European Union that provides independent scientific advice and communicates on existing and emerging risks associated with the food chain.',
    ),
    AuthoritySource(
      name: 'FRL',
      label: 'Food Standards Australia NZ',
      description: 'FRL is the food regulatory authority that develops standards for food composition, labeling, and additives across Australia and New Zealand to ensure safety and transparency.',
    ),
    AuthoritySource(
      name: 'FSA',
      label: 'Food Standards Agency UK',
      description: 'The Food Standards Agency is a non-ministerial government department of the UK responsible for protecting public health and the wider interest of consumers in relation to food.',
    ),
    AuthoritySource(
      name: 'FDA',
      label: 'US Food & Drug Administration',
      description: 'The United States Food and Drug Administration is a federal agency responsible for protecting public health by ensuring the safety, efficacy, and security of human foods, drugs, and cosmetics.',
    ),
    AuthoritySource(
      name: 'WHO-OMS',
      label: 'World Health Organization',
      description: 'The WHO works globally to promote health, keep the world safe, and serve the vulnerable, compiling standards for global food additives safety and nutritional thresholds.',
    ),
    AuthoritySource(
      name: 'Open Food Facts',
      label: 'Open Food Database',
      description: 'Open Food Facts is a free, open-collaborative database of food products from around the world, containing ingredient lists, allergens, and additive labels populated by users globally.',
    ),
  ];

  void _showSourceDetail(AuthoritySource source) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(source.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF55A498), fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              source.description,
              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF55A498))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9FA),
      drawer: const HalalDrawer(activeRoute: 'Source'),
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: const Text(
          'Source',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Our sources',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              // Grid View
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: _sources.length,
                itemBuilder: (context, index) {
                  final src = _sources[index];
                  return _buildSourceCard(src);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceCard(AuthoritySource source) {
    const tealColor = Color(0xFF55A498);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tealColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: () => _showSourceDetail(source),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Abstract Emblem representing the source logo
              Expanded(
                child: Center(
                  child: CustomPaint(
                    size: const Size(60, 60),
                    painter: SourceLogoPainter(name: source.name),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                source.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Logo Painters representing Jacfa, Efsa, etc.
class SourceLogoPainter extends CustomPainter {
  final String name;

  SourceLogoPainter({required this.name});

  @override
  void paint(Canvas canvas, Size size) {
    if (name == 'JACFA') {
      _paintJacfa(canvas, size);
    } else if (name == 'EFSA') {
      _paintEfsa(canvas, size);
    } else if (name == 'FRL') {
      _paintFrl(canvas, size);
    } else if (name == 'FSA') {
      _paintFsa(canvas, size);
    } else if (name == 'FDA') {
      _paintFda(canvas, size);
    } else if (name == 'WHO-OMS') {
      _paintWho(canvas, size);
    } else {
      _paintOpenFood(canvas, size);
    }
  }

  void _paintJacfa(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue[800]!..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.45, paint);

    // Inner details (cross line grid)
    final linePaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, linePaint);
    canvas.drawLine(Offset(size.width / 2, size.height * 0.15), Offset(size.width / 2, size.height * 0.85), linePaint);
    canvas.drawLine(Offset(size.width * 0.15, size.height / 2), Offset(size.width * 0.85, size.height / 2), linePaint);
  }

  void _paintEfsa(Canvas canvas, Size size) {
    // Crescent of dots
    final paint = Paint()..color = Colors.orange[400]!..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      double angle = i * 0.5;
      double x = size.width / 2 + size.width * 0.25 * math.cos(angle);
      double y = size.height / 2 + size.height * 0.25 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 3.5, paint);
    }
    // "efsa" mock letters
    final textPaint = Paint()..color = Colors.blue[900]!..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.4, size.height * 0.42, size.width * 0.3, size.height * 0.15), textPaint);
  }

  void _paintFrl(Canvas canvas, Size size) {
    // Shield coat of arms representation
    final paint = Paint()..color = Colors.grey[700]!..style = PaintingStyle.stroke..strokeWidth = 2;
    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.3);
    path.lineTo(size.width * 0.7, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.6, size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.3, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  void _paintFsa(Canvas canvas, Size size) {
    // Green vertical bar structure
    final paint = Paint()..color = Colors.green[600]!..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.3, size.height * 0.2, size.width * 0.4, size.height * 0.6),
        const Radius.circular(4),
      ),
      paint,
    );
    // inside columns
    final colPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.38, size.height * 0.25, size.width * 0.05, size.height * 0.5), colPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.48, size.height * 0.25, size.width * 0.05, size.height * 0.5), colPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.58, size.height * 0.25, size.width * 0.05, size.height * 0.5), colPaint);
  }

  void _paintFda(Canvas canvas, Size size) {
    // Bold FDA letters
    final paint = Paint()..color = Colors.blue[800]!..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.2, size.height * 0.35, size.width * 0.6, size.height * 0.3), paint);
  }

  void _paintWho(Canvas canvas, Size size) {
    // World Health Organization circle snake staff representation
    final paint = Paint()..color = Colors.blue[400]!..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.4, paint);

    final staffPaint = Paint()..color = Colors.blue[600]!..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawLine(Offset(size.width / 2, size.height * 0.15), Offset(size.width / 2, size.height * 0.85), staffPaint);

    final snakePath = Path();
    snakePath.moveTo(size.width * 0.4, size.height * 0.7);
    snakePath.quadraticBezierTo(size.width * 0.6, size.height * 0.55, size.width * 0.45, size.height * 0.45);
    snakePath.quadraticBezierTo(size.width * 0.3, size.height * 0.3, size.width * 0.5, size.height * 0.2);
    canvas.drawPath(snakePath, paint);
  }

  void _paintOpenFood(Canvas canvas, Size size) {
    // Rainbow stripes barcode logo
    final List<Color> colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.indigo];
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()..color = colors[i]..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.2 + (i * 7), size.height * 0.3, 5, size.height * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}