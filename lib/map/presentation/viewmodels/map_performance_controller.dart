import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MapPerformanceController {
  static const preferenceKey = 'map.performanceMode';

  // Until the first map opens, migrate its existing WebView preference instead
  // of replacing the user's graphics configuration with a guessed default.
  final enabled = signal<bool?>(null);
  Future<void> _saveQueue = Future.value();

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.get(preferenceKey);
    enabled.value = stored is bool ? stored : null;
  }

  Future<void> setEnabled(bool value) {
    enabled.value = value;
    return _saveQueue = _saveQueue.catchError((Object _) {}).then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(preferenceKey, value);
    });
  }

  Future<void> acceptRendererMode(bool value) =>
      enabled.value == value ? Future.value() : setEnabled(value);
}
