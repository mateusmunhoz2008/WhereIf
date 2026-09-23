import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/complementary_hours/data/mappers/complementary_hours_firestore_mapper.dart';
import 'package:autth_injustice_app/complementary_hours/data/services/i_complementary_hours_service.dart';
import 'package:autth_injustice_app/complementary_hours/domain/complementary_hours_types.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_summary.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';

class ComplementaryHoursFirestoreService implements IComplementaryHoursService {
  final FirebaseFirestore _firestore;
  final InstitutionPackage _institutionPackage;

  ComplementaryHoursFirestoreService({
    FirebaseFirestore? firestore,
    required InstitutionPackage institutionPackage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _institutionPackage = institutionPackage;

  CollectionReference<Map<String, dynamic>> _records(String uid) {
    return _firestore
        .collection('accounts')
        .doc(uid)
        .collection('personalActivityRecords');
  }

  @override
  Future<ComplementaryHoursSummaryResult> getSummary(String uid) async {
    try {
      final snapshot = await _records(uid).get();
      final completedMinutes = snapshot.docs.fold<int>(0, (total, doc) {
        final minutes = doc.data()['durationMinutes'];
        return total + (minutes is int ? minutes : 0);
      });

      return Success(ComplementaryHoursSummary(
        completedMinutes: completedMinutes,
        targetMinutes: _institutionPackage.complementaryHours.targetMinutes,
        milestoneMinutes:
            _institutionPackage.complementaryHours.milestoneMinutes,
      ));
    } on FirebaseException {
      return Error(RemoteFailure('complementaryHoursLoadError'));
    } catch (_) {
      return Error(RemoteFailure('complementaryHoursLoadError'));
    }
  }

  @override
  Future<ComplementaryHoursRecordsResult> getRecords(String uid) async {
    try {
      final snapshot =
          await _records(uid).orderBy('eventDate', descending: true).get();
      final records =
          snapshot.docs.map(ComplementaryHoursFirestoreMapper.fromSnapshot);

      return Success(List.unmodifiable(records));
    } on FirebaseException {
      return Error(RemoteFailure('complementaryHoursLoadError'));
    } catch (_) {
      return Error(RemoteFailure('complementaryHoursLoadError'));
    }
  }

  @override
  Future<ComplementaryHoursRecordActionResult> deleteRecord(
    String uid,
    String recordId,
  ) async {
    try {
      final ref = _records(uid).doc(recordId);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        return Error(NotFoundFailure('complementaryHoursRecordNotFound'));
      }

      await ref.delete();
      return const Success(null);
    } on FirebaseException {
      return Error(RemoteFailure('complementaryHoursDeleteError'));
    } catch (_) {
      return Error(RemoteFailure('complementaryHoursDeleteError'));
    }
  }
}
