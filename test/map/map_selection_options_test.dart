import 'package:autth_injustice_app/map/domain/models/map_selection_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Native selection options preserve optimized defaults', () {
    final options = MapSelectionOptions.fromJson({});
    expect(options.labels, isTrue);
    expect(options.floors, isTrue);
    expect(options.uiAnimation, isTrue);
    expect(options.glass, isFalse);
  });
  test('Each native overlay switch follows the viewer without dependencies',
      () {
    final options = MapSelectionOptions.fromJson({
      'labels': false,
      'floors': false,
      'uiAnimation': false,
      'glass': true,
      'outline': true,
    });
    expect(options.labels, isFalse);
    expect(options.floors, isFalse);
    expect(options.uiAnimation, isFalse);
    expect(options.glass, isTrue);
    expect(MapSelectionOptions.fromJson({'labels': 'bad'}).labels, isTrue);
  });
}
