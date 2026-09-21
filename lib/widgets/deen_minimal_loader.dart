import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_service.dart';
import 'auth_header.dart'; // For AppColors

/// An aesthetically captivating, minimal Islamic loading indicator.
/// Features the signature Arabic 'دِين' calligraphy emblem, surrounded by a
/// subtle astrolabe celestial track and a smooth light-blue/white sweeping arc.
///
/// Designed cleanly with NO bulky container box or flashy colors.
class DeenMinimalLoader extends StatefulWidget {
  /// Diameter of the loader (e.g. 32 for inline, 56 for standard, 84 for hero)
  final double size;

  /// Stroke width of the orbital hairline (default: proportional to size)
  final double? strokeWidth;

  /// Whether to render the signature Arabic 'دِين' calligraphy emblem in the center (default: true)
  final bool useArabicDeenEmblem;

  /// Whether to render the celestial crescent and star in the center (only if useArabicDeenEmblem is false)
  final bool showCrescent;

  /// Whether to render the subtle astrolabe outer tick ring
  final bool showOuterRing;

  /// Optional manual override for dark mode (defaults to auto-detecting app theme)
  final bool? isDarkMode;

  /// Optional custom primary arc color
  final Color? color;

  /// Optional custom background track color
  final Color? trackColor;

  const DeenMinimalLoader({
    super.key,
    this.size = 56.0,
    this.strokeWidth,
    this.useArabicDeenEmblem = true,
    this.showCrescent = false,
    this.showOuterRing = true,
    this.isDarkMode,
    this.color,
    this.trackColor,
  });

  @override
  State<DeenMinimalLoader> createState() => _DeenMinimalLoaderState();
}

class _DeenMinimalLoaderState extends State<DeenMinimalLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _resolveDarkMode(BuildContext context) {
    if (widget.isDarkMode != null) return widget.isDarkMode!;
    if (appThemeNotifier.value) return true;
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _resolveDarkMode(context);

    // Clean, serene palette strictly matching the app:
    // Light Dusty Blue (AppColors.dustyBlueTeal) & Pure White / Navy Blue
    final primaryArcColor = widget.color ??
        (isDark ? AppColors.dustyBlueTeal : AppColors.navyBlue);
    final secondaryArcColor = isDark ? Colors.white : AppColors.dustyBlueTeal;

    final trackColor = widget.trackColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : AppColors.dustyBlueTeal.withValues(alpha: 0.20));

    final outerRingColor = isDark
        ? AppColors.dustyBlueTeal.withValues(alpha: 0.25)
        : AppColors.dustyBlueTeal.withValues(alpha: 0.35);

    final crescentColor = isDark ? Colors.white : AppColors.navyBlue;
    final starColor = isDark ? Colors.white : AppColors.dustyBlueTeal;

    final stroke = widget.strokeWidth ?? (widget.size * 0.036).clamp(1.5, 3.2);
    final emblemColor = isDark ? Colors.white : AppColors.navyBlue;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CelestialIslamicLoaderPainter(
                  progress: _controller.value,
                  trackColor: trackColor,
                  outerRingColor: outerRingColor,
                  primaryColor: primaryArcColor,
                  secondaryColor: secondaryArcColor,
                  crescentColor: crescentColor,
                  starColor: starColor,
                  strokeWidth: stroke,
                  showCrescent: !widget.useArabicDeenEmblem && widget.showCrescent,
                  showOuterRing: widget.showOuterRing,
                  isDark: isDark,
                ),
              );
            },
          ),
          if (widget.useArabicDeenEmblem && widget.size >= 24)
            Padding(
              padding: EdgeInsets.only(bottom: widget.size * 0.05),
              child: Text(
                'دِين',
                textAlign: TextAlign.center,
                style: GoogleFonts.amiri(
                  fontSize: widget.size * 0.38,
                  fontWeight: FontWeight.bold,
                  color: emblemColor,
                  height: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the celestial Islamic loader
class _CelestialIslamicLoaderPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color outerRingColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color crescentColor;
  final Color starColor;
  final double strokeWidth;
  final bool showCrescent;
  final bool showOuterRing;
  final bool isDark;

  _CelestialIslamicLoaderPainter({
    required this.progress,
    required this.trackColor,
    required this.outerRingColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.crescentColor,
    required this.starColor,
    required this.strokeWidth,
    required this.showCrescent,
    required this.showOuterRing,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2;
    final mainRadius = outerRadius - strokeWidth * 2.8;

    if (mainRadius <= 0) return;

    // 1. Subtle Outer Astrolabe Accents (Delicate 8-point tick marks)
    if (showOuterRing && mainRadius > 18) {
      final tickRadius = outerRadius - strokeWidth * 0.8;
      final tickPaint = Paint()
        ..color = outerRingColor
        ..strokeWidth = strokeWidth * 0.55
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      // 8 delicate celestial tick marks representing the 8 directions/Rub el Hizb
      for (int i = 0; i < 8; i++) {
        final angle = (i * math.pi / 4);
        final p1 = Offset(
          center.dx + (tickRadius - strokeWidth * 1.6) * math.cos(angle),
          center.dy + (tickRadius - strokeWidth * 1.6) * math.sin(angle),
        );
        final p2 = Offset(
          center.dx + tickRadius * math.cos(angle),
          center.dy + tickRadius * math.sin(angle),
        );
        canvas.drawLine(p1, p2, tickPaint);
      }

      // Faint outer hairline boundary ring
      final outerRingPaint = Paint()
        ..color = outerRingColor.withValues(alpha: outerRingColor.a * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.5
        ..isAntiAlias = true;
      canvas.drawCircle(center, tickRadius, outerRingPaint);
    }

    // 2. Faint Main Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85
      ..isAntiAlias = true;
    canvas.drawCircle(center, mainRadius, trackPaint);

    // 3. Silky Non-Linear Sweeping Arc (Fading light blue / white)
    final rotation = progress * 2 * math.pi;
    final arcSpan = (0.50 + 0.18 * math.sin(progress * 2 * math.pi)) * math.pi;
    final startAngle = rotation - arcSpan;

    final rect = Rect.fromCircle(center: center, radius: mainRadius);
    final sweepGradient = SweepGradient(
      startAngle: 0.0,
      endAngle: arcSpan,
      colors: [
        primaryColor.withValues(alpha: 0.0),
        primaryColor.withValues(alpha: 0.45),
        secondaryColor,
      ],
      stops: const [0.0, 0.45, 1.0],
      transform: GradientRotation(startAngle),
    );

    final arcPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(rect, startAngle, arcSpan, false, arcPaint);

    // 4. Clean Star Dot at Arc Tip (No flashy color, clean light blue / white)
    final tipAngle = startAngle + arcSpan;
    final tip = Offset(
      center.dx + mainRadius * math.cos(tipAngle),
      center.dy + mainRadius * math.sin(tipAngle),
    );

    final starDotPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(tip, strokeWidth * 1.15, starDotPaint);

    // 5. Stationary Minimal Crescent in Center (if enabled)
    if (showCrescent && mainRadius > 14) {
      _drawCrescentAndStar(canvas, center, mainRadius * 0.45, strokeWidth * 0.95);
    }
  }

  void _drawCrescentAndStar(Canvas canvas, Offset center, double cRadius, double stroke) {
    final crescentPaint = Paint()
      ..color = crescentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();
    final outerRect = Rect.fromCircle(center: center, radius: cRadius);
    path.addArc(outerRect, -math.pi * 0.65, math.pi * 1.3);

    final startPt = Offset(
      center.dx + cRadius * math.cos(-math.pi * 0.65),
      center.dy + cRadius * math.sin(-math.pi * 0.65),
    );
    final controlPt = Offset(center.dx + cRadius * 0.25, center.dy);
    path.quadraticBezierTo(controlPt.dx, controlPt.dy, startPt.dx, startPt.dy);

    canvas.drawPath(path, crescentPaint);

    final starCenter = Offset(center.dx + cRadius * 0.38, center.dy - cRadius * 0.12);
    final starSize = stroke * 1.4;

    final starPath = Path();
    for (int i = 0; i < 8; i++) {
      final r = (i % 2 == 0) ? starSize : starSize * 0.52;
      final a = i * math.pi / 4 - math.pi / 8;
      final x = starCenter.dx + r * math.cos(a);
      final y = starCenter.dy + r * math.sin(a);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    final starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant _CelestialIslamicLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// A clean, borderless loading presentation with NO container box.
/// Floats seamlessly directly on the screen background.
class DeenMinimalLoadingCard extends StatefulWidget {
  final String? message;
  final double loaderSize;
  final bool? isDarkMode;
  final bool showBrandTitle;

  const DeenMinimalLoadingCard({
    super.key,
    this.message,
    this.loaderSize = 60.0,
    this.isDarkMode,
    this.showBrandTitle = true,
  });

  @override
  State<DeenMinimalLoadingCard> createState() => _DeenMinimalLoadingCardState();
}

class _DeenMinimalLoadingCardState extends State<DeenMinimalLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  bool _resolveDarkMode(BuildContext context) {
    if (widget.isDarkMode != null) return widget.isDarkMode!;
    if (appThemeNotifier.value) return true;
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _resolveDarkMode(context);

    // Clean, borderless typography
    // 'DeenMate' title color (Navy Blue in bright mode, Pure White in dark mode)
    final brandTitleColor = isDark ? Colors.white : AppColors.navyBlue;

    // Subtitle text color
    final subtitleColor = isDark
        ? Colors.white70
        : AppColors.placeholder;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Celestial Loader (with signature 'دِين' emblem)
        DeenMinimalLoader(
          size: widget.loaderSize,
          isDarkMode: isDark,
        ),

        if (widget.showBrandTitle) ...[
          const SizedBox(height: 18),
          // 'DeenMate' in signature splash screen Playfair Display
          Text(
            'DeenMate',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: brandTitleColor,
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Animated "LOADING . . ." or custom message
        AnimatedBuilder(
          animation: _dotsController,
          builder: (context, child) {
            final dotCount = ((_dotsController.value * 3).floor() % 3) + 1;
            final dots = '.' * dotCount;
            final displayText = widget.message != null && widget.message!.isNotEmpty
                ? widget.message!.toUpperCase()
                : 'LOADING $dots';

            return Text(
              displayText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.2,
                color: subtitleColor,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Fullscreen loading screen with serene atmosphere and branded typography
class DeenMinimalLoadingScreen extends StatelessWidget {
  final String? message;
  final bool? isDarkMode;
  final bool showBrandTitle;

  const DeenMinimalLoadingScreen({
    super.key,
    this.message,
    this.isDarkMode,
    this.showBrandTitle = true,
  });

  bool _resolveDarkMode(BuildContext context) {
    if (isDarkMode != null) return isDarkMode!;
    if (appThemeNotifier.value) return true;
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _resolveDarkMode(context);
    final bg = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: DeenMinimalLoadingCard(
          message: message,
          loaderSize: 68.0,
          isDarkMode: isDark,
          showBrandTitle: showBrandTitle,
        ),
      ),
    );
  }
}

/// Static helper to trigger aesthetic minimal loading overlay easily from anywhere
class DeenLoading {
  static OverlayEntry? _overlayEntry;

  /// Shows the branded aesthetic loading overlay over the entire screen
  static void show(
    BuildContext context, {
    String? message,
    bool showBrandTitle = true,
    bool? isDarkMode,
  }) {
    if (_overlayEntry != null) return; // already showing

    final overlayState = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Soft ambient dimmed backdrop
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: DeenMinimalLoadingCard(
                message: message,
                loaderSize: 64.0,
                isDarkMode: isDarkMode,
                showBrandTitle: showBrandTitle,
              ),
            ),
          ),
        ],
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  /// Hides the aesthetic loading overlay
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
