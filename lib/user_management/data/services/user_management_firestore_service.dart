import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/account/data/mappers/account_firestore_mapper.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/complementary_hours/data/mappers/complementary_hours_firestore_mapper.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_summary.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/user_management/data/services/i_user_management_service.dart';
import 'package:autth_injustice_app/user_management/domain/models/managed_user_details.dart';
import 'package:autth_injustice_app/user_management/domain/models/user_directory_entry.dart';
import 'package:autth_injustice_app/user_management/domain/user_management_types.dart';

class UserManagementFirestoreService implements IUserManagementService {
  final FirebaseFirestore _firestore;
  final InstitutionPackage _institutionPackage;

  UserManagementFirestoreService({
    FirebaseFirestore? firestore,
    required InstitutionPackage institutionPackage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _institutionPackage = institutionPackage;

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _firestore.collection('accounts');

  @override
  Future<UserDirectoryResult> getUsers(String actorUid) async {
    try {
      final snapshot = await _accounts.get();
      final entries = snapshot.docs.map(_entryFromSnapshot).toList();
      return Success(List.unmodifiable(entries));
    } on FirebaseException catch (error) {
      return Error(_mapFailure(error, fallbackKey: 'userManagementLoadError'));
    } catch (_) {
      return Error(RemoteFailure('userManagementLoadError'));
    }
  }

  @override
  Future<ManagedUserDetailsResult> getUserDetails(
    String actorUid,
    String userId,
  ) async {
    try {
      final accountSnapshot = await _accounts.doc(userId).get();
      if (!accountSnapshot.exists) {
        return Error(NotFoundFailure('userDetailsNotFound'));
      }

      final recordsSnapshot = await _accounts
          .doc(userId)
          .collection('personalActivityRecords')
          .orderBy('eventDate', descending: true)
          .get();

      final records = recordsSnapshot.docs
          .map(ComplementaryHoursFirestoreMapper.fromSnapshot)
          .toList();
      final entry = _entryFromSnapshot(accountSnapshot);

      return Success(ManagedUserDetails(
        user: entry,
        hoursSummary: ComplementaryHoursSummary(
          completedMinutes: entry.totalComplementaryMinutes,
          targetMinutes: _institutionPackage.complementaryHours.targetMinutes,
          milestoneMinutes:
              _institutionPackage.complementaryHours.milestoneMinutes,
        ),
        records: records,
      ));
    } on FirebaseException catch (error) {
      return Error(_mapFailure(error, fallbackKey: 'userDetailsLoadError'));
    } catch (_) {
      return Error(RemoteFailure('userDetailsLoadError'));
    }
  }

  @override
  Future<ManagedUserRoleResult> updateUserRole(
    String actorUid,
    String userId,
    AccountRole role,
  ) async {
    if (actorUid == userId) {
      return Error(InvalidInputFailure('userDetailsRoleChangeError'));
    }
    if (role != AccountRole.student && role != AccountRole.eventManager) {
      return Error(InvalidInputFailure('userDetailsInvalidRole'));
    }

    try {
      final docRef = _accounts.doc(userId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        return Error(NotFoundFailure('userDetailsNotFound'));
      }

      final current = _entryFromSnapshot(snapshot);
      if (current.account.role == AccountRole.administrator) {
        return Error(InvalidInputFailure('userDetailsRoleChangeError'));
      }

      await docRef.update({
        'role': role.name,
        'updatedAt': Timestamp.now(),
      });

      return Success(current.copyWith(
        account: current.account.copyWith(role: role),
      ));
    } on FirebaseException catch (error) {
      return Error(
        _mapFailure(error, fallbackKey: 'userDetailsRoleChangeError'),
      );
    } catch (_) {
      return Error(RemoteFailure('userDetailsRoleChangeError'));
    }
  }

  UserDirectoryEntry _entryFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final account = AccountFirestoreMapper.fromSnapshot(snapshot);
    final rawMinutes = snapshot.data()?['totalComplementaryMinutes'];

    return UserDirectoryEntry(
      account: account,
      totalComplementaryMinutes: rawMinutes is int ? rawMinutes : 0,
    );
  }

  Failure _mapFailure(FirebaseException error, {required String fallbackKey}) {
    if (error.code == 'permission-denied') {
      return ForbiddenFailure('userManagementUnauthorized');
    }
    return RemoteFailure(fallbackKey);
  }
}