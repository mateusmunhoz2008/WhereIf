import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/user_management/domain/facades/i_user_management_use_case_facade.dart';
import 'package:autth_injustice_app/user_management/presentation/commands/user_management_commands.dart';

import 'user_details_state_viewmodel.dart';

class UserDetailsCommands {
  final UserDetailsState state;
  final IUserManagementUseCaseFacade _facade;
  int _generation = 0;
  bool _disposed = false;
  String? _userId;

  UserDetailsCommands({
    required this.state,
    required IUserManagementUseCaseFacade facade,
  }) : _facade = facade;

  void resetForSession() {
    _generation++;
    _userId = null;
    state.reset();
  }

  void dispose() {
    _disposed = true;
    resetForSession();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _showFailure(Failure failure) {
    if (failure is ForbiddenFailure || failure is UnauthenticatedFailure) {
      resetForSession();
    }
    state.showError(failure.msg);
  }

  Future<void> load(String userId) async {
    if (_disposed || state.loading.value && _userId == userId) return;

    resetForSession();
    _userId = userId;
    final generation = _generation;

    state
      ..setLoading(true)
      ..clearError();
    try {
      final result = await LoadManagedUserDetailsCommand(_facade)
          .executeWith((userId: userId));
      if (!_isCurrent(generation)) return;
      result.fold(
        onSuccess: state.setDetails,
        onFailure: _showFailure,
      );
    } catch (_) {
      if (_isCurrent(generation)) state.showError('userDetailsLoadError');
    } finally {
      if (_isCurrent(generation)) state.setLoading(false);
    }
  }

  Future<bool> updateRole(AccountRole role) async {
    final details = state.details.value;
    if (_disposed || details == null || state.updatingRole.value) return false;
    if (details.user.account.role == role) return true;

    state
      ..setUpdatingRole(role)
      ..clearError();
    final generation = _generation;
    try {
      final result = await UpdateManagedUserRoleCommand(_facade).executeWith((
        userId: details.user.id,
        role: role,
      ));
      if (!_isCurrent(generation)) return false;
      return result.fold(
        onSuccess: (user) {
          state.updateUser(user);
          return true;
        },
        onFailure: (failure) {
          _showFailure(failure);
          return false;
        },
      );
    } catch (_) {
      if (_isCurrent(generation)) state.showError('userDetailsRoleChangeError');
      return false;
    } finally {
      if (_isCurrent(generation)) state.setUpdatingRole(null);
    }
  }
}
