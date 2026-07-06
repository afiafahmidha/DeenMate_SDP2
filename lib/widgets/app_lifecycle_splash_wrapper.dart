import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';

class AppLifecycleSplashWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleSplashWrapper({super.key, required this.child});

  @override
  State<AppLifecycleSplashWrapper> createState() => _AppLifecycleSplashWrapperState();
}

class _AppLifecycleSplashWrapperState extends State<AppLifecycleSplashWrapper> with WidgetsBindingObserver {
  bool _showSplash = true; // Play splash screen initially on first app load
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Record pause timestamp if not already set (prevents overwriting if state changes multiple times)
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        // If background time is 5 seconds or more, trigger splash again
        if (elapsed.inSeconds >= 5) {
          setState(() {
            _showSplash = true;
          });
        }
        _pausedAt = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The main content of the app (e.g. RegistrationPage) remains alive in background
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
