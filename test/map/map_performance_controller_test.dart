import 'package:autth_injustice_app/map/presentation/viewmodels/map_performance_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing choice waits to migrate the actual map preset', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = MapPerformanceController();
    await controller.initialize();
    expect(controller.enabled.value, isNull);
    await controller.acceptRendererMode(true);
    final reopened = MapPerformanceController();
    await reopened.initialize();
    expect(reopened.enabled.value, isTrue);
  });

  test('on and off survive reopening, without changing other preferences',
      () async {
    SharedPreferences.setMockInitialValues(
        {'map.climate': 'night', 'theme': 'dark', 'locale': 'pt'});
    final controller = MapPerformanceController();
    for (final value in [true, false, true]) {
      await controller.setEnabled(value);
      final reopened = MapPerformanceController();
      await reopened.initialize();
      expect(reopened.enabled.value, value);
    }
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('map.climate'), 'night');
    expect(preferences.getString('theme'), 'dark');
    expect(preferences.getString('locale'), 'pt');
  });

  test('rapid taps persist the last choice', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = MapPerformanceController();
    await Future.wait([
      controller.setEnabled(true),
      controller.setEnabled(false),
      controller.setEnabled(true)
    ]);
    final reopened = MapPerformanceController();
    await reopened.initialize();
    expect(reopened.enabled.value, isTrue);
  });

  test('invalid saved data waits for a valid renderer choice', () async {
    SharedPreferences.setMockInitialValues(
        {MapPerformanceController.preferenceKey: 'invalid'});
    final controller = MapPerformanceController();
    await controller.initialize();
    expect(controller.enabled.value, isNull);
    await controller.acceptRendererMode(false);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(MapPerformanceController.preferenceKey),
        isFalse);
  });
}
