import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // To access AppColors

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _swingController;

  // Choreographed animations
  late Animation<double> _bgOpacity;
  late Animation<double> _lanternSlideDown;
  late Animation<double> _mosqueSlideUp;
  late Animation<double> _logoScale;
  late Animation<double> _textFadeIn;
  late Animation<double> _subtitleFadeIn;
  late Animation<double> _exitFadeOut;

  // Stars configuration
  final List<StarConfig> _stars = [
    StarConfig(top: 80, left: 60, size: 10, delayMs: 200),
    StarConfig(top: 130, left: 100, size: 8, delayMs: 600),
    StarConfig(top: 90, left: 280, size: 12, delayMs: 400),
    StarConfig(top: 160, left: 320, size: 9, delayMs: 800),
    StarConfig(top: 220, left: 70, size: 11, delayMs: 100),
    StarConfig(top: 250, left: 300, size: 7, delayMs: 700),
    StarConfig(top: 70, left: 190, size: 14, delayMs: 300),
    StarConfig(top: 180, left: 170, size: 8, delayMs: 900),
  ];

  @override
  void initState() {
    super.initState();

    // 5-second main timeline
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    // Loop controller for swinging lanterns
    _swingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Timeline Choreography
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
      ),
    );

    _lanternSlideDown = Tween<double>(begin: -180.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.05, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _mosqueSlideUp = Tween<double>(begin: 260.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.18, 0.58, curve: Curves.easeOutBack),
      ),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.32, 0.65, curve: Curves.elasticOut),
      ),
    );

    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.50, 0.78, curve: Curves.easeIn),
      ),
    );

    _subtitleFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.62, 0.88, curve: Curves.easeIn),
      ),
    );

    // Exit fade-out in the last 500 milliseconds
    _exitFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.90, 1.0, curve: Curves.easeInOut),
      ),
    );

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onFinished();
        });
      }
    });

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _swingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxAppWidth = 430.0;
    final double appWidth = math.min(size.width, maxAppWidth);

    return Center(
      child: Container(
        width: appWidth,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.dustyBlueTeal,
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.15),
            width: 8.0,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_mainController, _swingController]),
          builder: (context, child) {
            return Opacity(
              opacity: _exitFadeOut.value,
              child: Stack(
                children: [
                  // 1. Subtle blue-teal geometric watermark texture background (no gold)
                  Positioned.fill(
                    child: Opacity(
                      opacity: _bgOpacity.value,
                      child: CustomPaint(
                        painter: IslamicTexturePainter(),
                      ),
                    ),
                  ),

                  // 2. Decorative Pearl string at the top (white)
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: _bgOpacity.value,
                      child: Container(
                        height: 20,
                        alignment: Alignment.topCenter,
                        child: CustomPaint(
                          size: Size(appWidth, 20),
                          painter: PearlBorderPainter(),
                        ),
                      ),
                    ),
                  ),

                  // 3. Twinkling Stars (soft white stars)
                  if (_mainController.value > 0.15)
                    ..._stars.map((star) {
                      return TwinklingStar(
                        top: star.top,
                        left: (star.left / maxAppWidth) * appWidth,
                        size: star.size,
                        delayMs: star.delayMs,
                      );
                    }),

                  // 4. Swinging Lanterns (Coral Orange caps, Navy frames, out-of-phase swings)
                  Positioned(
                    top: _lanternSlideDown.value,
                    left: appWidth * 0.12,
                    child: Transform.rotate(
                      angle: 0.08 * math.sin(_swingController.value * 2 * math.pi),
                      alignment: Alignment.topCenter,
                      child: CustomPaint(
                        size: const Size(40, 150),
                        painter: LanternPainter(stringLength: 70),
                      ),
                    ),
                  ),
                  Positioned(
                    top: _lanternSlideDown.value,
                    right: appWidth * 0.12,
                    child: Transform.rotate(
                      angle: 0.07 * math.sin(_swingController.value * 2 * math.pi + 1.2),
                      alignment: Alignment.topCenter,
                      child: CustomPaint(
                        size: const Size(40, 190),
                        painter: LanternPainter(stringLength: 100),
                      ),
                    ),
                  ),

                  // 5. Flat Vector Mosque (Drawn in layers with colors from the image, white columns)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Transform.translate(
                      offset: Offset(0, _mosqueSlideUp.value),
                      child: CustomPaint(
                        size: Size(appWidth, 230),
                        painter: MosquePainter(),
                      ),
                    ),
                  ),

                  // 6. Branding Center Layout (Calligraphy Logo + Text)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Arabic Calligraphy Logo (scales up)
                          Transform.scale(
                            scale: _logoScale.value,
                            child: const AppLogo(size: 85),
                          ),
                          const SizedBox(height: 18),
                          // Logo title: GoogleFonts.playfairDisplay (original registration logo style)
                          Opacity(
                            opacity: _textFadeIn.value,
                            child: Text(
                              'DeenMate',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navyBlue,
                                letterSpacing: 1.0,
                                shadows: [
                                  Shadow(
                                    color: AppColors.white.withValues(alpha: 0.4),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Subtitle: GoogleFonts.inter (original registration subtitle style)
                          Opacity(
                            opacity: _subtitleFadeIn.value,
                            child: Text(
                              'YOUR AI-POWERED ISLAMIC LIFESTYLE COMPANION',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navyBlue.withValues(alpha: 0.7),
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Config for static star placement
class StarConfig {
  final double top;
  final double left;
  final double size;
  final int delayMs;

  StarConfig({
    required this.top,
    required this.left,
    required this.size,
    required this.delayMs,
  });
}

// Twinkling star widget
class TwinklingStar extends StatefulWidget {
  final double top;
  final double left;
  final double size;
  final int delayMs;

  const TwinklingStar({
    super.key,
    required this.top,
    required this.left,
    required this.size,
    required this.delayMs,
  });

  @override
  State<TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<TwinklingStar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacity = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: FourPointStarPainter(),
            ),
          );
        },
      ),
    );
  }
}

class FourPointStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.75) // Soft white stars
      ..style = PaintingStyle.fill;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2;
    final ry = size.height / 2;

    path.moveTo(cx, cy - ry);
    path.quadraticBezierTo(cx, cy, cx + rx, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + ry);
    path.quadraticBezierTo(cx, cy, cx - rx, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - ry);
    path.close();

    canvas.drawPath(path, paint);

    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.12, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PearlBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final double beadRadius = 3.0;
    final double spacing = 12.0;
    final int count = (size.width / spacing).ceil();

    final linePaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 10), Offset(size.width, 10), linePaint);

    for (int i = 0; i <= count; i++) {
      double x = i * spacing;
      double y = 10 + 4 * math.sin((x / size.width) * math.pi);
      canvas.drawCircle(Offset(x, y), beadRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Flat Vector Mosque with white elements (strictly no cream/beige or gold)
class MosquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final paintNavy = Paint()..color = AppColors.navyBlue..style = PaintingStyle.fill;
    final paintWhite = Paint()..color = AppColors.white..style = PaintingStyle.fill;
    final paintMidTeal = Paint()..color = AppColors.midTeal..style = PaintingStyle.fill;

    // 1. Draw Side Domes (Teal, background)
    _drawOnionDome(canvas, w * 0.28, h * 0.65, w * 0.13, h * 0.22, paintMidTeal);
    _drawOnionDome(canvas, w * 0.72, h * 0.65, w * 0.13, h * 0.22, paintMidTeal);

    // 2. Draw Center Dome (Navy Blue)
    _drawOnionDome(canvas, w * 0.5, h * 0.63, w * 0.28, h * 0.38, paintNavy);
    
    // Spire on center dome (Navy)
    final spirePaint = Paint()
      ..color = AppColors.navyBlue
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.5, h * 0.25), Offset(w * 0.5, h * 0.20), spirePaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.20), 2.0, paintNavy);

    // 3. Draw Connective Base Walls (White)
    final wallPath = Path()
      ..moveTo(w * 0.1, h)
      ..lineTo(w * 0.1, h * 0.68)
      ..lineTo(w * 0.9, h * 0.68)
      ..lineTo(w * 0.9, h)
      ..close();
    canvas.drawPath(wallPath, paintWhite);

    // 4. Draw Minarets (White columns, teal caps)
    _drawMinaret(canvas, w * 0.15, h, w * 0.05, h * 0.6, paintWhite, paintMidTeal);
    _drawMinaret(canvas, w * 0.85, h, w * 0.05, h * 0.6, paintWhite, paintMidTeal);

    // 5. Draw Ground Floor (White)
    canvas.drawRect(Rect.fromLTRB(0, h * 0.88, w, h), paintWhite);

    // 6. Draw central arched door (Navy)
    final doorPath = Path()
      ..moveTo(w * 0.45, h * 0.88)
      ..lineTo(w * 0.45, h * 0.78)
      ..quadraticBezierTo(w * 0.5, h * 0.73, w * 0.55, h * 0.78)
      ..lineTo(w * 0.55, h * 0.88)
      ..close();
    canvas.drawPath(doorPath, paintNavy);
  }

  void _drawOnionDome(Canvas canvas, double cx, double by, double width, double height, Paint paint) {
    final path = Path();
    final double w2 = width / 2;
    final double bulge = width * 0.08;

    path.moveTo(cx - w2, by);
    path.cubicTo(
      cx - w2 - bulge, by - height * 0.35,
      cx - w2 + bulge * 0.2, by - height * 0.75,
      cx, by - height,
    );
    path.cubicTo(
      cx + w2 - bulge * 0.2, by - height * 0.75,
      cx + w2 + bulge, by - height * 0.35,
      cx + w2, by,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawMinaret(Canvas canvas, double cx, double by, double width, double height, Paint paintBody, Paint paintCap) {
    final double colW = width * 0.6;
    final double balconyW = width * 1.2;

    // Column body
    canvas.drawRect(Rect.fromLTRB(cx - colW / 2, by - height, cx + colW / 2, by), paintBody);
    
    // Balconies
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height * 0.75, cx + balconyW / 2, by - height * 0.72), paintBody);
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height - 3, cx + balconyW / 2, by - height), paintBody);
    
    // Onion Dome Cap
    _drawOnionDome(canvas, cx, by - height - 3, width * 0.7, height * 0.12, paintCap);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LanternPainter extends CustomPainter {
  final double stringLength;

  LanternPainter({required this.stringLength});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;

    // 1. Draw hanging thread string (Navy)
    final stringPaint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, 0), Offset(cx, stringLength), stringPaint);

    // 2. Draw Lantern Top Cap (Coral Orange)
    final double capY = stringLength;
    final capPaint = Paint()
      ..color = AppColors.coralOrange
      ..style = PaintingStyle.fill;

    final hookPaint = Paint()
      ..color = AppColors.navyBlue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, capY - 3), width: 6, height: 6),
      math.pi,
      math.pi,
      false,
      hookPaint,
    );

    final capPath = Path()
      ..moveTo(cx - 8, capY + 4)
      ..lineTo(cx + 8, capY + 4)
      ..lineTo(cx + 4, capY)
      ..lineTo(cx - 4, capY)
      ..close();
    canvas.drawPath(capPath, capPaint);

    final navyAccentPaint = Paint()
      ..color = AppColors.navyBlue
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(cx - 8, capY + 4, cx + 8, capY + 6), navyAccentPaint);

    // 3. Draw Lantern Glass Body (White with soft glow flame)
    final double bodyTopY = capY + 6;
    final double bodyHeight = 22.0;
    final double bodyWidth = 18.0;

    final flamePaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, bodyTopY + bodyHeight / 2), 5.0, flamePaint);

    final glassPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final bodyPath = Path()
      ..moveTo(cx - 5, bodyTopY)
      ..lineTo(cx + 5, bodyTopY)
      ..lineTo(cx + bodyWidth / 2, bodyTopY + bodyHeight * 0.4)
      ..lineTo(cx + 4, bodyTopY + bodyHeight)
      ..lineTo(cx - 4, bodyTopY + bodyHeight)
      ..lineTo(cx - bodyWidth / 2, bodyTopY + bodyHeight * 0.4)
      ..close();
    canvas.drawPath(bodyPath, glassPaint);

    final framePaint = Paint()
      ..color = AppColors.navyBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(bodyPath, framePaint);

    canvas.drawLine(Offset(cx, bodyTopY), Offset(cx, bodyTopY + bodyHeight), framePaint);

    canvas.drawLine(
      Offset(cx - bodyWidth / 2, bodyTopY + bodyHeight * 0.4),
      Offset(cx + bodyWidth / 2, bodyTopY + bodyHeight * 0.4),
      framePaint,
    );

    // 4. Bottom Cap (Coral Orange) & Spire
    final double bottomY = bodyTopY + bodyHeight;
    canvas.drawRect(Rect.fromLTRB(cx - 5, bottomY, cx + 5, bottomY + 2), navyAccentPaint);

    final bottomCapPath = Path()
      ..moveTo(cx - 5, bottomY + 2)
      ..lineTo(cx + 5, bottomY + 2)
      ..lineTo(cx, bottomY + 7)
      ..close();
    canvas.drawPath(bottomCapPath, capPaint);

    final spirePaint = Paint()
      ..color = AppColors.navyBlue
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, bottomY + 7), Offset(cx, bottomY + 14), spirePaint);
    canvas.drawCircle(Offset(cx, bottomY + 14), 1.0, navyAccentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Subtle Blue-Teal Geometric Watermark Pattern (Strictly no gold)
class IslamicTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dustyBlueTeal.withValues(alpha: 0.05)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final double gridWidth = 80.0;
    final int rows = (size.height / gridWidth).ceil() + 1;
    final int cols = (size.width / gridWidth).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double x = c * gridWidth;
        double y = r * gridWidth;

        // Overlay rotated squares forming Rub el Hizb octagram lines
        canvas.drawRect(Rect.fromLTWH(x - gridWidth / 2, y - gridWidth / 2, gridWidth, gridWidth), paint);

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: gridWidth, height: gridWidth), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
