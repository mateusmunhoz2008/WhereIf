import 'package:autth_injustice_app/settings/data/repositories/i_account_security_repository.dart';
import 'package:autth_injustice_app/settings/domain/account_security_types.dart';
import 'package:autth_injustice_app/settings/domain/facades/i_account_security_facade.dart';
import 'package:autth_injustice_app/settings/domain/usecases/i_account_security_usecases.dart';

class AccountSecurityFacadeImpl implements IAccountSecurityFacade {
  final IChangePasswordUseCase _changePasswordUseCase;
  final IRequestEmailChangeUseCase _requestEmailChangeUseCase;
  final IPermanentlyDeleteAccountUseCase _deleteAccountUseCase;
  final IAccountSecurityRepository _repository;

  const AccountSecurityFacadeImpl({
    required IChangePasswordUseCase changePasswordUseCase,
    required IRequestEmailChangeUseCase requestEmailChangeUseCase,
    required IPermanentlyDeleteAccountUseCase permanentlyDeleteAccountUseCase,
    required IAccountSecurityRepository accountSecurityRepository,
  })  : _changePasswordUseCase = changePasswordUseCase,
        _requestEmailChangeUseCase = requestEmailChangeUseCase,
        _deleteAccountUseCase = permanentlyDeleteAccountUseCase,
        _repository = accountSecurityRepository;

  @override
  AccountCredentialInfo get credentialInfo => _repository.credentialInfo;

  @override
  Future<AccountSecurityResult> changePassword(ChangePasswordParams params) {
    return _changePasswordUseCase(params);
  }

  @override
  Future<AccountSecurityResult> requestEmailChange(
    RequestEmailChangeParams params,
  ) {
    return _requestEmailChangeUseCase(params);
  }

  @override
  Future<AccountSecurityResult> deleteAccount(DeleteAccountParams params) {
    return _deleteAccountUseCase(params);
  }
}