import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: nameController,
                      icon: Icons.person_outline,
                      hint: 'Enter your full name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: emailController,
                      icon: Icons.mail_outline,
                      hint: 'Enter your email address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: phoneController,
                      icon: Icons.phone_outlined,
                      hint: 'Enter your phone number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
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
                        ),
                        onPressed: () {
                          setState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
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
          ],
        ),
      ),
    );
  }

  // ===== HEADER WITH GRADIENT + ISLAMIC DECOR =====
  Widget _buildHeader() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.teal, AppColors.lightTeal.withOpacity(0.6)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                ),
                itemCount: 30,
                itemBuilder: (context, index) => const Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
          const Positioned(
              top: 20, left: 30, child: Icon(Icons.star, color: Colors.white, size: 14)),
          const Positioned(
              top: 40, right: 40, child: Icon(Icons.star, color: Colors.white, size: 10)),
          const Positioned(
              top: 70, left: 80, child: Icon(Icons.star, color: Colors.white, size: 8)),
          const Positioned(
            top: 24,
            right: 90,
            child: Icon(Icons.nightlight_round, color: Colors.white, size: 26),
          ),
          Positioned(
            top: 0,
            left: 50,
            child: Icon(Icons.emoji_objects_outlined,
                color: Colors.white.withOpacity(0.85), size: 22),
          ),
          Positioned(
            top: 0,
            right: 60,
            child: Icon(Icons.emoji_objects_outlined,
                color: Colors.white.withOpacity(0.85), size: 22),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DeenMate',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create Your Account',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.park, color: AppColors.teal.withOpacity(0.5), size: 34),
                Icon(Icons.mosque, color: AppColors.teal.withOpacity(0.6), size: 46),
                Icon(Icons.park, color: AppColors.teal.withOpacity(0.5), size: 34),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== REUSABLE TEXT FIELD =====
  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: AppColors.navy, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.tealGray),
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
    );
  }

  // ===== FIQH DROPDOWN =====
  Widget _buildFiqhDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Fiqh (Madhhab)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightTeal),
          ),
          child: Row(
            children: [
              const Icon(Icons.balance, color: AppColors.tealGray, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFiqh,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.tealGray),
                    style: GoogleFonts.inter(color: AppColors.navy, fontSize: 14),
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

  // ===== LANGUAGE RADIO BUTTONS =====
  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.language, color: AppColors.tealGray, size: 20),
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
        Row(
          children: [
            _buildLanguageOption('English'),
            const SizedBox(width: 20),
            _buildLanguageOption('বাংলা'),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageOption(String lang) {
    final bool isSelected = selectedLanguage == lang;
    return GestureDetector(
      onTap: () => setState(() => selectedLanguage = lang),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.teal, width: 1.5),
              color: isSelected ? AppColors.teal : Colors.transparent,
            ),
            child: isSelected
                ? const Icon(Icons.circle, color: Colors.white, size: 8)
                : null,
          ),
          const SizedBox(width: 6),
          Text(lang, style: GoogleFonts.inter(color: AppColors.navy, fontSize: 13)),
        ],
      ),
    );
  }

  // ===== TERMS CHECKBOX =====
  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: agreedToTerms,
          activeColor: AppColors.teal,
          onChanged: (value) => setState(() => agreedToTerms = value!),
        ),
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
                    decoration: TextDecoration.underline,
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
    return ElevatedButton(
      onPressed: () {
        if (_formKey.currentState!.validate() && agreedToTerms) {
          // TODO: handle registration logic
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
    return OutlinedButton(
      onPressed: () {
        // TODO: handle Google sign-in
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: AppColors.lightTeal),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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