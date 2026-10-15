import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

extension AppLocalizationsErrorExt on BuildContext {
  String translateErrorKey(String key) {
    final l10n = AppLocalizations.of(this);
    if (l10n == null) return key;

    switch (key) {
      case 'accountLoadError':
      case 'connectionRequired':
        return l10n.connectionRequired;
      case 'networkWritePending':
        return l10n.networkWritePending;
      case 'networkWriteUnconfirmed':
        return l10n.networkWriteUnconfirmed;
      // Campos de login
      case 'fieldsRequired':
        return l10n.fieldsRequired;
      case 'invalidFields':
        return l10n.invalidFields;
      case 'authEmailAlreadyInUse':
        return l10n.authEmailAlreadyInUse;
      case 'authWeakPassword':
        return l10n.authWeakPassword;
      case 'authNetworkError':
        return l10n.authNetworkError;
      case 'authTooManyRequests':
        return l10n.authTooManyRequests;
      case 'authAccountDisabled':
        return l10n.authAccountDisabled;
      case 'authUnexpectedError':
        return l10n.authUnexpectedError;
      case 'authBackendUnavailable':
        return l10n.authBackendUnavailable;
      case 'authUserNotFound':
        return l10n.authUserNotFound;
      case 'authGoogleCanceled':
        return l10n.authGoogleCanceled;

      // Validação de e-mail
      case 'emailRequired':
        return l10n.emailRequired;
      case 'invalidEmail':
        return l10n.invalidEmail;

      case 'accountInvalidFullName':
        return l10n.accountInvalidFullName;

      // Verificação de e-mail
      case 'emailVerificationExpired':
        return l10n.emailVerificationExpired;
      case 'emailVerificationUnexpectedError':
        return l10n.emailVerificationUnexpectedError;
      case 'emailVerificationResendFailed':
        return l10n.emailVerificationResendFailed;
      case 'passwordResetMismatch':
        return l10n.passwordResetMismatch;
      case 'passwordResetInvalidLink':
        return l10n.passwordResetInvalidLink;
      case 'passwordResetFailed':
        return l10n.passwordResetFailed;

      // Validação de senha
      case 'passwordRequired':
        return l10n.passwordRequired;
      case 'passwordMinLength':
        return l10n.passwordMinLength;
      case 'passwordRequireLowercaseAndUppercase':
        return l10n.passwordRequireLowercaseAndUppercase;
      case 'passwordRequireNumber':
        return l10n.passwordRequireNumber;
      case 'passwordRequireSymbol':
        return l10n.passwordRequireSymbol;

      // Níveis de força de senha
      case 'passwordStrengthEmpty':
        return l10n.passwordStrengthEmpty;
      case 'passwordStrengthVeryWeak':
        return l10n.passwordStrengthVeryWeak;
      case 'passwordStrengthWeak':
        return l10n.passwordStrengthWeak;
      case 'passwordStrengthFair':
        return l10n.passwordStrengthFair;
      case 'passwordStrengthGood':
        return l10n.passwordStrengthGood;
      case 'passwordStrengthExcellent':
        return l10n.passwordStrengthExcellent;

      default:
        return key;
    }
  }
}
