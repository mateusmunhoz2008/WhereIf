import 'map_zone.dart';

/// A stable destination. Labels are for display, never for finding 3D objects.
class MapLocation {
  final String institutionId;
  final String zoneId;
  final String? floorId;
  final String? spaceNodeName;
  final String label;

  const MapLocation(
      {required this.institutionId,
      required this.zoneId,
      required this.label,
      this.floorId,
      this.spaceNodeName})
      : assert(spaceNodeName == null || floorId != null);

  String get key =>
      '$institutionId/$zoneId/${floorId ?? ''}/${spaceNodeName ?? ''}';
  bool get isValid =>
      institutionId.trim().isNotEmpty &&
      zoneId.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      (floorId == null || floorId!.trim().isNotEmpty) &&
      (spaceNodeName == null ||
          (floorId != null && spaceNodeName!.trim().isNotEmpty));

  Map<String, Object?> toJson() => {
        'institutionId': institutionId,
        'zoneId': zoneId,
        'floorId': floorId,
        'spaceNodeName': spaceNodeName,
        'label': label
      };

  static List<MapLocation> readList(Object? value) {
    if (value is! List) return const [];
    final locations = <String, MapLocation>{};
    for (final item in value) {
      if (item is! Map ||
          item['institutionId'] is! String ||
          item['zoneId'] is! String ||
          item['label'] is! String ||
          (item['floorId'] != null && item['floorId'] is! String) ||
          (item['spaceNodeName'] != null && item['spaceNodeName'] is! String)) {
        continue;
      }
      if (item['spaceNodeName'] != null && item['floorId'] == null) continue;
      final location = MapLocation(
          institutionId: item['institutionId'],
          zoneId: item['zoneId'],
          floorId: item['floorId'],
          spaceNodeName: item['spaceNodeName'],
          label: item['label']);
      if (location.isValid) locations[location.key] = location;
    }
    return List.unmodifiable(locations.values);
  }

  @override
  bool operator ==(Object other) => other is MapLocation && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

class MapLocationCatalog {
  final List<MapLocation> locations;
  MapLocationCatalog(String institutionId, List<MapZone> zones)
      : locations = List.unmodifiable([
          for (final zone in zones) ...[
            MapLocation(
                institutionId: institutionId,
                zoneId: zone.id,
                label: zone.label),
            for (final floor in zone.floors) ...[
              MapLocation(
                  institutionId: institutionId,
                  zoneId: zone.id,
                  floorId: floor.id,
                  label: '${floor.label} · ${zone.label}'),
              for (final space in floor.spaces)
                MapLocation(
                    institutionId: institutionId,
                    zoneId: zone.id,
                    floorId: floor.id,
                    spaceNodeName: space['nodeName'],
                    label:
                        '${space['label']} · ${floor.label} · ${zone.label}'),
            ],
          ],
        ]);
  MapLocation? resolve(MapLocation reference) {
    for (final location in locations) {
      if (location == reference) return location;
    }
    return null;
  }
}
