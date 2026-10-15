import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'event_preview.dart';
import 'event_timing.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';

class EventCreationInput {
  final String title;
  final EventCategory category;
  final DateTime startsAt;
  final EventEndMode endMode;
  final DateTime? endsAt;
  final String? locationLabel;
  final List<MapLocation> mapLocations;
  final String description;
  final String? externalUrl;
  final int? complementaryMinutes;
  final String imageSource;
  final DateTime? publishAt;

  const EventCreationInput({
    required this.title,
    required this.category,
    required this.startsAt,
    required this.endMode,
    required this.description,
    required this.imageSource,
    this.externalUrl,
    this.endsAt,
    this.locationLabel,
    this.mapLocations = const [],
    this.complementaryMinutes,
    this.publishAt,
  })  : assert(title != ''),
        assert(description != ''),
        assert(imageSource != ''),
        assert(
          endMode != EventEndMode.automatic || endsAt != null,
          'Automatic events require an end date.',
        ),
        assert(complementaryMinutes == null || complementaryMinutes > 0);

  EventPreview toPreview({
    required String id,
    String? remoteImageUrl,
  }) {
    return EventPreview(
      id: id,
      title: title,
      category: category,
      startsAt: startsAt,
      endMode: endMode,
      endsAt: endMode == EventEndMode.automatic ? endsAt : null,
      location: locationLabel ?? '',
      mapLocations: List.unmodifiable(mapLocations),
      description: description,
      externalUrl: externalUrl,
      imageUrl: remoteImageUrl ?? imageSource,
      publishAt: publishAt,
    );
  }
}
