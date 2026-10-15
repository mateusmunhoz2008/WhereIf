import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'map_location.dart';
import 'map_zone.dart';

class MapEventEntry {
  final EventPreview event;
  final List<MapLocation> locations;
  const MapEventEntry(this.event, this.locations);
  static List<MapEventEntry> fromEvents(
      Iterable<EventPreview> events, MapLocationCatalog catalog, DateTime now) {
    final unique = <String, MapEventEntry>{};
    for (final event in events) {
      if (event.isEndedAt(now) || event.publishAt?.isAfter(now) == true) {
        continue;
      }
      final locations = <String, MapLocation>{};
      for (final reference in event.mapLocations) {
        final location = catalog.resolve(reference);
        if (location != null) locations[location.key] = location;
      }
      if (locations.isNotEmpty) {
        unique[event.id] =
            MapEventEntry(event, List.unmodifiable(locations.values));
      }
    }
    return unique.values.toList()
      ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
  }
}

/// Unique events per floor; several rooms in one floor never inflate its count.
class MapEventFloorSummary {
  final Map<String, int> counts;
  final MapLocation? destination;
  const MapEventFloorSummary._(this.counts, this.destination);

  factory MapEventFloorSummary.fromEntries(
      Iterable<MapEventEntry> entries, MapZone zone) {
    final ids = {for (final floor in zone.floors) floor.id: <String>{}};
    MapLocation? reference;
    for (final entry in entries) {
      for (final place
          in entry.locations.where((place) => place.zoneId == zone.id)) {
        reference ??= place;
        ids[place.floorId]?.add(entry.event.id);
      }
    }
    final counts = Map<String, int>.unmodifiable(
        ids.map((floor, events) => MapEntry(floor, events.length)));
    MapFloor? busiest;
    var largest = 0;
    // Metadata order gives a predictable tie: the first/lowest floor wins.
    for (final floor in zone.floors) {
      if (counts[floor.id]! > largest) {
        busiest = floor;
        largest = counts[floor.id]!;
      }
    }
    return MapEventFloorSummary._(
        counts,
        reference == null
            ? null
            : MapLocation(
                institutionId: reference.institutionId,
                zoneId: zone.id,
                floorId: busiest?.id,
                label: busiest == null
                    ? zone.label
                    : '${busiest.label} · ${zone.label}',
              ));
  }
}
