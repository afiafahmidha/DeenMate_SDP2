import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool agreedToTerms = false;

  String selectedFiqh = 'Hanafi';
  String selectedLanguage = 'English';

  final List<String> fiqhOptions = ['Hanafi', "Shafi'i", 'Maliki', 'Hanbali'];

  // Sparkling Stars placement for Registration Header
  final List<StarConfig> _headerStars = [
    StarConfig(top: 60, left: 50, size: 8, delayMs: 200),
    StarConfig(top: 120, left: 75, size: 6, delayMs: 600),
    StarConfig(top: 75, left: 320, size: 10, delayMs: 400),
    StarConfig(top: 140, left: 300, size: 7, delayMs: 800),
    StarConfig(top: 90, left: 190, size: 11, delayMs: 300),
  ];

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Create Your Account',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Join DeenMate to manage your worship, Islamic\nwealth, and daily spiritual journey.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.navyBlue.withValues(alpha: 0.75),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildLabeledField(
                        label: 'Full Name',
                        controller: nameController,
                        icon: Icons.account_circle_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Email Address',
                        controller: emailController,
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Phone Number',
                        controller: phoneController,
                        icon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Password',
                        controller: passwordController,
                        icon: Icons.lock_outlined,
                        obscureText: obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.placeholder,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Confirm Password',
                        controller: confirmPasswordController,
                        icon: Icons.lock_reset_rounded,
                        obscureText: obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.placeholder,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() =>
                                obscureConfirmPassword = !obscureConfirmPassword);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildFiqhDropdown(),
                      const SizedBox(height: 24),
                      _buildLanguageSelector(),
                      const SizedBox(height: 20),
                      _buildTermsCheckbox(),
                      const SizedBox(height: 24),
                      _buildCreateAccountButton(),
                      const SizedBox(height: 20),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      _buildGoogleButton(),
                      const SizedBox(height: 24),
                      _buildLoginText(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== CUSTOM VECTOR HEADER WITH LOGO, SPARKLING STARS & ANIMATED LANTERNS =====
  Widget _buildHeader(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxAppWidth = 430.0;
    final double appWidth = math.min(size.width, maxAppWidth);

    return SizedBox(
      height: 275,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Stateful animated header widget to drive continuous swinging
          const Positioned.fill(
            child: RegistrationHeader(),
          ),
          // Sparkling Stars over the header
          ..._headerStars.map((star) {
            return TwinklingStar(
              top: star.top,
              left: (star.left / maxAppWidth) * appWidth,
              size: star.size,
              delayMs: star.delayMs,
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 55),
            child: Column(
              children: [
                const AppLogo(size: 64),
                const SizedBox(height: 12),
                Text(
                  'DeenMate',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyBlue,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your AI-Powered Islamic Lifestyle Companion',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== LABELED FLOATING FIELD WITH DESIGNER ICONS & CLEAN FLOATING INPUT =====
  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: AppColors.navyBlue, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: AppColors.placeholder,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          color: AppColors.navyBlue,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        // Premium prefix icon backing (soft blue-teal circle)
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              color: AppColors.dustyBlueTeal.withValues(alpha: 0.1), // Soft blue-teal circle background
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.navyBlue, size: 16),
          ),
        ),
        suffixIcon: suffixIcon,
        // No hintText is set so that the input interior remains completely empty/blank when label hovers to the top
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        alignLabelWithHint: true,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dustyBlueTeal, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dustyBlueTeal.withValues(alpha: 0.3), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navyBlue, width: 1.5),
        ),
      ),
    );
  }

  // ===== FIQH DROPDOWN (Blue-Teal/Navy accents) =====
  Widget _buildFiqhDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Fiqh (Madhhab)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navyBlue,
              ),
            ),
            const Icon(Icons.info_outline, color: AppColors.placeholder, size: 16),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.3), width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.navyBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.balance, color: AppColors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFiqh,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.placeholder),
                    style: GoogleFonts.poppins(
                      color: AppColors.navyBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: fiqhOptions.map((fiqh) {
                      return DropdownMenuItem(value: fiqh, child: Text(fiqh));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedFiqh = value!);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Used for personalized Islamic rulings.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
        ),
      ],
    );
  }

  // ===== LANGUAGE RADIO =====
  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.language, color: AppColors.midTeal, size: 18),
            const SizedBox(width: 8),
            Text(
              'Preferred Language',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navyBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 26),
            _buildLanguageOption('English'),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 26),
            _buildLanguageOption('বাংলা'),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageOption(String lang) {
    final bool isSelected = selectedLanguage == lang;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => setState(() => selectedLanguage = lang),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.navyBlue, width: 1.5),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.navyBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(lang, style: GoogleFonts.inter(color: AppColors.navyBlue, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ===== TERMS CHECKBOX =====
  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: agreedToTerms,
            activeColor: AppColors.navyBlue,
            checkColor: AppColors.white,
            side: const BorderSide(color: AppColors.dustyBlueTeal, width: 1.5),
            onChanged: (value) => setState(() => agreedToTerms = value!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.navyBlue),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Privacy Policy',
                  style: GoogleFonts.inter(
                    color: AppColors.midTeal,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // TODO: navigate to Terms page
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== CREATE ACCOUNT BUTTON (Navy with white text) =====
  Widget _buildCreateAccountButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate() && agreedToTerms) {
            // TODO: handle registration logic
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Create Account',
              style: GoogleFonts.poppins(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: AppColors.white, size: 18),
          ],
        ),
      ),
    );
  }

  // ===== DIVIDER =====
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.placeholder.withValues(alpha: 0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR',
              style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: AppColors.placeholder.withValues(alpha: 0.3))),
      ],
    );
  }

  // ===== GOOGLE BUTTON =====
  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () {
          // TODO: handle Google sign-in
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.dustyBlueTeal, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navyBlue,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(color: AppColors.navyBlue, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BOTTOM LOGIN TEXT =====
  Widget _buildLoginText() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.navyBlue),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Login',
              style: GoogleFonts.inter(
                color: AppColors.midTeal,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // TODO: navigate to Login page
                },
            ),
          ],
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