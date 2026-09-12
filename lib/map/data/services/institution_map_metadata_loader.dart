import 'dart:convert';

import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:flutter/services.dart';

class InstitutionMapMetadataLoader {
  const InstitutionMapMetadataLoader();

  Future<List<MapZone>> load(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    final json = jsonDecode(source) as Map<String, dynamic>;
    final zones = json['zones'] as List<dynamic>? ?? const [];

    return List.unmodifiable(
      zones.map(
        (zone) => MapZone.fromJson(zone as Map<String, dynamic>),
      ),
    );
  }
}
