import 'package:flutter/material.dart';
import 'screens/registration_page.dart';

void main() {
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
            child: const RegistrationPage(),
          ),
        ),
      ),
    );
  }
}