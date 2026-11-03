import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';

typedef AccountSecurityResult = Result<void, Failure>;

typedef ChangePasswordParams = ({
  String currentPassword,
  String newPassword,
});

typedef RequestEmailChangeParams = ({
  String currentPassword,
  String newEmail,
});

typedef DeleteAccountParams = ({String? currentPassword});

class AccountCredentialInfo {
  final bool hasPassword;
  final bool hasGoogle;

  const AccountCredentialInfo({
    required this.hasPassword,
    required this.hasGoogle,
  });

  bool get isGoogleOnly => hasGoogle && !hasPassword;
}