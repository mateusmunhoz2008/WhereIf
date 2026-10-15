import 'package:autth_injustice_app/events/domain/events_types.dart';
import 'package:autth_injustice_app/events/domain/models/event_creation_input.dart';
import 'package:autth_injustice_app/events/domain/models/event_update_input.dart';

abstract interface class IEventsService {
  Future<EventsCatalogResult> getCatalog();

  Future<EventsCatalogResult> getManagementCatalog({
    required String actorUid,
  });

  Future<EventDetailsResult> getEventDetails({
    String? uid,
    required String eventId,
  });

  Future<EventPersonalRecordResult> setPersonalRecord({
    required String uid,
    required String eventId,
    required bool addedToPersonalHistory,
  });

  /// Device images must be uploaded before their URL is persisted.
  Future<EventCreationResult> createEvent({
    required String actorUid,
    required EventCreationInput input,
  });

  /// Preserves the current image when no replacement is supplied.
  Future<EventUpdateResult> updateEvent({
    required String actorUid,
    required String eventId,
    required EventUpdateInput input,
  });

  /// Authorization and publication constraints must also hold on the server.
  Future<EventDeletionResult> deleteEvent({
    required String actorUid,
    required String eventId,
  });

  /// Persists cancellation and its notification atomically.
  Future<EventCancellationResult> cancelEvent({
    required String actorUid,
    required String eventId,
    required String reason,
  });

  Future<EventEndResult> endEvent({
    required String actorUid,
    required String eventId,
  });
}
