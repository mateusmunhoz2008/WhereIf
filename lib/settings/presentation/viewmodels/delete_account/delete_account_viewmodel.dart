import 'package:autth_injustice_app/settings/domain/facades/i_account_security_facade.dart';

import 'delete_account_commands_viewmodel.dart';
import 'delete_account_state_viewmodel.dart';

class DeleteAccountViewModel {
  late final DeleteAccountState _state;
  late final DeleteAccountCommands _commands;

  DeleteAccountState get state => _state;
  DeleteAccountCommands get commands => _commands;

  DeleteAccountViewModel(IAccountSecurityFacade facade) {
    _state = DeleteAccountState();
    _commands = DeleteAccountCommands(
      state: _state,
      accountSecurityFacade: facade,
    );
  }
}