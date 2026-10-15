import 'package:autth_injustice_app/authentication/presentation/commands/auth_commands.dart';
import 'package:autth_injustice_app/authentication/domain/services/login_attempt.dart';

import 'login_state_viewmodel.dart';

class LoginCommands {
  final LoginState state;

  final SignInCommand _signInCommand;
  final SignInWithGoogleCommand _signInWithGoogleCommand;
  LoginAttempt? _attempt;

  void cancel() {
    _attempt?.cancel();
    _attempt = null;
    state.setLoading(false);
    state.clearError();
  }

  LoginCommands({
    required this.state,
    required SignInCommand signInCommand,
    required SignInWithGoogleCommand signInWithGoogleCommand,
  })  : _signInCommand = signInCommand,
        _signInWithGoogleCommand = signInWithGoogleCommand;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (state.loading.value) return false;
    final attempt = _attempt = LoginAttempt.begin();
    state.setLoading(true);
    state.clearError();

    try {
      final result = await _signInCommand.executeWith((
        email: email,
        password: password,
      ));

      if (attempt.cancelled) {
        if (identical(_attempt, attempt) && attempt.timedOut) {
          state.showError('connectionRequired');
        }
        return false;
      }

      return result.fold(
        onSuccess: (_) => true,
        onFailure: (failure) {
          state.showError(failure.msg);
          return false;
        },
      );
    } catch (_) {
      if (!attempt.cancelled) state.showError('authUnexpectedError');
      return false;
    } finally {
      if (identical(_attempt, attempt)) state.setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    if (state.loading.value) return false;
    final attempt = _attempt = LoginAttempt.begin();
    state.setLoading(true);
    state.clearError();

    try {
      final result = await _signInWithGoogleCommand.executeWith(());
      if (attempt.cancelled) {
        if (identical(_attempt, attempt) && attempt.timedOut) {
          state.showError('connectionRequired');
        }
        return false;
      }
      return result.fold(
        onSuccess: (_) => true,
        onFailure: (failure) {
          state.showError(failure.msg);
          return false;
        },
      );
    } catch (_) {
      if (!attempt.cancelled) state.showError('authUnexpectedError');
      return false;
    } finally {
      if (identical(_attempt, attempt)) state.setLoading(false);
    }
  }
}
