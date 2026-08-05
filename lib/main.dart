import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'firebase_options.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _splashDone = false;
  VoidCallback? _themeListener;

  @override
  void initState() {
    super.initState();
    _initSystemUI();
    _themeListener = () => _applySystemUI(appThemeNotifier.value);
    appThemeNotifier.addListener(_themeListener!);
  }

  Future<void> _initSystemUI() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    _applySystemUI(isDark);
  }

  void _applySystemUI(bool isDark) {
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    if (_themeListener != null) {
      appThemeNotifier.removeListener(_themeListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeenMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1A2E40),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: _splashDone
          ? const AuthScreen()
          : SplashScreen(
              onFinished: () => setState(() => _splashDone = true),
            ),
    );
  }
}