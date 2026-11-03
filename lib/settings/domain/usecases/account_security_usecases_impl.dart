import 'package:autth_injustice_app/settings/data/repositories/i_account_security_repository.dart';
import 'package:autth_injustice_app/settings/domain/account_security_types.dart';
import 'package:autth_injustice_app/settings/domain/usecases/i_account_security_usecases.dart';

final class ChangePasswordUseCase implements IChangePasswordUseCase {
  final IAccountSecurityRepository _repository;

  const ChangePasswordUseCase({
    required IAccountSecurityRepository accountSecurityRepository,
  }) : _repository = accountSecurityRepository;

  @override
  Future<AccountSecurityResult> call(ChangePasswordParams params) {
    return _repository.changePassword(params);
  }
}

final class RequestEmailChangeUseCase implements IRequestEmailChangeUseCase {
  final IAccountSecurityRepository _repository;

  const RequestEmailChangeUseCase({
    required IAccountSecurityRepository accountSecurityRepository,
  }) : _repository = accountSecurityRepository;

  @override
  Future<AccountSecurityResult> call(RequestEmailChangeParams params) {
    return _repository.requestEmailChange(params);
  }
}

final class PermanentlyDeleteAccountUseCase
    implements IPermanentlyDeleteAccountUseCase {
  final IAccountSecurityRepository _repository;

  const PermanentlyDeleteAccountUseCase({
    required IAccountSecurityRepository accountSecurityRepository,
  }) : _repository = accountSecurityRepository;

  @override
  Future<AccountSecurityResult> call(DeleteAccountParams params) {
    return _repository.deleteAccount(params);
  }
}
