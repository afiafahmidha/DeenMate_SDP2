import 'dart:async';
import 'package:flutter/material.dart';
import 'halal_drawer.dart';
import 'halal_scanner_home.dart';

class GuidesAndWalkthroughScreen extends StatefulWidget {
  const GuidesAndWalkthroughScreen({super.key});

  @override
  State<GuidesAndWalkthroughScreen> createState() => _GuidesAndWalkthroughScreenState();
}

class _GuidesAndWalkthroughScreenState extends State<GuidesAndWalkthroughScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9FA),
      drawer: const HalalDrawer(activeRoute: 'Guide'),
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
          padding: const EdgeInsets.all(16.0),
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
                      builder: (context) => const WalkthroughCarousel(initialPage: 0),
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
                      builder: (context) => const WalkthroughCarousel(initialPage: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildGuideLinkButton(
                icon: Icons.tune_rounded,
                label: 'HOW CAN I CONFIGURE AN ADDITIVE STATUS?',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WalkthroughCarousel(initialPage: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              const Text(
                'What is Halal?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildArticleBox(
                text: 'Term that encompasses everything that is allowed, and therefore is beneficial and healthy for humans, promoting improved quality of life and reducing health risks.\n\nIt could be translated as authorized, recommended, healthy, ethical or not abusive.\n\nMuslims understand the term Halal, as a lifestyle, a global and comprehensive concept that influences and affects everyday issues, such as food, hygiene, health, economy, fashion, commerce and tourism.',
              ),
              const SizedBox(height: 20),

              const Text(
                'What is Haram?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildArticleBox(
                text: 'Term that refers to anything that is prohibited, not allowed, it is harmful or abusive. Are considered Haram, according to Islamic rules:\n- Pork, blood, animals slaughtered without invoking the name of God.\n- Carnivorous animals and birds of prey.\n- Alcohol, intoxicants, and harmful chemicals.\n- Additives derived from non-halal animal sources.',
              ),
            ],
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
    const tealColor = Color(0xFF55A498);
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

// Swipeable Walkthrough Onboarding Carousel
class WalkthroughCarousel extends StatefulWidget {
  final int initialPage;
  const WalkthroughCarousel({super.key, this.initialPage = 0});

  @override
  State<WalkthroughCarousel> createState() => _WalkthroughCarouselState();
}

class _WalkthroughCarouselState extends State<WalkthroughCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Scaffold(
      backgroundColor: Colors.white,
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
              children: [
                // Slide 1
                _buildSlide(
                  title: 'Scan by barcode',
                  subtitle: 'Look for the barcode on the product you want to know if it is Halal.',
                  painter: BarcodeIllustrationPainter(),
                ),
                // Slide 2
                _buildSlide(
                  title: 'SEARCH INGREDIENT',
                  subtitle: 'Search the product for the ingredients part.',
                  painter: IngredientIllustrationPainter(),
                ),
                // Slide 3
                _buildSlide(
                  title: 'Customize your states in each additives',
                  subtitle: 'If you think an additive is not the correct status for you or in your country. You can change the status to Halal, Haram or Mushbooh (makruh).',
                  painter: CustomizeIllustrationPainter(),
                ),
              ],
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
                  children: List.generate(3, (index) {
                    final isSelected = _currentPage == index;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? tealColor : Colors.grey[300],
                      ),
                    );
                  }),
                ),

                // Text next / Finish
                TextButton(
                  onPressed: () {
                    if (_currentPage == 2) {
                      Navigator.pop(context);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    _currentPage == 2 ? 'FINISH' : 'NEXT',
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
    );
  }

  Widget _buildSlide({
    required String title,
    required String subtitle,
    required CustomPainter painter,
  }) {
    const tealColor = Color(0xFF55A498);
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
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Simulation/Walkthrough painters
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

// Custom Barcode Scanner Simulator screen
class BarcodeScannerSimulator extends StatefulWidget {
  final Function(ScannedProduct) onScanComplete;

  const BarcodeScannerSimulator({super.key, required this.onScanComplete});

  @override
  State<BarcodeScannerSimulator> createState() => _BarcodeScannerSimulatorState();
}

class _BarcodeScannerSimulatorState extends State<BarcodeScannerSimulator> {
  late Timer _timer;
  double _lineY = 0.2;
  bool _movingDown = true;

  final List<ScannedProduct> _scanPool = [
    ScannedProduct(
      name: 'Gelatin Gummy Bears',
      barcode: '501234567890',
      scanDate: DateTime.now(),
      status: 'HARAM',
      origin: 'animal (pork derivative)',
      risk: 'Toxic',
    ),
    ScannedProduct(
      name: 'Orange Carbonated Drink',
      barcode: '400123456789',
      scanDate: DateTime.now(),
      status: 'HALAL',
      origin: 'plant/chemical',
      risk: 'Safe',
    ),
    ScannedProduct(
      name: 'E471 emulsifier bakery bread',
      barcode: '300987654321',
      scanDate: DateTime.now(),
      status: 'MUSHBOOH',
      origin: 'mixed animal/plant',
      risk: 'Do not abuse',
    ),
    ScannedProduct(
      name: 'Organic Fruit Juice',
      barcode: '880123456000',
      scanDate: DateTime.now(),
      status: 'HALAL',
      origin: 'plant',
      risk: 'Safe',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Animate red scanning line
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        if (_movingDown) {
          _lineY += 0.015;
          if (_lineY >= 0.8) _movingDown = false;
        } else {
          _lineY -= 0.015;
          if (_lineY <= 0.2) _movingDown = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _triggerScan() {
    // Select random product from pool
    final randomProduct = (_scanPool..shuffle()).first;
    Navigator.pop(context);
    widget.onScanComplete(randomProduct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated camera view (dark green/blue futuristic overlay)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Color(0xFF0F2027), Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Transparent scanning window
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    // Moving red scanner line
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 30),
                      top: 260 * _lineY,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Instruction label
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Align barcode within frame',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep the phone steady to auto-focus',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),

          // Scan Trigger Button
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF55A498),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _triggerScan,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Simulate Product Detect',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}