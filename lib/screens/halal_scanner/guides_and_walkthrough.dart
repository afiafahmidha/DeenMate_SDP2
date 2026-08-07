import 'package:flutter/material.dart';

const tealColor = Color(0xFF55A498);

// Keeps the screen phone-width on desktop/web (Chrome) by centering it on a
// grey backdrop, same trick used elsewhere in the app (e.g. QurbaniPlannerPage).
// On an actual Android device the screen width is already <= 430, so this
// has no visible effect there — it only kicks in on wide desktop windows.
class MobileFrame extends StatelessWidget {
  final Widget child;
  final bool isDarkMode;
  const MobileFrame({super.key, required this.child, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDarkMode ? const Color(0xFF0F1216) : const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child,
        ),
      ),
    );
  }
}

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
        backgroundColor: tealColor,
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
                iconBuilder: (item) => const _GaugeIcon(),
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
                iconBuilder: (item) => Text(item.emoji!, style: const TextStyle(fontSize: 30)),
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
    required Widget Function(_GuideGridItem item) iconBuilder,
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
        children: items.map((item) {
          return SizedBox(
            width: MediaQuery.of(context).size.width / 2 - 30,
            child: Row(
              children: [
                SizedBox(width: 44, height: 44, child: Center(child: iconBuilder(item))),
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
// Deliberately the SAME icon for every level (matching the reference design,
// which reuses one generic rainbow gauge glyph for every row).
class _GaugeIcon extends StatelessWidget {
  const _GaugeIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 24),
      painter: _GaugePainter(),
    );
  }
}

class _GaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    const gradientColors = [
      Color(0xFFE84A3D),
      Color(0xFFEF8C1F),
      Color(0xFFF4C430),
      Color(0xFF9FCB3C),
      Color(0xFF4CAF50),
    ];
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: gradientColors,
        startAngle: 3.1416,
        endAngle: 3.1416 * 2,
        center: Alignment.center,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 3.1416, 3.1416, false, arcPaint);

    final needlePaint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height);
    canvas.drawLine(center, Offset(size.width * 0.72, size.height * 0.35), needlePaint);
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.grey[800]!);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(4)), Paint()..color = const Color(0xFF55A498));

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
    canvas.drawRect(labelRect, Paint()..color = const Color(0xFF55A498));
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
      Paint()..color = const Color(0xFF55A498),
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
      Paint()..color = const Color(0xFF55A498),
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
      Paint()..color = const Color(0xFF55A498),
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