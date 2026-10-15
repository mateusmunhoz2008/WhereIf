import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  // tema atual do aparelho
  final themeMode = signal<ThemeMode>(ThemeMode.system);

  Future<void> setDarkMode(bool enabled) async {
    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, enabled ? 'dark' : 'light');
  }

  void toggleTheme(BuildContext context) {
    if (themeMode.value == ThemeMode.system) {
      final isPlatformDark =
          View.of(context).platformDispatcher.platformBrightness ==
              Brightness.dark;
      themeMode.value = isPlatformDark ? ThemeMode.light : ThemeMode.dark;
    } else {
      themeMode.value =
          themeMode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    }
  }

  static const _themeKey = 'settings.theme';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);

    themeMode.value = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
