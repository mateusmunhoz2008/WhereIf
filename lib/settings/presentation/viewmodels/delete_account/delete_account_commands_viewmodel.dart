import 'package:autth_injustice_app/settings/domain/facades/i_account_security_facade.dart';

import 'delete_account_state_viewmodel.dart';

class DeleteAccountCommands {
  final DeleteAccountState state;
  final IAccountSecurityFacade _facade;

  DeleteAccountCommands({
    required this.state,
    required IAccountSecurityFacade accountSecurityFacade,
  }) : _facade = accountSecurityFacade;

  Future<bool> deleteAccount({String? currentPassword}) async {
    if (state.loading.value) return false;

    state
      ..setLoading(true)
      ..clearError();

    try {
      final result = await _facade.deleteAccount(
        (currentPassword: currentPassword),
      );
      return result.fold(
        onSuccess: (_) => true,
        onFailure: (failure) {
          state.setError(failure.msg);
          return false;
        },
      );
    } catch (_) {
      state.setError('authUnexpectedError');
      return false;
    } finally {
      state.setLoading(false);
    }
  }
}