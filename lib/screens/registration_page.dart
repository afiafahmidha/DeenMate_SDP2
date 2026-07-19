import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart';

class RegistrationPage extends StatefulWidget {
  final VoidCallback onShowLogin;
  final VoidCallback onRegisterSuccess;

  const RegistrationPage({
    super.key,
    required this.onShowLogin,
    required this.onRegisterSuccess,
  });

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
      body: Stack(
        children: [
          // Pinned still header image/vector
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 275,
            child: _buildHeader(context),
          ),
          // Scrollable form container
          Positioned.fill(
            top: 247, // 275 header height - 28 overlap offset
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
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
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.35), width: 1.0),
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
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: Colors.white,
                    elevation: 4,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.placeholder, size: 20),
                    style: GoogleFonts.poppins(
                      color: AppColors.navyBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: fiqhOptions.map((fiqh) {
                      return DropdownMenuItem(
                        value: fiqh,
                        child: Text(
                          fiqh,
                          style: GoogleFonts.poppins(
                            color: AppColors.navyBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
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
            widget.onRegisterSuccess();
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
                ..onTap = widget.onShowLogin,
            ),
          ],
        ),
      ),
    );
  }
}