import 'package:autth_injustice_app/map/domain/models/map_climate.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_climate_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to the device clock and ignores the old graphics choice',
      () async {
    SharedPreferences.setMockInitialValues({'map.graphicsQuality': 'complete'});
    final controller = MapClimateController();
    await controller.initialize();
    expect(controller.climate.value, MapClimate.automatic);
    expect(controller.climate.value.previewMinutes, isNull);
  });

  test('every atmosphere choice survives a new controller', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = MapClimateController();
    for (final mode in MapClimate.values) {
      await controller.setClimate(mode);
      final reopened = MapClimateController();
      await reopened.initialize();
      expect(reopened.climate.value, mode);
      expect(reopened.climate.value.previewMinutes, mode.previewMinutes);
    }
  });

  test('invalid saved choices safely use automatic', () async {
    SharedPreferences.setMockInitialValues(
        {MapClimateController.preferenceKey: 'invalid'});
    final controller = MapClimateController();
    await controller.initialize();
    expect(controller.climate.value, MapClimate.automatic);
  });

  test('manual choices sample the approved presets', () {
    expect(MapClimate.morning.previewMinutes, 360);
    expect(MapClimate.midday.previewMinutes, 720);
    expect(MapClimate.sunset.previewMinutes, 1080);
    expect(MapClimate.night.previewMinutes, 1260);
  });

  test('each tap cycles the five choices and returns to dynamic', () {
    var mode = MapClimate.automatic;
    for (final expected in [
      MapClimate.morning,
      MapClimate.midday,
      MapClimate.sunset,
      MapClimate.night,
      MapClimate.automatic
    ]) {
      mode = mode.next;
      expect(mode, expected);
    }
  });
}
