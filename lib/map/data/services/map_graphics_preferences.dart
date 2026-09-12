import 'package:autth_injustice_app/map/domain/models/map_graphics_quality.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapGraphicsPreferences {
  static const _qualityKey = 'map.graphics_quality';

  const MapGraphicsPreferences();

  Future<MapGraphicsQuality?> load() async {
    final preferences = await SharedPreferences.getInstance();
    return MapGraphicsQuality.fromStorage(preferences.getString(_qualityKey));
  }

  Future<void> save(MapGraphicsQuality quality) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_qualityKey, quality.name);
  }
}
