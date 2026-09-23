import 'package:autth_injustice_app/account/data/repositories/i_account_repository.dart';
import 'package:autth_injustice_app/account/data/services/i_account_remote_storage.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';

final class AccountRepositoryImpl implements IAccountRepository {
  final IAccountRemoteStorage _remoteStorage;
  final IAuthRepository _authRepository;

  AccountRepositoryImpl({
    required IAccountRemoteStorage remoteStorage,
    required IAuthRepository authRepository,
  })  : _remoteStorage = remoteStorage,
        _authRepository = authRepository;

  String? get _currentUid => _authRepository.currentSession?.account.uid;

  Failure get _unauthError => UnauthenticatedFailure();

  Failure? _validateAccountOwner(Account account) {
    final uid = _currentUid;
    if (uid == null) return _unauthError;
    if (uid != account.uid) {
      return InvalidInputFailure('accountOwnerMismatch');
    }
    return null;
  }

  @override
  Future<AccountResult> getAccount() async {
    final uid = _currentUid;
    if (uid == null) return Error(_unauthError);
    return _remoteStorage.getAccount(uid);
  }

  @override
  Future<VoidResult> saveAccount(Account account) async {
    final failure = _validateAccountOwner(account);
    if (failure != null) return Error(failure);
    return _remoteStorage.saveAccount(account);
  }

  @override
  Future<VoidResult> updateAccount(Account account) async {
    final failure = _validateAccountOwner(account);
    if (failure != null) return Error(failure);
    return _remoteStorage.updateAccount(account);
  }

  @override
  Future<VoidResult> deleteAccount() async {
    final uid = _currentUid;
    if (uid == null) return Error(_unauthError);
    return _remoteStorage.deleteAccount(uid);
  }
}
