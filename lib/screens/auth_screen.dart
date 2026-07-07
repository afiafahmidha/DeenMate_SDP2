import 'package:flutter/material.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'dashboard_screen.dart';

enum AppScreenState {
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
  AppScreenState _screenState = AppScreenState.login;

  @override
  Widget build(BuildContext context) {
    Widget activePage;
    switch (_screenState) {
      case AppScreenState.login:
        activePage = LoginPage(
          key: const ValueKey('LoginPage'),
          onShowRegister: () => setState(() => _screenState = AppScreenState.register),
          onLoginSuccess: () => setState(() => _screenState = AppScreenState.dashboard),
        );
        break;
      case AppScreenState.register:
        activePage = RegistrationPage(
          key: const ValueKey('RegistrationPage'),
          onShowLogin: () => setState(() => _screenState = AppScreenState.login),
          onRegisterSuccess: () => setState(() => _screenState = AppScreenState.dashboard),
        );
        break;
      case AppScreenState.dashboard:
        activePage = DashboardScreen(
          key: const ValueKey('DashboardScreen'),
          onLogout: () => setState(() => _screenState = AppScreenState.login),
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
