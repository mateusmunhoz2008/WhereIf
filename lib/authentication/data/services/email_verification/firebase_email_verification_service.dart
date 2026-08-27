import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:autth_injustice_app/authentication/data/services/email_verification/i_email_verification_service.dart';
import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';

//Precisa ainda fazer a redefinição de senha, confirmaçaõ de email por link e troca de email
class FirebaseEmailVerificationService implements IEmailVerificationService {
  final fb.FirebaseAuth _firebaseAuth;

  FirebaseEmailVerificationService({fb.FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  @override
  Future<EmailVerificationStatusResult> getStatus(
    EmailVerificationParams params,
  ) async {
    if (params.flow == EmailVerificationFlow.forgotPassword) {
      return Error(RemoteFailure('authBackendUnavailable'));
    }

    final user = _firebaseAuth.currentUser;
    if (user == null) return Error(RemoteFailure('authUserNotFound'));

    try {
      await user.reload();
    } on fb.FirebaseAuthException catch (error) {
      if (error.code == 'user-token-expired' || error.code == 'user-not-found') {
        return const Success(
          EmailVerificationCheck(status: EmailVerificationStatus.expired),
        );
      }
      return Error(RemoteFailure('emailVerificationCheckFailed'));
    } catch (_) {
      return Error(RemoteFailure('emailVerificationCheckFailed'));
    }

    final refreshed = _firebaseAuth.currentUser;
    if (refreshed == null) {
      return const Success(
        EmailVerificationCheck(status: EmailVerificationStatus.expired),
      );
    }

    final confirmed = switch (params.flow) {
      EmailVerificationFlow.register => refreshed.emailVerified,
      EmailVerificationFlow.changeEmail =>
        refreshed.email?.toLowerCase() == params.email.toLowerCase(),
      EmailVerificationFlow.forgotPassword => false,
    };

    return Success(
      EmailVerificationCheck(
        status: confirmed
            ? EmailVerificationStatus.confirmed
            : EmailVerificationStatus.pending,
      ),
    );
  }

  @override
  Future<EmailVerificationActionResult> resend(
    EmailVerificationParams params,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return Error(RemoteFailure('authUserNotFound'));

    try {
      switch (params.flow) {
        case EmailVerificationFlow.register:
          if (user.emailVerified) return const Success(null);
          await user.sendEmailVerification();
          return const Success(null);

        case EmailVerificationFlow.changeEmail:
          await user.verifyBeforeUpdateEmail(params.email);
          return const Success(null);

        case EmailVerificationFlow.forgotPassword:
          return Error(RemoteFailure('authBackendUnavailable'));
      }
    } on fb.FirebaseAuthException catch (error) {
      return Error(_mapFailure(error));
    } catch (_) {
      return Error(RemoteFailure('emailVerificationResendFailed'));
    }
  }

  Failure _mapFailure(fb.FirebaseAuthException error) {
    return switch (error.code) {
      'too-many-requests' => DefaultFailure('authTooManyRequests'),
      'network-request-failed' => DefaultFailure('authNetworkError'),
      'requires-recent-login' => DefaultFailure('authRequiresRecentLogin'),
      _ => DefaultFailure('emailVerificationResendFailed'),
    };
  }
}