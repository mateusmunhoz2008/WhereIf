import 'package:autth_injustice_app/map/domain/models/map_climate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MapClimateController {
  static const preferenceKey = 'map.climate';
  final climate = signal(MapClimate.automatic);

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    climate.value =
        MapClimate.fromStorage(preferences.getString(preferenceKey));
  }

  Future<void> setClimate(MapClimate mode) async {
    climate.value = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, mode.name);
  }
}
