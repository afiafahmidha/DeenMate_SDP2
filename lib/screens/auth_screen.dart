import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'dashboard_screen.dart';

enum AppScreenState {
  loading,
  login,
  register,
  dashboard,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AppScreenState _screenState = AppScreenState.loading;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  // 🔥 Check Firebase Auth state
  Future<void> _checkAuthState() async {
    try {
      // Listen to Firebase auth changes
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // User is signed in
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        if (mounted) {
          setState(() => _screenState = AppScreenState.dashboard);
        }
      } else {
        // Check SharedPreferences as backup
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
        if (mounted) {
          setState(() {
            _screenState = isLoggedIn ? AppScreenState.dashboard : AppScreenState.login;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      if (mounted) {
        setState(() => _screenState = AppScreenState.login);
      }
    }
  }

  // 🔥 Listen to auth changes (realtime)
  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        setState(() => _screenState = AppScreenState.dashboard);
      } else if (mounted) {
        setState(() => _screenState = AppScreenState.login);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToAuthChanges();
  }

  @override
  Widget build(BuildContext context) {
    Widget activePage;
    switch (_screenState) {
      case AppScreenState.loading:
        activePage = const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A2E40)),
            ),
          ),
        );
        break;
      case AppScreenState.login:
        activePage = LoginPage(
          key: const ValueKey('LoginPage'),
          onShowRegister: () => setState(() => _screenState = AppScreenState.register),
          onLoginSuccess: () async {
            // Firebase handles login, just update state
            await _updateLoginSession(true);
            if (mounted) {
              setState(() => _screenState = AppScreenState.dashboard);
            }
          },
        );
        break;
      case AppScreenState.register:
        activePage = RegistrationPage(
          key: const ValueKey('RegistrationPage'),
          onShowLogin: () => setState(() => _screenState = AppScreenState.login),
          onRegisterSuccess: () async {
            await _updateLoginSession(true);
            if (mounted) {
              setState(() => _screenState = AppScreenState.dashboard);
            }
          },
        );
        break;
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
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: activePage,
    );
  }

  // 🔥 Update session state
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