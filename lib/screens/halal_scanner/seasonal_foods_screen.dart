import 'package:flutter/material.dart';
import 'halal_drawer.dart';

class SeasonalFoodItem {
  final String name;
  final String category; // 'Fruit' or 'Vegetable'

  SeasonalFoodItem({required this.name, required this.category});
}

class SeasonalFoodsScreen extends StatefulWidget {
  const SeasonalFoodsScreen({super.key});

  @override
  State<SeasonalFoodsScreen> createState() => _SeasonalFoodsScreenState();
}

class _SeasonalFoodsScreenState extends State<SeasonalFoodsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedMonth = 'JULY';

  final List<String> _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
  ];

  // Database of seasonal foods
  final Map<String, List<SeasonalFoodItem>> _seasonalData = {
    'JULY': [
      SeasonalFoodItem(name: 'Apricot', category: 'Fruit'),
      SeasonalFoodItem(name: 'Fig', category: 'Fruit'),
      SeasonalFoodItem(name: 'Cherry', category: 'Fruit'),
      SeasonalFoodItem(name: 'Plum', category: 'Fruit'),
      SeasonalFoodItem(name: 'Peach', category: 'Fruit'),
      SeasonalFoodItem(name: 'Cantaloupe', category: 'Fruit'),
      SeasonalFoodItem(name: 'Nectarine', category: 'Fruit'),
      SeasonalFoodItem(name: 'Paraguay', category: 'Fruit'),
      SeasonalFoodItem(name: 'Pear', category: 'Fruit'),
      SeasonalFoodItem(name: 'Banana', category: 'Fruit'),
      SeasonalFoodItem(name: 'Watermelon', category: 'Fruit'),
      SeasonalFoodItem(name: 'Garlic', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Eggplant', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Zucchini', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Onion', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Lettuce', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Cucumber', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Pepper', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Leek', category: 'Vegetable'),
    ],
    'JUNE': [
      SeasonalFoodItem(name: 'Strawberry', category: 'Fruit'),
      SeasonalFoodItem(name: 'Raspberry', category: 'Fruit'),
      SeasonalFoodItem(name: 'Apricot', category: 'Fruit'),
      SeasonalFoodItem(name: 'Cherry', category: 'Fruit'),
      SeasonalFoodItem(name: 'Asparagus', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Spinach', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Peas', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Broccoli', category: 'Vegetable'),
    ],
    'AUGUST': [
      SeasonalFoodItem(name: 'Blackberry', category: 'Fruit'),
      SeasonalFoodItem(name: 'Fig', category: 'Fruit'),
      SeasonalFoodItem(name: 'Melon', category: 'Fruit'),
      SeasonalFoodItem(name: 'Plum', category: 'Fruit'),
      SeasonalFoodItem(name: 'Tomato', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Corn', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Eggplant', category: 'Vegetable'),
      SeasonalFoodItem(name: 'Okra', category: 'Vegetable'),
    ],
  };

  List<SeasonalFoodItem> _getCurrentFoods() {
    return _seasonalData[_selectedMonth] ?? _seasonalData['JULY']!;
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);
    final foods = _getCurrentFoods();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9FA),
      drawer: const HalalDrawer(activeRoute: 'Seasonal foods'),
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
          'Seasonal foods',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Month Selector dropdown
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: tealColor.withValues(alpha: 0.5), width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  icon: const Icon(Icons.arrow_drop_down, color: tealColor, size: 28),
                  isExpanded: true,
                  style: const TextStyle(
                    color: tealColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMonth = newValue;
                      });
                    }
                  },
                  items: _months.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Center(child: Text(value)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Seasonal Food Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemCount: foods.length,
              itemBuilder: (context, index) {
                final item = foods[index];
                return _buildFoodCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(SeasonalFoodItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic representation of food
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              child: CustomPaint(
                painter: FoodIconPainter(name: item.name),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            item.category,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// Food Icon Custom Painter to render cute, colorful fruits and vegetables
class FoodIconPainter extends CustomPainter {
  final String name;

  FoodIconPainter({required this.name});

  @override
  void paint(Canvas canvas, Size size) {
    final cleanName = name.toLowerCase().trim();

    if (cleanName == 'apricot') {
      _drawApricot(canvas, size);
    } else if (cleanName == 'fig') {
      _drawFig(canvas, size);
    } else if (cleanName == 'cherry') {
      _drawCherry(canvas, size);
    } else if (cleanName == 'plum') {
      _drawPlum(canvas, size);
    } else if (cleanName == 'peach' || cleanName == 'paraguay') {
      _drawPeach(canvas, size);
    } else if (cleanName == 'cantaloupe') {
      _drawCantaloupe(canvas, size);
    } else if (cleanName == 'nectarine') {
      _drawNectarine(canvas, size);
    } else if (cleanName == 'pear') {
      _drawPear(canvas, size);
    } else if (cleanName == 'banana') {
      _drawBanana(canvas, size);
    } else if (cleanName == 'watermelon') {
      _drawWatermelon(canvas, size);
    } else if (cleanName == 'garlic') {
      _drawGarlic(canvas, size);
    } else if (cleanName == 'eggplant') {
      _drawEggplant(canvas, size);
    } else if (cleanName == 'zucchini' || cleanName == 'cucumber') {
      _drawCucumber(canvas, size);
    } else if (cleanName == 'onion') {
      _drawOnion(canvas, size);
    } else if (cleanName == 'lettuce') {
      _drawLettuce(canvas, size);
    } else if (cleanName == 'pepper') {
      _drawPepper(canvas, size);
    } else if (cleanName == 'leek') {
      _drawLeek(canvas, size);
    } else {
      // Fallback: simple circle
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, Paint()..color = Colors.amber[300]!);
    }
  }

  void _drawApricot(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.orange[400]!..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.55), size.width * 0.32, paint);
    // leaf
    final leafPaint = Paint()..color = Colors.green..style = PaintingStyle.fill;
    final leafPath = Path();
    leafPath.moveTo(size.width * 0.5, size.height * 0.23);
    leafPath.quadraticBezierTo(size.width * 0.7, size.height * 0.1, size.width * 0.65, size.height * 0.3);
    leafPath.close();
    canvas.drawPath(leafPath, leafPaint);
  }

  void _drawFig(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.purple[800]!..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.cubicTo(
      size.width * 0.25, size.height * 0.5,
      size.width * 0.15, size.height * 0.85,
      size.width * 0.5, size.height * 0.85
    );
    path.cubicTo(
      size.width * 0.85, size.height * 0.85,
      size.width * 0.75, size.height * 0.5,
      size.width * 0.5, size.height * 0.15
    );
    canvas.drawPath(path, paint);
  }

  void _drawCherry(Canvas canvas, Size size) {
    final cherryPaint = Paint()..color = Colors.red[700]!..style = PaintingStyle.fill;
    final stemPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // two cherries
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.68), size.width * 0.16, cherryPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.62), size.width * 0.16, cherryPaint);

    // stems merging at top
    final path = Path();
    path.moveTo(size.width * 0.35, size.height * 0.55);
    path.quadraticBezierTo(size.width * 0.45, size.height * 0.3, size.width * 0.52, size.height * 0.25);
    path.moveTo(size.width * 0.65, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.55, size.height * 0.3, size.width * 0.52, size.height * 0.25);
    canvas.drawPath(path, stemPaint);
  }

  void _drawPlum(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.deepPurple[700]!..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(size.width * 0.2, size.height * 0.25, size.width * 0.6, size.height * 0.55), paint);
  }

  void _drawPeach(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.orange[300]!..style = PaintingStyle.fill;
    // double circle to simulate heart-like peach shape
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.55), size.width * 0.28, paint);
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.55), size.width * 0.28, paint);
    // leaf
    final leafPaint = Paint()..color = Colors.green..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(size.width * 0.45, size.height * 0.15, size.width * 0.2, size.height * 0.12), leafPaint);
  }

  void _drawCantaloupe(Canvas canvas, Size size) {
    final shellPaint = Paint()..color = Colors.orange[200]!..style = PaintingStyle.fill;
    final rindPaint = Paint()..color = Colors.green[300]!..style = PaintingStyle.fill;

    // outer half rind
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.2, size.width * 0.7, size.height * 0.6),
      0, 3.1415, true, rindPaint
    );
    // inner flesh
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.22, size.width * 0.6, size.height * 0.54),
      0, 3.1415, true, shellPaint
    );
  }

  void _drawNectarine(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.55), size.width * 0.32, paint);
    // yellow highlight side
    final yellowPaint = Paint()..color = Colors.yellow[600]!..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(size.width * 0.5, size.height * 0.35, size.width * 0.22, size.height * 0.35), yellowPaint);
  }

  void _drawPear(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.lightGreen[400]!..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.2);
    path.cubicTo(
      size.width * 0.35, size.height * 0.3,
      size.width * 0.22, size.height * 0.6,
      size.width * 0.22, size.height * 0.75
    );
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.88,
      size.width * 0.5, size.height * 0.88
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.88,
      size.width * 0.78, size.height * 0.75
    );
    path.cubicTo(
      size.width * 0.78, size.height * 0.6,
      size.width * 0.65, size.height * 0.3,
      size.width * 0.5, size.height * 0.2
    );
    canvas.drawPath(path, paint);
  }

  void _drawBanana(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.85,
      size.width * 0.8,
      size.height * 0.35,
    );
    canvas.drawPath(path, paint);
  }

  void _drawWatermelon(Canvas canvas, Size size) {
    final rindPaint = Paint()..color = Colors.green[800]!..style = PaintingStyle.fill;
    final fleshPaint = Paint()..color = Colors.red[600]!..style = PaintingStyle.fill;
    final seedPaint = Paint()..color = Colors.black87..style = PaintingStyle.fill;

    // Rind slice
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.2, size.width * 0.8, size.height * 0.6),
      0, 3.1415, true, rindPaint
    );
    // Red flesh
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.16, size.height * 0.2, size.width * 0.68, size.height * 0.54),
      0, 3.1415, true, fleshPaint
    );

    // Seeds
    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.5), 1.5, seedPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.6), 1.5, seedPaint);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.5), 1.5, seedPaint);
  }

  void _drawGarlic(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey[200]!..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.grey[400]!..style = PaintingStyle.stroke..strokeWidth = 1.0;

    canvas.drawOval(Rect.fromLTWH(size.width * 0.25, size.height * 0.35, size.width * 0.5, size.height * 0.45), paint);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.25, size.height * 0.35, size.width * 0.5, size.height * 0.45), borderPaint);

    // Draw vertical section lines
    canvas.drawLine(Offset(size.width * 0.4, size.height * 0.35), Offset(size.width * 0.4, size.height * 0.8), borderPaint);
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.35), Offset(size.width * 0.5, size.height * 0.8), borderPaint);
    canvas.drawLine(Offset(size.width * 0.6, size.height * 0.35), Offset(size.width * 0.6, size.height * 0.8), borderPaint);
  }

  void _drawEggplant(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.purple[900]!..style = PaintingStyle.fill;
    final capPaint = Paint()..color = Colors.green..style = PaintingStyle.fill;

    // Eggplant body
    final path = Path();
    path.moveTo(size.width * 0.45, size.height * 0.25);
    path.cubicTo(
      size.width * 0.3, size.height * 0.35,
      size.width * 0.2, size.height * 0.65,
      size.width * 0.4, size.height * 0.85
    );
    path.cubicTo(
      size.width * 0.8, size.height * 0.85,
      size.width * 0.7, size.height * 0.35,
      size.width * 0.55, size.height * 0.25
    );
    canvas.drawPath(path, paint);

    // Cap
    final capPath = Path();
    capPath.moveTo(size.width * 0.4, size.height * 0.24);
    capPath.lineTo(size.width * 0.5, size.height * 0.15);
    capPath.lineTo(size.width * 0.6, size.height * 0.24);
    capPath.lineTo(size.width * 0.5, size.height * 0.32);
    capPath.close();
    canvas.drawPath(capPath, capPaint);
  }

  void _drawCucumber(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green[700]!..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(size.width * 0.2, size.height * 0.35, size.width * 0.6, size.height * 0.3), paint);
  }

  void _drawOnion(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.purple[400]!..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.purple[700]!..style = PaintingStyle.stroke..strokeWidth = 1.0;

    canvas.drawOval(Rect.fromLTWH(size.width * 0.25, size.height * 0.32, size.width * 0.5, size.height * 0.5), paint);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.25, size.height * 0.32, size.width * 0.5, size.height * 0.5), borderPaint);

    // Root stem at bottom
    final rootPaint = Paint()..color = Colors.amber[100]!..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.45, size.height * 0.8, size.width * 0.1, size.height * 0.05), rootPaint);
  }

  void _drawLettuce(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.lightGreen..style = PaintingStyle.fill;
    // draw a bunch of overlapping circles to look like leafy greens
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.55), size.width * 0.2, paint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.55), size.width * 0.2, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.42), size.width * 0.22, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.68), size.width * 0.22, paint);
  }

  void _drawPepper(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.red[500]!..style = PaintingStyle.fill;
    final stemPaint = Paint()..color = Colors.green..style = PaintingStyle.fill;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.3, size.width * 0.5, size.height * 0.55),
        const Radius.circular(10),
      ),
      paint,
    );
    // Stem
    canvas.drawRect(Rect.fromLTWH(size.width * 0.46, size.height * 0.2, size.width * 0.08, size.height * 0.12), stemPaint);
  }

  void _drawLeek(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green[400]!..style = PaintingStyle.fill;
    final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

    // Green stalk top
    canvas.drawRect(Rect.fromLTWH(size.width * 0.4, size.height * 0.2, size.width * 0.2, size.height * 0.4), paint);
    // White stem bottom
    canvas.drawRect(Rect.fromLTWH(size.width * 0.4, size.height * 0.6, size.width * 0.2, size.height * 0.25), whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}