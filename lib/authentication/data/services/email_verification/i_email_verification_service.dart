import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';

/// Backend boundary for the screen that waits for an email action.
///
/// The flow that opens the screen informs whether it already sent the first
/// link. Otherwise the screen calls [resend] once before monitoring. A real
/// adapter must map each flow to the correct backend operation:
/// registration verification, password recovery, or email change.
///
/// A production implementation must return stable error keys, never raw
/// Firebase or HTTP messages. The UI translates those keys through l10n.
abstract interface class IEmailVerificationService {
  Future<EmailVerificationStatusResult> getStatus(
    EmailVerificationParams params,
  );

  Future<EmailVerificationActionResult> resend(
    EmailVerificationParams params,
  );

  /// Abandona um cadastro não verificado, removendo o usuário do provedor.
  /// Nunca remove uma conta que já confirmou o e-mail.
  Future<EmailVerificationActionResult> cancel(EmailVerificationParams params);
}
