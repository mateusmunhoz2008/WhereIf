import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_email_verification_facade.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/i_email_verification_usecases.dart';

class EmailVerificationFacadeImpl implements IEmailVerificationFacade {
  final IGetEmailVerificationStatusUseCase _getStatusUseCase;
  final IResendEmailVerificationUseCase _resendUseCase;
  final ICancelEmailVerificationUseCase _cancelUseCase;

  const EmailVerificationFacadeImpl({
    required IGetEmailVerificationStatusUseCase
        getEmailVerificationStatusUseCase,
    required IResendEmailVerificationUseCase resendEmailVerificationUseCase,
    required ICancelEmailVerificationUseCase cancelEmailVerificationUseCase,
  })  : _getStatusUseCase = getEmailVerificationStatusUseCase,
        _resendUseCase = resendEmailVerificationUseCase,
        _cancelUseCase = cancelEmailVerificationUseCase;

  @override
  Future<EmailVerificationStatusResult> getStatus(
    EmailVerificationParams params,
  ) {
    return _getStatusUseCase(params);
  }

  @override
  Future<EmailVerificationActionResult> resend(
    EmailVerificationParams params,
  ) {
    return _resendUseCase(params);
  }

  @override
  Future<EmailVerificationActionResult> cancel(
    EmailVerificationParams params,
  ) {
    return _cancelUseCase(params);
  }
}