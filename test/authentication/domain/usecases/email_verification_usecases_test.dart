import 'package:autth_injustice_app/authentication/data/repositories/i_email_verification_repository.dart';
import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/email_verification_usecases_impl.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeEmailVerificationRepository repository;

  setUp(() {
    repository = _FakeEmailVerificationRepository();
  });

  test('normalizes the email before checking backend status', () async {
    final useCase = GetEmailVerificationStatusUseCase(
      emailVerificationRepository: repository,
    );

    final result = await useCase((
      email: '  STUDENT@IFPR.EDU.BR ',
      flow: EmailVerificationFlow.register,
    ));

    expect(
      result.successValueOrNull?.status,
      EmailVerificationStatus.pending,
    );
    expect(repository.lastStatusParams?.email, 'student@ifpr.edu.br');
  });

  test('rejects an invalid email before reaching the backend', () async {
    final useCase = ResendEmailVerificationUseCase(
      emailVerificationRepository: repository,
    );

    final result = await useCase((
      email: 'invalid-email',
      flow: EmailVerificationFlow.forgotPassword,
    ));

    expect(result.failureValueOrNull, isA<InvalidInputFailure>());
    expect(repository.resendCalls, 0);
  });
}

class _FakeEmailVerificationRepository implements IEmailVerificationRepository {
  EmailVerificationParams? lastStatusParams;
  int resendCalls = 0;

  @override
  Future<EmailVerificationStatusResult> getStatus(
    EmailVerificationParams params,
  ) async {
    lastStatusParams = params;
    return const Success(
      EmailVerificationCheck(status: EmailVerificationStatus.pending),
    );
  }

  @override
  Future<EmailVerificationActionResult> resend(
    EmailVerificationParams params,
  ) async {
    resendCalls++;
    return const Success(null);
  }

  @override
  Future<EmailVerificationActionResult> cancel(
    EmailVerificationParams params,
  ) async {
    return const Success(null);
  }
}
