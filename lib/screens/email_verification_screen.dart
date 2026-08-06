import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_header.dart';
import '../l10n/app_localizations.dart';

class EmailVerificationScreen extends StatefulWidget {
  final VoidCallback onVerified;
  final VoidCallback onSignOut;

  const EmailVerificationScreen({
    super.key,
    required this.onVerified,
    required this.onSignOut,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // ── Timers & state ─────────────────────────────────────────────
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _isChecking = false;
  bool _isSending = false;
  int _checkCount = 0;

  final List<StarConfig> _headerStars = [
    StarConfig(top: 60, left: 50, size: 8, delayMs: 200),
    StarConfig(top: 120, left: 75, size: 6, delayMs: 600),
    StarConfig(top: 75, left: 320, size: 10, delayMs: 400),
    StarConfig(top: 140, left: 300, size: 7, delayMs: 800),
    StarConfig(top: 90, left: 190, size: 11, delayMs: 300),
  ];

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Polling: check emailVerified every 5 s automatically ────────
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkVerification(auto: true);
    });
  }

  // ── Core verification check ─────────────────────────────────────
  Future<void> _checkVerification({bool auto = false}) async {
    if (_isChecking) return;
    if (!auto) setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        widget.onSignOut();
        return;
      }
      await user.reload(); // Force fresh data from Firebase
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null && fresh.emailVerified) {
        _pollTimer?.cancel();
        widget.onVerified();
      } else if (!auto) {
        setState(() => _checkCount++);
        if (mounted && _checkCount > 0) {
         _showSnack(
        _t('email_not_verified'),
            color: Colors.orange.shade700,
          );
        }
      }
    } catch (e) {
      if (!auto && mounted) {
        _showSnack(_t('error_checking_verification'));
      }
    } finally {
      if (!auto && mounted) setState(() => _isChecking = false);
    }
  }

  // ── Resend verification email ────────────────────────────────────
  Future<void> _resendEmail() async {
    if (_isSending || _cooldownSeconds > 0) return;
    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        widget.onSignOut();
        return;
      }
      await user.sendEmailVerification();
      _showSnack(
        _t('verification_email_sent'),
        color: AppColors.midTeal,
      );
      _startCooldown(60);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _showSnack(_t('too_many_requests_wait'));
        _startCooldown(60);
      } else {
        _showSnack(e.message ?? _t('failed_to_send_email'));
      }
    } catch (e) {
      _showSnack(_t('error_try_again'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Cooldown countdown ──────────────────────────────────────────
  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String _t(String key) => AppLocalizations.of(context)!.tr(key);

  void _showSnack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Sign out ────────────────────────────────────────────────────
  Future<void> _signOut() async {
    _pollTimer?.cancel();
    await FirebaseAuth.instance.signOut();
    widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'your email';
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 500;

    final Widget contentStack = Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 250,
          child: _buildHeader(context),
        ),
        Positioned.fill(
          top: 220,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(36),
                topRight: Radius.circular(36),
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.dustyBlueTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      color: AppColors.navyBlue,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),

                   Text(
                    _t('verify_your_email'),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 8),

                   Text(
                    _t('verification_sent'),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.navyBlue.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Email badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.dustyBlueTeal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 15, color: AppColors.midTeal),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            email,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.navyBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instructions
                   _InstructionStep(
                    number: '1',
                    text: _t('check_inbox'),
                  ),
                  const SizedBox(height: 10),
                  _InstructionStep(
                    number: '2',
                    text: _t('click_verify_link'),
                  ),
                  const SizedBox(height: 10),
                  _InstructionStep(
                    number: '3',
                    text: _t('return_here'),
                  ),
                  const SizedBox(height: 28),

                  // ── Check Verification Button ──────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          _isChecking ? null : () => _checkVerification(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child: _isChecking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 18),
                                const SizedBox(width: 8),
                           Text(
                            _t('ive_verified'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Resend Button ──────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: (_isSending || _cooldownSeconds > 0)
                          ? null
                          : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _cooldownSeconds > 0
                              ? AppColors.placeholder.withValues(alpha: 0.3)
                              : AppColors.midTeal,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.midTeal,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 17,
                                  color: _cooldownSeconds > 0
                                      ? AppColors.placeholder
                                      : AppColors.midTeal,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    _cooldownSeconds > 0
                                       ? '${_t("resend_in")} ${_cooldownSeconds}s'
                                       : _t('resend_verification'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: _cooldownSeconds > 0
                                        ? AppColors.placeholder
                                        : AppColors.midTeal,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Auto-checking indicator ────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.placeholder,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _t('auto_checking'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.placeholder,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Divider ────────────────────────
                  Divider(
                      color: AppColors.placeholder.withValues(alpha: 0.2),
                      thickness: 1),
                  const SizedBox(height: 14),

                  // Wrong email / Sign out
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                         _t('wrong_email'),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.navyBlue.withValues(alpha: 0.7),
                        ),
                      ),
                      GestureDetector(
                        onTap: _signOut,
                        child: Text(
                           _t('sign_out_try_again'),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Spam note
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.dustyBlueTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.dustyBlueTeal.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.navyBlue, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                             _t('cant_find_email'),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.navyBlue.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
      height: 250,
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
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              children: [
                const AppLogo(size: 60),
                const SizedBox(height: 10),
                 Text(
                _t('app_name'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyBlue,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Instruction step widget ─────────────────────────────────────────
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.navyBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.navyBlue.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
