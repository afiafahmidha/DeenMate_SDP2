import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<bool> appThemeNotifier = ValueNotifier<bool>(false);
final ValueNotifier<String> prayerCardThemeNotifier = ValueNotifier<String>('video');

Future<void> loadPrayerCardThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  prayerCardThemeNotifier.value = prefs.getString('prayer_card_theme_id') ?? 'video';
}

Future<void> savePrayerCardThemePreference(String themeId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('prayer_card_theme_id', themeId);
  prayerCardThemeNotifier.value = themeId;
}


