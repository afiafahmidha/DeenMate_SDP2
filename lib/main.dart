import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'widgets/app_lifecycle_splash_wrapper.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeenMate',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black12,
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
  }
}