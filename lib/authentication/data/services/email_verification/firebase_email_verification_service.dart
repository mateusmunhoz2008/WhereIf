import 'package:autth_injustice_app/authentication/data/services/email_verification/i_email_verification_service.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/i_auth_service.dart';
import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Cobre `register` e `changeEmail` via polling nativo do Firebase Auth
/// (`reload()` + `emailVerified`/`email`). O fluxo `forgotPassword` não é
/// suportado por este adaptador (fora de escopo por enquanto).
///
/// No fluxo `register`, quando o e-mail é confirmado este serviço pede ao
/// [IAuthService] para ativar a sessão (cria o documento `/accounts/{uid}`).
class FirebaseEmailVerificationService implements IEmailVerificationService {
  final fb.FirebaseAuth _firebaseAuth;
  final IAuthService _authService;

  FirebaseEmailVerificationService({
    fb.FirebaseAuth? firebaseAuth,
    required IAuthService authService,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _authService = authService;

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
      await user.reload().timeout(const Duration(seconds: 8));
    } on fb.FirebaseAuthException catch (error) {
      if (error.code == 'user-token-expired' ||
          error.code == 'user-not-found') {
        return const Success(
          EmailVerificationCheck(status: EmailVerificationStatus.expired),
        );
      }
      return Error(RemoteFailure('emailVerificationCheckFailed'));
    } catch (_) {
      return Error(RemoteFailure('emailVerificationCheckFailed'));
    }

    final refreshed = _firebaseAuth.currentUser;
    if (refreshed == null || refreshed.uid != user.uid) {
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

    if (confirmed && params.flow == EmailVerificationFlow.register) {
      await _authService.initSession();
      if (_authService.currentSession == null) {
        // Verificou, mas não conseguiu abrir a sessão (ex.: Firestore
        // indisponível). O botão "tentar novamente" da tela repete este passo.
        return Error(RemoteFailure('accountLoadError'));
      }
    }

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
          await user
              .sendEmailVerification()
              .timeout(const Duration(seconds: 8));
          return const Success(null);

        case EmailVerificationFlow.changeEmail:
          await user
              .verifyBeforeUpdateEmail(params.email)
              .timeout(const Duration(seconds: 8));
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

  /// Abandona um cadastro não verificado, removendo o usuário do Firebase
  /// Auth. Nunca remove uma conta que já confirmou o e-mail.
  @override
  Future<EmailVerificationActionResult> cancel(
    EmailVerificationParams params,
  ) async {
    if (params.flow != EmailVerificationFlow.register) {
      return const Success(null);
    }

    final user = _firebaseAuth.currentUser;
    if (user == null) return const Success(null);

    try {
      await user.reload().timeout(const Duration(seconds: 8));
      final current = _firebaseAuth.currentUser;
      if (current == null ||
          current.emailVerified ||
          current.email?.toLowerCase() != params.email.toLowerCase()) {
        return const Success(null);
      }
      await current.delete().timeout(const Duration(seconds: 8));
      return const Success(null);
    } catch (_) {
      try {
        await _firebaseAuth.signOut();
      } catch (_) {}
      return Error(DefaultFailure('authUnexpectedError'));
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
