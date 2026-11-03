import 'package:autth_injustice_app/core/patterns/i_usecases.dart';
import 'package:autth_injustice_app/settings/domain/account_security_types.dart';

abstract interface class IChangePasswordUseCase
    implements IUseCase<AccountSecurityResult, ChangePasswordParams> {}

abstract interface class IRequestEmailChangeUseCase
    implements IUseCase<AccountSecurityResult, RequestEmailChangeParams> {}

abstract interface class IPermanentlyDeleteAccountUseCase
    implements IUseCase<AccountSecurityResult, DeleteAccountParams> {}