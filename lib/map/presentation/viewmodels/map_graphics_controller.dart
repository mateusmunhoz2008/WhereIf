import 'package:autth_injustice_app/map/data/services/map_graphics_preferences.dart';
import 'package:autth_injustice_app/map/domain/models/map_graphics_quality.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MapGraphicsController {
  final MapGraphicsPreferences _preferences;
  final quality = signal(MapGraphicsQuality.complete);
  final hasExplicitPreference = signal(false);

  MapGraphicsController(this._preferences);

  String get requestedRendererProfile => hasExplicitPreference.value
      ? quality.value.rendererProfile
      : 'auto';

  Future<void> initialize() async {
    final saved = await _preferences.load();
    if (saved == null) return;
    quality.value = saved;
    hasExplicitPreference.value = true;
  }

  Future<void> setQuality(MapGraphicsQuality value) async {
    quality.value = value;
    hasExplicitPreference.value = true;
    await _preferences.save(value);
  }

  void acceptDetectedProfile(String rendererProfile) {
    if (hasExplicitPreference.value) return;
    quality.value = rendererProfile == MapGraphicsQuality.light.rendererProfile
        ? MapGraphicsQuality.light
        : MapGraphicsQuality.complete;
  }
}
