import 'package:autth_injustice_app/complementary_hours/domain/complementary_hours_types.dart';

abstract interface class IComplementaryHoursService {
  Future<ComplementaryHoursSummaryResult> getSummary(String uid);

  Future<ComplementaryHoursRecordsResult> getRecords(String uid);

  Future<ComplementaryHoursRecordActionResult> deleteRecord(
    String uid,
    String recordId,
  );
}
