import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';

class EventFirestoreMapper {
  static Map<String, dynamic> toMap(
    EventPreview event, {
    int? complementaryMinutes,
  }) {
    return {
      'title': event.title,
      'category': event.category.storageValue,
      'startsAt': Timestamp.fromDate(event.startsAt),
      'endMode': event.endMode.name,
      'endsAt': event.endsAt != null ? Timestamp.fromDate(event.endsAt!) : null,
      'endedAt': event.endedAt != null ? Timestamp.fromDate(event.endedAt!) : null,
      'location': event.location,
      'description': event.description,
      'externalUrl': event.externalUrl,
      'imageUrl': event.imageUrl,
      'publishAt':
          event.publishAt != null ? Timestamp.fromDate(event.publishAt!) : null,
      'cancelledAt':
          event.cancelledAt != null ? Timestamp.fromDate(event.cancelledAt!) : null,
      'cancellationReason': event.cancellationReason,
      'cancelledByUid': event.cancelledByUid,
      'complementaryMinutes': complementaryMinutes,
    };
  }

  static EventPreview previewFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    InstitutionPackage institutionPackage,
  ) {
    final data = snapshot.data() ?? const {};

    return EventPreview(
      id: snapshot.id,
      title: data['title'] as String? ?? '',
      category: institutionPackage.events
          .resolveCategory(data['category'] as String? ?? ''),
      startsAt: _timestamp(data['startsAt']),
      endMode: EventEndMode.values.firstWhere(
        (mode) => mode.name == data['endMode'],
        orElse: () => EventEndMode.manual,
      ),
      endsAt: _optionalTimestamp(data['endsAt']),
      endedAt: _optionalTimestamp(data['endedAt']),
      location: data['location'] as String? ?? '',
      description: data['description'] as String? ?? '',
      externalUrl: data['externalUrl'] as String?,
      imageUrl: data['imageUrl'] as String? ?? '',
      publishAt: _optionalTimestamp(data['publishAt']),
      cancelledAt: _optionalTimestamp(data['cancelledAt']),
      cancellationReason: data['cancellationReason'] as String?,
      cancelledByUid: data['cancelledByUid'] as String?,
    );
  }

  static int? complementaryMinutesFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final value = snapshot.data()?['complementaryMinutes'];
    return value is int ? value : null;
  }

  static DateTime _timestamp(dynamic value) =>
      value is Timestamp ? value.toDate() : DateTime.now();

  static DateTime? _optionalTimestamp(dynamic value) =>
      value is Timestamp ? value.toDate() : null;
}
