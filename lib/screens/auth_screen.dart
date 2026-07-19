import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _checkLoginSession();
  }

  // Check SharedPreferences on start
  Future<void> _checkLoginSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (mounted) {
        setState(() {
          _screenState = isLoggedIn ? AppScreenState.dashboard : AppScreenState.login;
        });
      }
    } catch (e) {
      debugPrint('Error loading login session: $e');
      if (mounted) {
        setState(() {
          _screenState = AppScreenState.login;
        });
      }
    }
  }

  // Update session state in SharedPreferences
  Future<void> _updateLoginSession(bool isLoggedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', isLoggedIn);
    } catch (e) {
      debugPrint('Error updating login session: $e');
    }
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
          onLoginSuccess: () {
            _updateLoginSession(true);
            setState(() => _screenState = AppScreenState.dashboard);
          },
        );
        break;
      case AppScreenState.register:
        activePage = RegistrationPage(
          key: const ValueKey('RegistrationPage'),
          onShowLogin: () => setState(() => _screenState = AppScreenState.login),
          onRegisterSuccess: () {
            _updateLoginSession(true);
            setState(() => _screenState = AppScreenState.dashboard);
          },
        );
        break;
      case AppScreenState.dashboard:
        activePage = DashboardScreen(
          key: const ValueKey('DashboardScreen'),
          onLogout: () {
            _updateLoginSession(false);
            setState(() => _screenState = AppScreenState.login);
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
}
