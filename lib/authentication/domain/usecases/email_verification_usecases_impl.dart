import 'package:autth_injustice_app/authentication/data/repositories/i_email_verification_repository.dart';
import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/i_email_verification_usecases.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';

final class GetEmailVerificationStatusUseCase
    implements IGetEmailVerificationStatusUseCase {
  final IEmailVerificationRepository _repository;

  const GetEmailVerificationStatusUseCase({
    required IEmailVerificationRepository emailVerificationRepository,
  }) : _repository = emailVerificationRepository;

  @override
  Future<EmailVerificationStatusResult> call(
    EmailVerificationParams params,
  ) {
    final normalized = _normalize(params);
    if (normalized == null) {
      return Future.value(
        Error(InvalidInputFailure('invalidEmail')),
      );
    }
    return _repository.getStatus(normalized);
  }
}

final class ResendEmailVerificationUseCase
    implements IResendEmailVerificationUseCase {
  final IEmailVerificationRepository _repository;

  const ResendEmailVerificationUseCase({
    required IEmailVerificationRepository emailVerificationRepository,
  }) : _repository = emailVerificationRepository;

  @override
  Future<EmailVerificationActionResult> call(
    EmailVerificationParams params,
  ) {
    final normalized = _normalize(params);
    if (normalized == null) {
      return Future.value(
        Error(InvalidInputFailure('invalidEmail')),
      );
    }
    return _repository.resend(normalized);
  }
}

final class CancelEmailVerificationUseCase
    implements ICancelEmailVerificationUseCase {
  final IEmailVerificationRepository _repository;

  const CancelEmailVerificationUseCase({
    required IEmailVerificationRepository emailVerificationRepository,
  }) : _repository = emailVerificationRepository;

  @override
  Future<EmailVerificationActionResult> call(EmailVerificationParams params) {
    final normalized = _normalize(params);
    if (normalized == null) {
      return Future.value(Error(InvalidInputFailure('invalidEmail')));
    }
    return _repository.cancel(normalized);
  }
}

EmailVerificationParams? _normalize(EmailVerificationParams params) {
  final email = params.email.trim().toLowerCase();
  if (email.isEmpty || !email.contains('@')) return null;
  return (email: email, flow: params.flow);
}
