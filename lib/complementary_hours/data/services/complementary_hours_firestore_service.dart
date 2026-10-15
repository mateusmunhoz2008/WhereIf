import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autth_injustice_app/core/network/firestore_access.dart';
import 'package:autth_injustice_app/complementary_hours/data/mappers/complementary_hours_firestore_mapper.dart';
import 'package:autth_injustice_app/complementary_hours/data/services/i_complementary_hours_service.dart';
import 'package:autth_injustice_app/complementary_hours/domain/complementary_hours_types.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_summary.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';

class ComplementaryHoursFirestoreService implements IComplementaryHoursService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final InstitutionPackage _institutionPackage;

  ComplementaryHoursFirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    required InstitutionPackage institutionPackage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
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
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }
      final snapshot = await FirestoreAccess.query(_records(uid));
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }
      final completedMinutes = snapshot.docs.fold<int>(0, (total, doc) {
        final minutes = doc.data()['durationMinutes'];
        return total + (minutes is int && minutes > 0 ? minutes : 0);
      });

      return Success(ComplementaryHoursSummary(
        completedMinutes: completedMinutes,
        targetMinutes: _institutionPackage.complementaryHours.targetMinutes,
        milestoneMinutes:
            _institutionPackage.complementaryHours.milestoneMinutes,
      ));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return Error(ForbiddenFailure('complementaryHoursLoadError'));
      }
      return Error(RemoteFailure('complementaryHoursLoadError'));
    } catch (_) {
      return Error(RemoteFailure('complementaryHoursLoadError'));
    }
  }

  @override
  Future<ComplementaryHoursRecordsResult> getRecords(String uid) async {
    try {
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }
      final snapshot = await FirestoreAccess.query(
          _records(uid).orderBy('eventDate', descending: true));
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }
      final records =
          snapshot.docs.map(ComplementaryHoursFirestoreMapper.fromSnapshot);

      return Success(List.unmodifiable(records));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return Error(ForbiddenFailure('complementaryHoursLoadError'));
      }
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
      final accountRef = _firestore.collection('accounts').doc(uid);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final account = await transaction.get(accountRef);
        if (_firebaseAuth.currentUser?.uid != uid) {
          throw UnauthenticatedFailure();
        }
        if (!snapshot.exists) {
          throw NotFoundFailure('complementaryHoursRecordNotFound');
        }
        final minutes = snapshot.data()?['durationMinutes'];
        final total = account.data()?['totalComplementaryMinutes'];
        if (account.exists && minutes is int && minutes > 0 && total is int) {
          final remaining = total - minutes;
          transaction.update(accountRef, {
            'totalComplementaryMinutes': remaining < 0 ? 0 : remaining,
            'updatedAt': Timestamp.now(),
          });
        }
        transaction.delete(ref);
      }).timeout(FirestoreAccess.deadline);
      return const Success(null);
    } on Failure catch (failure) {
      return Error(failure);
    } on FirebaseException {
      return Error(RemoteFailure('complementaryHoursDeleteError'));
    } catch (_) {
      return Error(RemoteFailure('complementaryHoursDeleteError'));
    }
  }
}
