import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'email_verification_screen.dart';
import 'dashboard_screen.dart';

enum AppScreenState {
  loading,
  login,
  register,
  verifyEmail, // ← NEW: email not verified yet
  dashboard,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AppScreenState _screenState = AppScreenState.loading;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  // ── Decide which screen to show based on Firebase auth state ────
  Future<void> _checkAuthState() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Force refresh user data so emailVerified status is up-to-date
        await user.reload();
        final fresh = FirebaseAuth.instance.currentUser;

        if (fresh == null) {
          if (mounted) setState(() => _screenState = AppScreenState.login);
          return;
        }

        final bool isGoogle = fresh.providerData.any((p) => p.providerId == 'google.com');
        final bool isVerified = fresh.emailVerified || isGoogle;

        if (!isVerified) {
          // Email not verified yet → route to verify email page
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', false);
          if (mounted) setState(() => _screenState = AppScreenState.verifyEmail);
        } else {
          // Email verified → grant dashboard access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          if (mounted) setState(() => _screenState = AppScreenState.dashboard);
        }
      } else {
        if (mounted) setState(() => _screenState = AppScreenState.login);
      }
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      if (mounted) setState(() => _screenState = AppScreenState.login);
    }
  }

  // ── Realtime listener (fires when user object changes) ──────────
  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (!mounted) return;
      if (user == null) {
        setState(() => _screenState = AppScreenState.login);
      } else {
        try {
          await user.reload();
        } catch (_) {}
        final fresh = FirebaseAuth.instance.currentUser;
        if (fresh == null) {
          setState(() => _screenState = AppScreenState.login);
        } else {
          final bool isGoogle = fresh.providerData.any((p) => p.providerId == 'google.com');
          final bool isVerified = fresh.emailVerified || isGoogle;

          if (!isVerified) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_logged_in', false);
            setState(() => _screenState = AppScreenState.verifyEmail);
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_logged_in', true);
            setState(() => _screenState = AppScreenState.dashboard);
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget activePage;

    switch (_screenState) {
      // ── Loading spinner ──────────────────────────────────────
      case AppScreenState.loading:
        activePage = const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF1A2E40)),
            ),
          ),
        );
        break;

      // ── Login ────────────────────────────────────────────────
      case AppScreenState.login:
        activePage = LoginPage(
          key: const ValueKey('LoginPage'),
          onShowRegister: () =>
              setState(() => _screenState = AppScreenState.register),
          onLoginSuccess: () async {
            // Re-check verification after login
            await _updateLoginSession(true);
            await _checkAuthState();
          },
        );
        break;

      // ── Register ─────────────────────────────────────────────
      case AppScreenState.register:
        activePage = RegistrationPage(
          key: const ValueKey('RegistrationPage'),
          onShowLogin: () =>
              setState(() => _screenState = AppScreenState.login),
          onRegisterSuccess: () async {
            // After registration, always go to verification screen
            if (mounted) {
              setState(() => _screenState = AppScreenState.verifyEmail);
            }
          },
        );
        break;

      // ── Email Verification ───────────────────────────────────
      case AppScreenState.verifyEmail:
        activePage = EmailVerificationScreen(
          key: const ValueKey('EmailVerificationScreen'),
          onVerified: () async {
            await _updateLoginSession(true);
            if (mounted) {
              setState(() => _screenState = AppScreenState.dashboard);
            }
          },
          onSignOut: () async {
            await _updateLoginSession(false);
            if (mounted) {
              setState(() => _screenState = AppScreenState.login);
            }
          },
        );
        break;

      // ── Dashboard ────────────────────────────────────────────
      case AppScreenState.dashboard:
        activePage = DashboardScreen(
          key: const ValueKey('DashboardScreen'),
          onLogout: () async {
            await _updateLoginSession(false);
            if (mounted) {
              setState(() => _screenState = AppScreenState.login);
            }
          },
        );
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: activePage,
    );
  }

  // ── Session helper ───────────────────────────────────────────────
  Future<void> _updateLoginSession(bool isLoggedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', isLoggedIn);
      if (!isLoggedIn) {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
      }
    } catch (e) {
      debugPrint('Error updating login session: $e');
    }
  }
}