import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/settings/data/services/i_account_security_service.dart';
import 'package:autth_injustice_app/settings/domain/account_security_types.dart';

/// Safe placeholder for credential changes while the backend is pending.
class UnconfiguredAccountSecurityService implements IAccountSecurityService {
  @override
  Future<AccountSecurityResult> changePassword(
    ChangePasswordParams params,
  ) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }

  @override
  Future<AccountSecurityResult> requestEmailChange(
    RequestEmailChangeParams params,
  ) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }

  @override
  AccountCredentialInfo get credentialInfo =>
      const AccountCredentialInfo(hasPassword: false, hasGoogle: false);

  @override
  Future<AccountSecurityResult> deleteAccount(
      DeleteAccountParams params) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }
}
