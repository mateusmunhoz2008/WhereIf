import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'event_creation_input.dart';
import 'event_details.dart';
import 'event_external_link.dart';
import 'event_preview.dart';
import 'event_timing.dart';
import 'event_update_input.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';

const _unsetEventDraftValue = Object();

enum EventPublicationMode {
  now,
  scheduled,
}

class EventEditorDraft {
  final String title;
  final EventCategory? category;
  final DateTime? startsAt;
  final EventEndMode? endMode;
  final DateTime? endsAt;
  final String? location;
  final List<MapLocation> mapLocations;
  String? get displayLocation => mapLocations.isEmpty
      ? location
      : mapLocations.map((place) => place.label).join('\n');
  final String description;
  final String? externalUrl;
  final int? complementaryMinutes;
  final String? selectedImageSource;
  final String? existingImageUrl;
  final DateTime? publishAt;

  const EventEditorDraft({
    this.title = '',
    this.category,
    this.startsAt,
    this.endMode,
    this.endsAt,
    this.location,
    this.mapLocations = const [],
    this.description = '',
    this.externalUrl,
    this.complementaryMinutes,
    this.selectedImageSource,
    this.existingImageUrl,
    this.publishAt,
  })  : assert(complementaryMinutes == null || complementaryMinutes >= 0),
        assert(
          location == null || location != '',
          'Use null when the location is omitted.',
        );

  factory EventEditorDraft.fromDetails(
    EventDetails details, {
    DateTime? now,
  }) {
    final event = details.event;
    final effectiveNow = now ?? DateTime.now();
    final pendingPublication =
        event.publishAt?.isAfter(effectiveNow) == true ? event.publishAt : null;

    return EventEditorDraft(
      title: event.title,
      category: event.category,
      startsAt: event.startsAt,
      endMode: event.endMode,
      endsAt: event.endsAt,
      location: event.mapLocations.isNotEmpty || event.location.trim().isEmpty
          ? null
          : event.location,
      mapLocations: List.unmodifiable(event.mapLocations),
      description: event.description,
      externalUrl: event.externalUrl,
      complementaryMinutes: details.complementaryMinutes,
      existingImageUrl: event.imageUrl,
      publishAt: pendingPublication,
    );
  }

  EventPublicationMode get publicationMode => publishAt == null
      ? EventPublicationMode.now
      : EventPublicationMode.scheduled;

  String? get displayImageSource => selectedImageSource ?? existingImageUrl;

  EventPreview toDisplayPreview({
    required EventCategory fallbackCategory,
    String id = 'event-preview',
  }) {
    return EventPreview(
      id: id,
      title: title.trim(),
      category: category ?? fallbackCategory,
      startsAt: startsAt ?? DateTime.now(),
      endMode: endMode ?? EventEndMode.manual,
      endsAt: endMode == EventEndMode.automatic ? endsAt : null,
      location: location?.trim() ?? '',
      mapLocations: List.unmodifiable(mapLocations),
      description: description.trim(),
      externalUrl: EventExternalLink.normalize(externalUrl),
      imageUrl: displayImageSource ?? '',
      publishAt: publishAt,
    );
  }

  EventCreationInput toCreationInput() {
    return EventCreationInput(
      title: title.trim(),
      category: category!,
      startsAt: startsAt!,
      endMode: endMode!,
      endsAt: endMode == EventEndMode.automatic ? endsAt : null,
      locationLabel: switch (location?.trim()) {
        final value? when value.isNotEmpty => value,
        _ => null,
      },
      mapLocations: List.unmodifiable(mapLocations),
      description: description.trim(),
      externalUrl: EventExternalLink.normalize(externalUrl),
      complementaryMinutes: complementaryMinutes,
      imageSource: selectedImageSource!.trim(),
      publishAt: publishAt,
    );
  }

  EventUpdateInput toUpdateInput() {
    return EventUpdateInput(
      title: title.trim(),
      category: category!,
      startsAt: startsAt!,
      endMode: endMode!,
      endsAt: endMode == EventEndMode.automatic ? endsAt : null,
      locationLabel: switch (location?.trim()) {
        final value? when value.isNotEmpty => value,
        _ => null,
      },
      mapLocations: List.unmodifiable(mapLocations),
      description: description.trim(),
      externalUrl: EventExternalLink.normalize(externalUrl),
      complementaryMinutes: complementaryMinutes,
      replacementImageSource: selectedImageSource?.trim(),
      publishAt: publishAt,
    );
  }

  EventEditorDraft copyWith({
    String? title,
    Object? category = _unsetEventDraftValue,
    Object? startsAt = _unsetEventDraftValue,
    Object? endMode = _unsetEventDraftValue,
    Object? endsAt = _unsetEventDraftValue,
    Object? location = _unsetEventDraftValue,
    List<MapLocation>? mapLocations,
    String? description,
    Object? externalUrl = _unsetEventDraftValue,
    Object? complementaryMinutes = _unsetEventDraftValue,
    Object? selectedImageSource = _unsetEventDraftValue,
    Object? existingImageUrl = _unsetEventDraftValue,
    Object? publishAt = _unsetEventDraftValue,
  }) {
    return EventEditorDraft(
      title: title ?? this.title,
      category: identical(category, _unsetEventDraftValue)
          ? this.category
          : category as EventCategory?,
      startsAt: identical(startsAt, _unsetEventDraftValue)
          ? this.startsAt
          : startsAt as DateTime?,
      endMode: identical(endMode, _unsetEventDraftValue)
          ? this.endMode
          : endMode as EventEndMode?,
      endsAt: identical(endsAt, _unsetEventDraftValue)
          ? this.endsAt
          : endsAt as DateTime?,
      location: identical(location, _unsetEventDraftValue)
          ? this.location
          : location as String?,
      mapLocations: List.unmodifiable(mapLocations ?? this.mapLocations),
      description: description ?? this.description,
      externalUrl: identical(externalUrl, _unsetEventDraftValue)
          ? this.externalUrl
          : externalUrl as String?,
      complementaryMinutes:
          identical(complementaryMinutes, _unsetEventDraftValue)
              ? this.complementaryMinutes
              : complementaryMinutes as int?,
      selectedImageSource: identical(selectedImageSource, _unsetEventDraftValue)
          ? this.selectedImageSource
          : selectedImageSource as String?,
      existingImageUrl: identical(existingImageUrl, _unsetEventDraftValue)
          ? this.existingImageUrl
          : existingImageUrl as String?,
      publishAt: identical(publishAt, _unsetEventDraftValue)
          ? this.publishAt
          : publishAt as DateTime?,
    );
  }
}
