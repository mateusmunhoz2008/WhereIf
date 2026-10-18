import 'package:autth_injustice_app/authentication/data/services/email_verification/i_email_verification_service.dart';
import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';

/// Fails explicitly until the backend implements email action links.
class UnconfiguredEmailVerificationService
    implements IEmailVerificationService {
  @override
  Future<EmailVerificationStatusResult> getStatus(
    EmailVerificationParams params,
  ) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }

  @override
  Future<EmailVerificationActionResult> resend(
    EmailVerificationParams params,
  ) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }

  @override
  Future<EmailVerificationActionResult> cancel(
    EmailVerificationParams params,
  ) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }
}
