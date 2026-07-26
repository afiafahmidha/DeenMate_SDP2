import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'widgets/app_lifecycle_splash_wrapper.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  // Load saved theme preference and initialize global notifier
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  appThemeNotifier.value = isDark;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appThemeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'DeenMate',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF6F0F4),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            backgroundColor: isDark ? Colors.black : const Color(0xFFF6F0F4),
            body: Center(
              child: Container(
                width: 430,
                constraints: const BoxConstraints(maxWidth: 430),
                child: const AppLifecycleSplashWrapper(
                  child: AuthScreen(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}