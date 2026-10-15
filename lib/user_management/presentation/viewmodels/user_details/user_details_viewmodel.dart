import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/user_management/domain/facades/i_user_management_use_case_facade.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'user_details_commands_viewmodel.dart';
import 'user_details_state_viewmodel.dart';

class UserDetailsViewModel {
  late final UserDetailsState _state;
  late final UserDetailsCommands _commands;
  late final void Function() _disposeSessionEffect;

  UserDetailsState get state => _state;
  UserDetailsCommands get commands => _commands;

  UserDetailsViewModel(
      IUserManagementUseCaseFacade facade, IAuthRepository auth) {
    _state = UserDetailsState();
    _commands = UserDetailsCommands(
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
