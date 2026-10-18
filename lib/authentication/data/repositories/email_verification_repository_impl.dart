import 'package:autth_injustice_app/authentication/data/repositories/i_email_verification_repository.dart';
import 'package:autth_injustice_app/authentication/data/services/email_verification/i_email_verification_service.dart';
import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';

class EmailVerificationRepositoryImpl implements IEmailVerificationRepository {
  final IEmailVerificationService _service;

  const EmailVerificationRepositoryImpl({
    required IEmailVerificationService emailVerificationService,
  }) : _service = emailVerificationService;

  @override
  Future<EmailVerificationStatusResult> getStatus(
    EmailVerificationParams params,
  ) {
    return _service.getStatus(params);
  }

  @override
  Future<EmailVerificationActionResult> resend(
    EmailVerificationParams params,
  ) {
    return _service.resend(params);
  }

  @override
  Future<EmailVerificationActionResult> cancel(EmailVerificationParams params) {
    return _service.cancel(params);
  }
}
