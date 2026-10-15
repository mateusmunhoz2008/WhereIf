import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController {
  final InstitutionPackage _institutionPackage;

  final locale = signal<Locale?>(null);

  LocaleController({
    required InstitutionPackage institutionPackage,
  }) : _institutionPackage = institutionPackage;

  List<String> get supportedLanguageCodes =>
      _institutionPackage.localization.supportedLanguageCodes;

  Future<void> cycleLanguage(String currentLanguageCode) async {
    final currentIndex = supportedLanguageCodes.indexOf(currentLanguageCode);
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % supportedLanguageCodes.length;

    final languageCode = supportedLanguageCodes[nextIndex];
    locale.value = Locale(languageCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  void useSystemLocale() {
    locale.value = null;
  }

  static const _languageKey = 'settings.language';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey);

    if (savedLanguage != null &&
        supportedLanguageCodes.contains(savedLanguage)) {
      locale.value = Locale(savedLanguage);
    }
  }
}
