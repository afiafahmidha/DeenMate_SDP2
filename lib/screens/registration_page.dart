import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ===== DeenMate Color Palette =====
class AppColors {
  static const teal = Color(0xFF0F6F6B);
  static const grayTeal = Color(0xFF788885);
  static const lightTeal = Color(0xFFBFE3DF);
  static const cream = Color(0xFFF6F1E9);
  static const navy = Color(0xFF1E3A5F);
  static const tealGray = Color(0xFF557C7A);
  static const placeholder = Color(0xFF9AA7A6);
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
      backgroundColor: AppColors.cream,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.cream,
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
                            color: AppColors.navy,
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
                            color: AppColors.tealGray,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildLabeledField(
                        label: 'Full Name',
                        controller: nameController,
                        icon: Icons.person_outline,
                        hint: 'Enter your full name',
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Email Address',
                        controller: emailController,
                        icon: Icons.mail_outline,
                        hint: 'Enter your email address',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Phone Number',
                        controller: phoneController,
                        icon: Icons.phone_outlined,
                        hint: 'Enter your phone number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Password',
                        controller: passwordController,
                        icon: Icons.lock_outline,
                        hint: 'Create a strong password',
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
                        icon: Icons.lock_outline,
                        hint: 'Confirm your password',
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
                      const SizedBox(height: 20),
                      _buildLanguageSelector(),
                      const SizedBox(height: 16),
                      _buildTermsCheckbox(),
                      const SizedBox(height: 20),
                      _buildCreateAccountButton(),
                      const SizedBox(height: 20),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      _buildGoogleButton(),
                      const SizedBox(height: 20),
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

  // ===== HEADER =====
  Widget _buildHeader() {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/images/header_art.svg',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 95),
            child: Column(
              children: [
                Text(
                  'DeenMate',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your AI-Powered Islamic\nLifestyle Companion',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.navy.withOpacity(0.75),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== LABELED FIELD (label above input, like reference) =====
  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(color: AppColors.navy, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.tealGray, size: 20),
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightTeal),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightTeal),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ===== FIQH DROPDOWN =====
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
                color: AppColors.navy,
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
            border: Border.all(color: AppColors.lightTeal),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.balance, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFiqh,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.tealGray),
                    style: GoogleFonts.poppins(
                      color: AppColors.navy,
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
            const Icon(Icons.language, color: AppColors.tealGray, size: 18),
            const SizedBox(width: 8),
            Text(
              'Preferred Language',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
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
                border: Border.all(color: AppColors.teal, width: 1.5),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(lang, style: GoogleFonts.inter(color: AppColors.navy, fontSize: 13)),
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
            activeColor: AppColors.teal,
            onChanged: (value) => setState(() => agreedToTerms = value!),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.navy),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Privacy Policy',
                  style: GoogleFonts.inter(
                    color: AppColors.teal,
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

  // ===== CREATE ACCOUNT BUTTON =====
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
          backgroundColor: AppColors.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Create Account',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  // ===== DIVIDER =====
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.grayTeal.withOpacity(0.4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR',
              style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 12)),
        ),
        Expanded(child: Divider(color: AppColors.grayTeal.withOpacity(0.4))),
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
          side: BorderSide(color: AppColors.lightTeal),
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
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(color: AppColors.navy, fontSize: 14),
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
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.navy),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Login',
              style: GoogleFonts.inter(
                color: AppColors.teal,
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