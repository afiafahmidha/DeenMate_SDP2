import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ===== DeenMate Color Palette (Pure White & Navy aligned with the image) =====
class AppColors {
  static const dustyBlueTeal = Color(0xFF84B5B4); // Card background on splash, header background
  static const navyBlue = Color(0xFF1A2E40);      // Domes, text, focused elements, primary buttons
  static const white = Colors.white;              // Page background, card backgrounds, minarets (strictly white!)
  static const midTeal = Color(0xFF459490);       // Side domes, accents
  static const coralOrange = Color(0xFFEB8A6C);   // Hanging lanterns (no gold)
  static const placeholder = Color(0xFF6B8A88);   // Unfocused input label color
}

// ===== REUSABLE APP LOGO WITH ARABIC CALLIGRAPHY =====
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 80.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.navyBlue,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.dustyBlueTeal, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'دِين',
        style: GoogleFonts.amiri(
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.15,
        ),
      ),
    );
  }
}

// ===== STATEFUL ANIMATED HEADER TO KEEP LANTERNS SWINGING =====
class RegistrationHeader extends StatefulWidget {
  const RegistrationHeader({super.key});

  @override
  State<RegistrationHeader> createState() => _RegistrationHeaderState();
}

class _RegistrationHeaderState extends State<RegistrationHeader> with SingleTickerProviderStateMixin {
  late AnimationController _swingController;

  @override
  void initState() {
    super.initState();
    _swingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _swingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _swingController,
      builder: (context, child) {
        return CustomPaint(
          painter: HeaderPainter(swingValue: _swingController.value),
        );
      },
    );
  }
}

// ===== HEADER CUSTOM PAINTER =====
class HeaderPainter extends CustomPainter {
  final double swingValue;

  HeaderPainter({required this.swingValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Background color (dustyBlueTeal)
    final bgPaint = Paint()..color = AppColors.dustyBlueTeal..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, 0, w, h), bgPaint);

    // Decorative pearls/tasbih string at the top (white)
    final pearlPaint = Paint()..color = AppColors.white.withValues(alpha: 0.45)..style = PaintingStyle.fill;
    final double beadRadius = 2.5;
    final double spacing = 10.0;
    final int count = (w / spacing).ceil();
    for (int i = 0; i <= count; i++) {
      double x = i * spacing;
      double y = 15 + 3 * math.sin((x / w) * math.pi);
      canvas.drawCircle(Offset(x, y), beadRadius, pearlPaint);
    }

    final paintTeal = Paint()..color = AppColors.midTeal..style = PaintingStyle.fill;
    final paintNavy = Paint()..color = AppColors.navyBlue..style = PaintingStyle.fill;
    final paintWhite = Paint()..color = AppColors.white..style = PaintingStyle.fill;

    // 1. Background side domes in midTeal
    _drawOnionDome(canvas, w * 0.26, h * 0.90, w * 0.12, h * 0.18, paintTeal);
    _drawOnionDome(canvas, w * 0.74, h * 0.90, w * 0.12, h * 0.18, paintTeal);

    // 2. Central dome in navyBlue
    _drawOnionDome(canvas, w * 0.5, h * 0.90, w * 0.24, h * 0.28, paintNavy);

    // 3. Connective base walls in white (merging seamlessly into the form card below)
    final wallPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90)
      ..lineTo(w, h * 0.90)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(wallPath, paintWhite);

    // 4. Minarets in white with teal caps
    _drawMinaret(canvas, w * 0.12, h, w * 0.04, h * 0.45, paintWhite, paintTeal);
    _drawMinaret(canvas, w * 0.88, h, w * 0.04, h * 0.45, paintWhite, paintTeal);

    // 5. Dynamic swinging lanterns on the sides (swinging out-of-phase)
    _drawSwingingLantern(canvas, w * 0.08, 0, 75, swingValue, 0.0);
    _drawSwingingLantern(canvas, w * 0.92, 0, 105, swingValue, 1.2);
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

    canvas.drawRect(Rect.fromLTRB(cx - colW / 2, by - height, cx + colW / 2, by), paintBody);
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height * 0.75, cx + balconyW / 2, by - height * 0.72), paintBody);
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height - 2, cx + balconyW / 2, by - height), paintBody);
    _drawOnionDome(canvas, cx, by - height - 2, width * 0.7, height * 0.12, paintCap);
  }

  void _drawSwingingLantern(Canvas canvas, double cx, double topY, double length, double swingVal, double phaseOffset) {
    final double angle = 0.07 * math.sin(swingVal * 2 * math.pi + phaseOffset);

    canvas.save();
    canvas.translate(cx, topY);
    canvas.rotate(angle);

    final framePaint = Paint()..color = AppColors.navyBlue..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final glassPaint = Paint()..color = AppColors.white.withValues(alpha: 0.7)..style = PaintingStyle.fill;
    final capPaint = Paint()..color = AppColors.coralOrange..style = PaintingStyle.fill;
    final flamePaint = Paint()..color = AppColors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)..style = PaintingStyle.fill;

    // 1. Thread line
    canvas.drawLine(Offset.zero, Offset(0, length), Paint()..color = AppColors.navyBlue.withValues(alpha: 0.5)..strokeWidth = 1.0);

    // 2. Cap
    final double capY = length;
    final capPath = Path()
      ..moveTo(-8, capY + 4)
      ..lineTo(8, capY + 4)
      ..lineTo(4, capY)
      ..lineTo(-4, capY)
      ..close();
    canvas.drawPath(capPath, capPaint);

    final navyAccentPaint = Paint()..color = AppColors.navyBlue..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(-8, capY + 4, 8, capY + 6), navyAccentPaint);

    // Hook loop
    final hookPaint = Paint()..color = AppColors.navyBlue..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCenter(center: Offset(0, capY - 3), width: 6, height: 6), math.pi, math.pi, false, hookPaint);

    // 3. Body
    final double bodyY = capY + 6;
    final double bodyH = 20.0;
    final double bodyW = 16.0;

    // Flame
    canvas.drawCircle(Offset(0, bodyY + bodyH / 2), 5.0, flamePaint);

    // Glass fill
    final bodyPath = Path()
      ..moveTo(-5, bodyY)
      ..lineTo(5, bodyY)
      ..lineTo(bodyW / 2, bodyY + bodyH * 0.4)
      ..lineTo(4, bodyY + bodyH)
      ..lineTo(-4, bodyY + bodyH)
      ..lineTo(-bodyW / 2, bodyY + bodyH * 0.4)
      ..close();
    canvas.drawPath(bodyPath, glassPaint);
    canvas.drawPath(bodyPath, framePaint);

    // Struts
    canvas.drawLine(Offset(0, bodyY), Offset(0, bodyY + bodyH), framePaint);
    canvas.drawLine(Offset(-bodyW / 2, bodyY + bodyH * 0.4), Offset(bodyW / 2, bodyY + bodyH * 0.4), framePaint);

    // 4. Bottom cap & Spire
    final double bottomY = bodyY + bodyH;
    canvas.drawRect(Rect.fromLTRB(-5, bottomY, 5, bottomY + 2), navyAccentPaint);

    final bottomCapPath = Path()
      ..moveTo(-5, bottomY + 2)
      ..lineTo(5, bottomY + 2)
      ..lineTo(0, bottomY + 7)
      ..close();
    canvas.drawPath(bottomCapPath, capPaint);

    // Spire
    final spirePaint = Paint()..color = AppColors.navyBlue..strokeWidth = 1.2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, bottomY + 7), Offset(0, bottomY + 13), spirePaint);
    canvas.drawCircle(Offset(0, bottomY + 13), 1.0, navyAccentPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Always repaint to animate
}

// Configuration for stars
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

// Sparkling Star Widget (animates both scale and opacity for a true twinkle effect)
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
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacity = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.4, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: FourPointStarPainter(),
              ),
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
      ..color = AppColors.white.withValues(alpha: 0.8) // Sparkling white stars
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
    canvas.drawCircle(Offset(cx, cy), size.width * 0.15, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
