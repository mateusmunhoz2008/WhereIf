import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'event_external_link.dart';
import 'event_timing.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';

const _unsetEventPreviewValue = Object();

class EventPreview {
  final String id;
  final String title;
  final EventCategory category;
  final DateTime startsAt;
  final String location;
  final List<MapLocation> mapLocations;
  String get displayLocation => mapLocations.isEmpty
      ? location
      : mapLocations.map((place) => place.label).join('\n');
  final String description;
  final String? externalUrl;
  final String imageUrl;
  final DateTime? publishAt;
  final EventEndMode endMode;
  final DateTime? endsAt;
  final DateTime? endedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? cancelledByUid;

  EventPreview({
    required this.id,
    required this.title,
    required this.category,
    required this.startsAt,
    required this.location,
    this.mapLocations = const [],
    required this.description,
    required this.imageUrl,
    required this.endMode,
    this.externalUrl,
    this.publishAt,
    this.endsAt,
    this.endedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancelledByUid,
  })  : assert(
          endMode != EventEndMode.automatic || endsAt != null,
          'Automatic events require an end date.',
        ),
        assert(
          endsAt == null || endsAt.isAfter(startsAt),
          'The event end must be after its start.',
        ),
        assert(
          cancelledAt == null ||
              (cancellationReason != null && cancelledByUid != null),
          'Cancelled events require a reason and author.',
        ),
        assert(
          EventExternalLink.isValidOptional(externalUrl),
          'The external URL must use HTTP or HTTPS.',
        );

  EventLifecycleStatus lifecycleAt(DateTime now) {
    if (cancelledAt != null) return EventLifecycleStatus.ended;

    return EventTiming.statusAt(
      now: now,
      startsAt: startsAt,
      endMode: endMode,
      endsAt: endsAt,
      endedAt: endedAt,
    );
  }

  bool isUpcomingAt(DateTime now) =>
      lifecycleAt(now) == EventLifecycleStatus.upcoming;

  bool isOngoingAt(DateTime now) =>
      lifecycleAt(now) == EventLifecycleStatus.ongoing;

  bool isEndedAt(DateTime now) =>
      lifecycleAt(now) == EventLifecycleStatus.ended;

  bool get isCancelled => cancelledAt != null;

  EventPreview copyWith({
    String? id,
    String? title,
    EventCategory? category,
    DateTime? startsAt,
    String? location,
    List<MapLocation>? mapLocations,
    String? description,
    Object? externalUrl = _unsetEventPreviewValue,
    String? imageUrl,
    Object? publishAt = _unsetEventPreviewValue,
    EventEndMode? endMode,
    Object? endsAt = _unsetEventPreviewValue,
    Object? endedAt = _unsetEventPreviewValue,
    Object? cancelledAt = _unsetEventPreviewValue,
    Object? cancellationReason = _unsetEventPreviewValue,
    Object? cancelledByUid = _unsetEventPreviewValue,
  }) {
    return EventPreview(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      startsAt: startsAt ?? this.startsAt,
      location: location ?? this.location,
      mapLocations: List.unmodifiable(mapLocations ?? this.mapLocations),
      description: description ?? this.description,
      externalUrl: identical(externalUrl, _unsetEventPreviewValue)
          ? this.externalUrl
          : externalUrl as String?,
      imageUrl: imageUrl ?? this.imageUrl,
      publishAt: identical(publishAt, _unsetEventPreviewValue)
          ? this.publishAt
          : publishAt as DateTime?,
      endMode: endMode ?? this.endMode,
      endsAt: identical(endsAt, _unsetEventPreviewValue)
          ? this.endsAt
          : endsAt as DateTime?,
      endedAt: identical(endedAt, _unsetEventPreviewValue)
          ? this.endedAt
          : endedAt as DateTime?,
      cancelledAt: identical(cancelledAt, _unsetEventPreviewValue)
          ? this.cancelledAt
          : cancelledAt as DateTime?,
      cancellationReason: identical(cancellationReason, _unsetEventPreviewValue)
          ? this.cancellationReason
          : cancellationReason as String?,
      cancelledByUid: identical(cancelledByUid, _unsetEventPreviewValue)
          ? this.cancelledByUid
          : cancelledByUid as String?,
    );
  }
}
