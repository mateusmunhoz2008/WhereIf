import 'dart:convert';
import 'dart:io';

import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('court is selectable and uses the captured phone camera', () {
    final metadata = jsonDecode(File(
      'assets/institutions/ifpr-pgua/map/campus_map.json',
    ).readAsStringSync()) as Map<String, dynamic>;
    final zones = (metadata['zones'] as List)
        .map((json) => MapZone.fromJson(json as Map<String, dynamic>));
    final court = zones.singleWhere((zone) => zone.id == 'quadra');
    expect(court.nodeName, 'quadra');
    expect(court.label, 'Quadra');
    expect(court.focusOnVisualCenter, isTrue);
    expect(court.focusPosition,
        [-23.634898770638898, 57.768847057900985, 45.322597437942804]);
    expect(court.focusTarget,
        [69.67167242389885, 4.583362102508552, 92.1012252461731]);
  });
}
