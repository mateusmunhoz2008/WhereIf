import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_record.dart';

/// Estrutura do documento em
/// `/accounts/{uid}/personalActivityRecords/{recordId}`.
///
/// O `recordId` é sempre o `eventId` do evento que originou o registro
/// (ver comentário em [ComplementaryHoursRecord.id]).
class ComplementaryHoursFirestoreMapper {
  static Map<String, dynamic> toMap(ComplementaryHoursRecord record) {
    return {
      'eventName': record.eventName,
      'eventDate': Timestamp.fromDate(record.eventDate),
      'durationMinutes': record.durationMinutes,
    };
  }

  static ComplementaryHoursRecord fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const {};
    final rawDuration = data['durationMinutes'];

    return ComplementaryHoursRecord(
      id: snapshot.id,
      eventName: data['eventName'] as String? ?? '',
      eventDate: _timestamp(data['eventDate']),
      durationMinutes: rawDuration is int ? rawDuration : null,
    );
  }

  static DateTime _timestamp(dynamic value) =>
      value is Timestamp ? value.toDate() : DateTime.now();
}
