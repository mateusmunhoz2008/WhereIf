import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/user_management/domain/facades/i_user_management_use_case_facade.dart';
import 'package:autth_injustice_app/user_management/presentation/commands/user_management_commands.dart';
import 'package:autth_injustice_app/user_management/presentation/viewmodels/user_management_state_viewmodel.dart';

class UserManagementCommands {
  final UserManagementState state;
  final IUserManagementUseCaseFacade _facade;
  int _generation = 0;
  bool _disposed = false;

  UserManagementCommands({
    required this.state,
    required IUserManagementUseCaseFacade facade,
  }) : _facade = facade;

  void resetForSession() {
    _generation++;
    state.reset();
  }

  void dispose() {
    _disposed = true;
    resetForSession();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> loadUsers({bool forceRefresh = false}) async {
    if (_disposed ||
        state.loading.value ||
        (!forceRefresh && state.hasLoaded)) {
      return;
    }

    state.setLoading(true);
    state.clearError();
    final generation = _generation;
    try {
      final result = await LoadManagedUsersCommand(_facade).executeWith(());
      if (!_isCurrent(generation)) return;
      result.fold(
        onSuccess: state.setUsers,
        onFailure: (failure) {
          if (failure is ForbiddenFailure ||
              failure is UnauthenticatedFailure) {
            resetForSession();
          }
          state.showError(failure.msg);
        },
      );
    } catch (_) {
      if (_isCurrent(generation)) state.showError('userManagementLoadError');
    } finally {
      if (_isCurrent(generation)) state.setLoading(false);
    }
  }

  void selectRole(AccountRole? role) => state.selectRole(role);

  void search(String value) => state.setSearchQuery(value);

  void cycleSort() => state.cycleSortMode();

  void resetFilters() {
    state.selectRole(null);
    state.setSearchQuery('');
    state.resetSort();
  }
}
