import 'package:flutter/material.dart';
import 'translations_en.dart';
import 'translations_bn.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('bn'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final Map<String, Map<String, String>> translations = {
    'en': enTranslations,
    'bn': bnTranslations,
  };

  String tr(String key) {
    final lang = locale.languageCode;
    final map = translations[lang];
    if (map != null && map.containsKey(key)) {
      return map[key]!;
    }
    // Fallback to English
    return enTranslations[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'bn'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension AppLocalizationsExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
