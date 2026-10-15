import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_email_verification_facade.dart';

import 'check_email_state_viewmodel.dart';

class CheckEmailCommands {
  static const pollingInterval = Duration(milliseconds: 750);

  final CheckEmailState state;
  final IEmailVerificationFacade _facade;
  int _monitorGeneration = 0;

  CheckEmailCommands({
    required this.state,
    required IEmailVerificationFacade emailVerificationFacade,
  }) : _facade = emailVerificationFacade;

  Future<void> waitForConfirmation({
    required String email,
    required EmailVerificationFlow flow,
  }) async {
    if (state.loading.value || state.confirmed.value) return;

    final generation = ++_monitorGeneration;
    final params = (email: email, flow: flow);

    state
      ..setLoading(true)
      ..clearError();

    try {
      while (generation == _monitorGeneration && !state.confirmed.value) {
        final result = await _facade.getStatus(params);
        if (generation != _monitorGeneration) return;

        final shouldContinue = result.fold(
          onSuccess: (verification) {
            switch (verification.status) {
              case EmailVerificationStatus.pending:
                return true;
              case EmailVerificationStatus.confirmed:
                state.setConfirmation(
                  value: true,
                  actionCode: verification.actionCode,
                );
                return false;
              case EmailVerificationStatus.expired:
                state.showError('emailVerificationExpired');
                return false;
            }
          },
          onFailure: (failure) {
            state.showError(failure.msg);
            return false;
          },
        );

        if (!shouldContinue) return;
        await Future<void>.delayed(pollingInterval);
      }
    } catch (_) {
      if (generation == _monitorGeneration) {
        state.showError('emailVerificationUnexpectedError');
      }
    } finally {
      if (generation == _monitorGeneration) {
        state.setLoading(false);
      }
    }
  }

  Future<bool> resend({
    required String email,
    required EmailVerificationFlow flow,
  }) async {
    if (state.resending.value || state.confirmed.value) return false;

    state
      ..setResending(true)
      ..clearError();
    final generation = _monitorGeneration;

    try {
      final result = await _facade.resend((email: email, flow: flow));
      if (generation != _monitorGeneration) return false;
      return result.fold(
        onSuccess: (_) => true,
        onFailure: (failure) {
          state.showError(failure.msg);
          return false;
        },
      );
    } catch (_) {
      if (generation == _monitorGeneration) {
        state.showError('emailVerificationResendFailed');
      }
      return false;
    } finally {
      if (generation == _monitorGeneration) state.setResending(false);
    }
  }

  void cancelMonitoring() {
    _monitorGeneration++;
    state.setLoading(false);
    state.setResending(false);
  }
}
