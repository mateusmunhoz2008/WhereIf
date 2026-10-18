import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/core/patterns/i_usecases.dart';

abstract interface class IGetEmailVerificationStatusUseCase
    implements
        IUseCase<EmailVerificationStatusResult, EmailVerificationParams> {}

abstract interface class IResendEmailVerificationUseCase
    implements
        IUseCase<EmailVerificationActionResult, EmailVerificationParams> {}

abstract interface class ICancelEmailVerificationUseCase
    implements
        IUseCase<EmailVerificationActionResult, EmailVerificationParams> {}