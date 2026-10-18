import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';

abstract interface class IEmailVerificationFacade {
  Future<EmailVerificationStatusResult> getStatus(
    EmailVerificationParams params,
  );

  Future<EmailVerificationActionResult> resend(
    EmailVerificationParams params,
  );

  Future<EmailVerificationActionResult> cancel(EmailVerificationParams params);
}
