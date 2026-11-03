import 'package:autth_injustice_app/settings/domain/account_security_types.dart';

abstract interface class IAccountSecurityService {
  AccountCredentialInfo get credentialInfo;

  Future<AccountSecurityResult> changePassword(ChangePasswordParams params);

  Future<AccountSecurityResult> requestEmailChange(
    RequestEmailChangeParams params,
  );

  Future<AccountSecurityResult> deleteAccount(DeleteAccountParams params);
}