import 'package:autth_injustice_app/settings/domain/account_security_types.dart';

abstract interface class IAccountSecurityRepository {
  Future<AccountSecurityResult> changePassword(ChangePasswordParams params);

  Future<AccountSecurityResult> requestEmailChange(
    RequestEmailChangeParams params,
  );

  AccountCredentialInfo get credentialInfo;
  Future<AccountSecurityResult> deleteAccount(DeleteAccountParams params);
}
