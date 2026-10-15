import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'event_preview.dart';
import 'event_timing.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';

class EventUpdateInput {
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
  final String? replacementImageSource;
  final DateTime? publishAt;

  const EventUpdateInput({
    required this.title,
    required this.category,
    required this.startsAt,
    required this.endMode,
    required this.description,
    this.externalUrl,
    this.endsAt,
    this.locationLabel,
    this.mapLocations = const [],
    this.complementaryMinutes,
    this.replacementImageSource,
    this.publishAt,
  })  : assert(title != ''),
        assert(description != ''),
        assert(
          endMode != EventEndMode.automatic || endsAt != null,
          'Automatic events require an end date.',
        ),
        assert(complementaryMinutes == null || complementaryMinutes > 0);

  EventPreview applyTo(
    EventPreview current, {
    String? replacementRemoteImageUrl,
  }) {
    return current.copyWith(
      title: title,
      category: category,
      startsAt: startsAt,
      endMode: endMode,
      endsAt: endMode == EventEndMode.automatic ? endsAt : null,
      location: locationLabel ?? '',
      mapLocations: List.unmodifiable(mapLocations),
      description: description,
      externalUrl: externalUrl,
      imageUrl: replacementRemoteImageUrl ??
          replacementImageSource ??
          current.imageUrl,
      publishAt: publishAt,
    );
  }
}
