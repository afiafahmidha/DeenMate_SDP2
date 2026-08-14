import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/auth_header.dart';
import '../l10n/app_localizations.dart';
import 'about_screen.dart';

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
  bool _isLoading = false;

  String selectedLanguage = 'English';

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

  // ============================================================
  // 🔥 FIREBASE EMAIL/PASSWORD REGISTRATION
  // ============================================================
Future<void> _registerWithEmailAndPassword() async {
  if (_isLoading) return;

  // Validate passwords match
  if (passwordController.text != confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.tr('passwords_do_not_match'),
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    // 1. Create Firebase Authentication account
    final userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    final user = userCredential.user;

    if (user == null) {
      throw Exception('User creation failed.');
    }

    // 2. Update Firebase Auth display name
    final fullName = nameController.text.trim();

    await user.updateDisplayName(fullName);

    // 3. Create user's profile in Cloud Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('profile')
        .doc('data')
        .set({
      'fullName': fullName,
      'email': emailController.text.trim(),
      'phone': null,
      'address': null,
      'avatarPath': null,
      'language': 'en',
      'darkMode': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4. Send email verification
    await user.sendEmailVerification();

    // 5. Go to email verification screen
    if (mounted) {
      widget.onRegisterSuccess();
    }
  } on FirebaseAuthException catch (e) {
    String message =
        AppLocalizations.of(context)!.tr('registration_failed');

    switch (e.code) {
      case 'email-already-in-use':
        message =
            AppLocalizations.of(context)!.tr('email_already_in_use');
        break;

      case 'invalid-email':
        message =
            AppLocalizations.of(context)!.tr('invalid_email');
        break;

      case 'weak-password':
        message =
            AppLocalizations.of(context)!.tr('password_too_weak');
        break;

      default:
        message = e.message ??
            '${AppLocalizations.of(context)!.tr('registration_failed')}.';
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tr('unexpected_error'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  // ============================================================
  // 🔥 FIREBASE GOOGLE SIGN-IN (for Registration)
  // ============================================================
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        widget.onRegisterSuccess();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Text(e.message ?? AppLocalizations.of(context)!.tr('google_sign_in_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 500;

    final Widget contentStack = Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 275,
          child: _buildHeader(context),
        ),
        Positioned.fill(
          top: 247,
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
                      AppLocalizations.of(context)!.tr('create_account'),
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
                      AppLocalizations.of(context)!.tr('register_welcome'),
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
                      label: AppLocalizations.of(context)!.tr('full_name'),
                      controller: nameController,
                      icon: Icons.account_circle_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.tr('please_enter_full_name');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: AppLocalizations.of(context)!.tr('email_address'),
                      controller: emailController,
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.tr('please_enter_email');
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return AppLocalizations.of(context)!.tr('valid_email');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: AppLocalizations.of(context)!.tr('phone_number'),
                      controller: phoneController,
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.tr('please_enter_phone');
                        }
                        if (value.trim().length < 10) {
                          return AppLocalizations.of(context)!.tr('valid_phone');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: AppLocalizations.of(context)!.tr('password'),
                      controller: passwordController,
                      icon: Icons.lock_outlined,
                      obscureText: obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.tr('please_enter_password');
                        }
                        if (value.length < 6) {
                          return AppLocalizations.of(context)!.tr('password_too_short');
                        }
                        return null;
                      },
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
                      label: AppLocalizations.of(context)!.tr('confirm_password'),
                      controller: confirmPasswordController,
                      icon: Icons.lock_reset_rounded,
                      obscureText: obscureConfirmPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.tr('please_confirm_password');
                        }
                        if (value != passwordController.text) {
                          return AppLocalizations.of(context)!.tr('passwords_do_not_match');
                        }
                        return null;
                      },
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
    );

    return Scaffold(
      backgroundColor: isWideScreen ? const Color(0xFFEFEFF4) : AppColors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: isWideScreen
                ? BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  )
                : const BoxDecoration(color: AppColors.white),
            child: contentStack,
          ),
        ),
      ),
    );
  }

  // ===== HEADER =====
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
          const Positioned.fill(
            child: RegistrationHeader(),
          ),
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
                  AppLocalizations.of(context)!.tr('app_name'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyBlue,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                   AppLocalizations.of(context)!.tr('app_subtitle'),
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

  // ===== LABELED FIELD =====
  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      enabled: !_isLoading,
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
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
              color: AppColors.dustyBlueTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.navyBlue, size: 16),
          ),
        ),
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }



  // ===== LANGUAGE SELECTOR =====
  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.language, color: AppColors.midTeal, size: 18),
            const SizedBox(width: 8),
             Text(
                AppLocalizations.of(context)!.tr('app_language'),
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
        onTap: _isLoading ? null : () => setState(() => selectedLanguage = lang),
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
            onChanged: _isLoading ? null : (value) => setState(() => agreedToTerms = value!),
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
                   text: AppLocalizations.of(context)!.tr('terms_privacy'),
                  style: GoogleFonts.inter(
                    color: AppColors.midTeal,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutScreen(isDarkMode: false),
                        ),
                      );
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
        onPressed: (_isLoading || !agreedToTerms)
            ? null
            : () {
                if (_formKey.currentState!.validate()) {
                  _registerWithEmailAndPassword();
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
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(
                    AppLocalizations.of(context)!.tr('create_account'),
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
          child: Text(AppLocalizations.of(context)!.tr('or'),
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
        onPressed: _isLoading ? null : _signInWithGoogle,
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
              AppLocalizations.of(context)!.tr('continue_with_google'),
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
              text: AppLocalizations.of(context)!.tr('login'),
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