import 'map_event_entry.dart';
import 'map_location.dart';

class MapSearchResult {
  final String id;
  final String title;
  final String? origin;
  final String? eventId;
  final MapLocation destination;

  const MapSearchResult({
    required this.id,
    required this.title,
    required this.destination,
    this.origin,
    this.eventId,
  });

  bool get isEvent => eventId != null;
}

/// A small, pre-normalized local index. No model loading or network per query.
class MapSearchIndex {
  final List<_IndexedResult> _entries;

  MapSearchIndex(List<MapLocation> locations, List<MapEventEntry> events)
      : _entries = [
          for (final entry in {
            for (final entry in events) entry.event.id: entry,
          }.values)
            if (entry.locations.isNotEmpty)
              _IndexedResult(
                MapSearchResult(
                  id: 'event:${entry.event.id}',
                  title: entry.event.title,
                  eventId: entry.event.id,
                  origin: entry.locations.first.label,
                  destination: entry.locations.first,
                ),
                entry.locations.map((place) => place.label).join(' '),
              ),
          for (final place in {
            for (final place in locations) place.key: place,
          }.values)
            _IndexedResult(
              MapSearchResult(
                id: 'place:${place.key}',
                title: place.label.split(' · ').first,
                origin: place.label.contains(' · ')
                    ? place.label.split(' · ').skip(1).join(' · ')
                    : null,
                destination: place,
              ),
              place.label,
            ),
        ];

  List<MapSearchResult> search(String query) {
    final normalized = _normalize(query).trim();
    if (normalized.isEmpty) {
      return [for (final entry in _entries) entry.result];
    }
    final tokens = normalized.split(RegExp(r'\s+'));
    final matches = <(_IndexedResult, int, int)>[];
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (!tokens.every(entry.searchable.contains)) continue;
      final score = entry.title == normalized
          ? 0
          : entry.title.startsWith(normalized)
              ? 1
              : tokens.every(entry.title.contains)
                  ? 2
                  : 3;
      matches.add((entry, score, index));
    }
    matches.sort((a, b) {
      final score = a.$2.compareTo(b.$2);
      return score != 0 ? score : a.$3.compareTo(b.$3);
    });
    return [for (final match in matches) match.$1.result];
  }
}

class _IndexedResult {
  final MapSearchResult result;
  final String title;
  final String searchable;

  _IndexedResult(this.result, String extra)
      : title = _normalize(result.title),
        searchable = _normalize('${result.title} $extra');
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàãâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');
