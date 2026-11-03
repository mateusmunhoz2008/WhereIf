import 'package:autth_injustice_app/settings/data/repositories/i_account_security_repository.dart';
import 'package:autth_injustice_app/settings/data/services/i_account_security_service.dart';
import 'package:autth_injustice_app/settings/domain/account_security_types.dart';

class AccountSecurityRepositoryImpl implements IAccountSecurityRepository {
  final IAccountSecurityService _service;

  const AccountSecurityRepositoryImpl({
    required IAccountSecurityService accountSecurityService,
  }) : _service = accountSecurityService;

  @override
  Future<AccountSecurityResult> changePassword(ChangePasswordParams params) {
    return _service.changePassword(params);
  }

  @override
  Future<AccountSecurityResult> requestEmailChange(
    RequestEmailChangeParams params,
  ) {
    return _service.requestEmailChange(params);
  }

  @override
  AccountCredentialInfo get credentialInfo => _service.credentialInfo;

  @override
  Future<AccountSecurityResult> deleteAccount(DeleteAccountParams params) {
    return _service.deleteAccount(params);
  }
}
