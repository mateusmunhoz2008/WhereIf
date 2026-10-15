import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/user_management/domain/facades/i_user_management_use_case_facade.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:autth_injustice_app/user_management/presentation/viewmodels/user_management_commands_viewmodel.dart';
import 'package:autth_injustice_app/user_management/presentation/viewmodels/user_management_state_viewmodel.dart';

class UserManagementViewModel {
  late final UserManagementState _state;
  late final UserManagementCommands _commands;
  late final void Function() _disposeSessionEffect;

  UserManagementState get state => _state;
  UserManagementCommands get commands => _commands;

  UserManagementViewModel(
      IUserManagementUseCaseFacade facade, IAuthRepository auth) {
    _state = UserManagementState();
    _commands = UserManagementCommands(
      state: _state,
      facade: facade,
    );
    (String?, AccountRole?)? identity;
    _disposeSessionEffect = effect(() {
      final account = auth.sessionSignal.value?.account;
      final next = (account?.uid, account?.role);
      if (next == identity) return;
      identity = next;
      untracked(_commands.resetForSession);
    });
  }

  void dispose() {
    _disposeSessionEffect();
    _commands.dispose();
  }
}
