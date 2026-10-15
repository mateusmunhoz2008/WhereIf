import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/core/network/firestore_access.dart';

import 'package:autth_injustice_app/account/data/mappers/account_firestore_mapper.dart';
import 'package:autth_injustice_app/account/data/services/i_account_remote_storage.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';

final class AccountFirestoreService implements IAccountRemoteStorage {
  final FirebaseFirestore _firestore;

  AccountFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _accountDoc(String uid) =>
      _firestore.collection('accounts').doc(uid);

  @override
  Future<AccountResult> getAccount(String uid) async {
    try {
      final snapshot = await FirestoreAccess.document(_accountDoc(uid));
      if (!snapshot.exists) {
        return Error(NotFoundFailure('accountNotFound'));
      }

      return Success(AccountFirestoreMapper.fromSnapshot(snapshot));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return Error(ForbiddenFailure('accountLoadError'));
      }
      return Error(RemoteFailure('accountLoadError'));
    } catch (_) {
      return Error(RemoteFailure('accountLoadError'));
    }
  }

  @override
  Future<VoidResult> saveAccount(Account account) async {
    try {
      final reference = _accountDoc(account.uid);
      await _firestore.runTransaction<Account>((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) {
          return AccountFirestoreMapper.fromSnapshot(existing);
        }
        transaction.set(reference, AccountFirestoreMapper.toMap(account));
        return account;
      }, timeout: FirestoreAccess.deadline).timeout(FirestoreAccess.deadline);
      return const Success(null);
    } on FirebaseException {
      return Error(RemoteFailure('accountSaveError'));
    } catch (_) {
      return Error(RemoteFailure('accountSaveError'));
    }
  }

  @override
  Future<VoidResult> updateAccount(Account account) async {
    try {
      await _accountDoc(account.uid)
          .update(
            AccountFirestoreMapper.toProfileUpdateMap(account),
          )
          .timeout(FirestoreAccess.deadline);
      return const Success(null);
    } on FirebaseException {
      return Error(RemoteFailure('accountUpdateError'));
    } catch (_) {
      return Error(RemoteFailure('accountUpdateError'));
    }
  }

  @override
  Future<VoidResult> deleteAccount(String uid) async {
    try {
      await _accountDoc(uid).delete().timeout(FirestoreAccess.deadline);
      return const Success(null);
    } on FirebaseException {
      return Error(RemoteFailure('accountDeleteError'));
    } catch (_) {
      return Error(RemoteFailure('accountDeleteError'));
    }
  }
}
