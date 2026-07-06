import 'package:flutter/material.dart';
import 'login_page.dart';
import 'registration_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
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
      child: _showLogin
          ? LoginPage(
              key: const ValueKey('LoginPage'),
              onShowRegister: () => setState(() => _showLogin = false),
            )
          : RegistrationPage(
              key: const ValueKey('RegistrationPage'),
              onShowLogin: () => setState(() => _showLogin = true),
            ),
    );
  }
}
