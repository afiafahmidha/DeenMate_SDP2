import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/auth_header.dart';
import '../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onShowRegister;
  final VoidCallback onLoginSuccess;

  const LoginPage({
    super.key,
    required this.onShowRegister,
    required this.onLoginSuccess,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool _isLoading = false;

  // Sparkling Stars placement for Login Header
  final List<StarConfig> _headerStars = [
    StarConfig(top: 60, left: 50, size: 8, delayMs: 200),
    StarConfig(top: 120, left: 75, size: 6, delayMs: 600),
    StarConfig(top: 75, left: 320, size: 10, delayMs: 400),
    StarConfig(top: 140, left: 300, size: 7, delayMs: 800),
    StarConfig(top: 90, left: 190, size: 11, delayMs: 300),
  ];

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // 🔥 FIREBASE EMAIL/PASSWORD LOGIN
  // ============================================================
  Future<void> _signInWithEmailAndPassword(String email, String password) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // ── Email verification gate ──────────────────────────────────
      final user = cred.user;
      if (user != null && !user.emailVerified) {
        // Resend verification email and redirect to verification screen
        try {
          await user.sendEmailVerification();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
          content: Text(
                 '${AppLocalizations.of(context)!.tr("please_verify_email")} $email',
              ),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onLoginSuccess(); // auth_screen will re-check and route to verify screen
        }
        return;
      }
      
      if (mounted) {
        widget.onLoginSuccess();
      }
    } on FirebaseAuthException catch (e) {
      String message = AppLocalizations.of(context)!.tr('login_failed');
      
      switch (e.code) {
        case 'user-not-found':
          message = AppLocalizations.of(context)!.tr('no_account_found');
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = AppLocalizations.of(context)!.tr('incorrect_password');
          break;
        case 'invalid-email':
            message = AppLocalizations.of(context)!.tr('invalid_email');
          break;
        case 'too-many-requests':
          message = AppLocalizations.of(context)!.tr('too_many_requests');
          break;
        default:
          message = e.message ?? AppLocalizations.of(context)!.tr('login_failed');
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
            content: Text(AppLocalizations.of(context)!.tr('unexpected_error')),
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
  // 🔥 FIREBASE GOOGLE SIGN-IN
  // ============================================================
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled sign-in
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
        widget.onLoginSuccess();
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
              content: Text(AppLocalizations.of(context)!.tr('unexpected_error')),
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
                         AppLocalizations.of(context)!.tr('assalamu_alaikum'),
                        style: GoogleFonts.amiri(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.midTeal,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                       child: Text(
                         AppLocalizations.of(context)!.tr('welcome_back'),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                       child: Text(
                         AppLocalizations.of(context)!.tr('login_continue'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.navyBlue.withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
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
                     const SizedBox(height: 20),
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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                         child: Text(
                           AppLocalizations.of(context)!.tr('forgot_password'),
                          style: GoogleFonts.inter(
                            color: AppColors.midTeal,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildLoginButton(),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildGoogleButton(),
                    const SizedBox(height: 28),
                    _buildRegisterText(),
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

  // ===== FORGOT PASSWORD DIALOG =====
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: emailController.text);
    final dialogFormKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
                   title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.midTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.midTeal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.tr('reset_password'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyBlue,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your registered email address and we will send you a link to reset your password.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.navyBlue.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.tr('email_address'),
                        prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.placeholder),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.midTeal, width: 2),
                        ),
                      ),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;

                          setDialogState(() => isSending = true);
                          final email = resetEmailController.text.trim();

                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reset link sent to $email!\nCheck your Inbox, Spam, or Junk folder.'),
                                  backgroundColor: AppColors.midTeal,
                                  duration: const Duration(seconds: 6),
                                ),
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() => isSending = false);
                            String errorMsg = e.message ?? 'Failed to send reset email.';
                            if (e.code == 'user-not-found') {
                              errorMsg = 'No account found with this email. Please register first or use Google Sign-In.';
                            } else if (e.code == 'invalid-email') {
                              errorMsg = 'The email address is badly formatted.';
                            }
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSending = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Send Reset Link',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
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

  // ===== LOGIN BUTTON =====
  Widget _buildLoginButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                if (_formKey.currentState!.validate()) {
                  _signInWithEmailAndPassword(
                    emailController.text.trim(),
                    passwordController.text,
                  );
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
                    AppLocalizations.of(context)!.tr('login'),
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

  // ===== BOTTOM REGISTER TEXT =====
  Widget _buildRegisterText() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.navyBlue),
          children: [
              const TextSpan(text: "Don't have an account? "),
            TextSpan(
              text: AppLocalizations.of(context)!.tr('register'),
              style: GoogleFonts.inter(
                color: AppColors.midTeal,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = widget.onShowRegister,
            ),
          ],
        ),
      ),
    );
  }
}