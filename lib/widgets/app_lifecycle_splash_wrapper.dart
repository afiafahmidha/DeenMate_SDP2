import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';

class AppLifecycleSplashWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleSplashWrapper({super.key, required this.child});

  @override
  State<AppLifecycleSplashWrapper> createState() => _AppLifecycleSplashWrapperState();
}

class _AppLifecycleSplashWrapperState extends State<AppLifecycleSplashWrapper> {
  bool _showSplash = true; // Play splash screen initially on first app load

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The main content of the app remains alive in background
        widget.child,
        // Overlay splash screen when active
        if (_showSplash)
          SplashScreen(
            onFinished: () {
              setState(() {
                _showSplash = false;
              });
            },
          ),
      ],
    );
  }
}
