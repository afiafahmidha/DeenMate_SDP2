import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<Locale> appLanguageNotifier = ValueNotifier<Locale>(const Locale('en'));

class LanguageService {
  static const String en = 'en';
  static const String bn = 'bn';

  static Future<void> loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language') ?? 'en';
    appLanguageNotifier.value = Locale(code);
  }

  static Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    appLanguageNotifier.value = Locale(languageCode);
  }

  static String get currentLanguage => appLanguageNotifier.value.languageCode;
}
