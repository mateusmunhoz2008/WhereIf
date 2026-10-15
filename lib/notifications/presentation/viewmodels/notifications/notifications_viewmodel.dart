import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/notifications/domain/facades/i_notifications_use_case_facade.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'notifications_commands_viewmodel.dart';
import 'notifications_state_viewmodel.dart';

class NotificationsViewModel {
  late final NotificationsState _state;
  late final NotificationsCommands _commands;
  late final void Function() _disposeSessionEffect;

  NotificationsState get state => _state;
  NotificationsCommands get commands => _commands;

  NotificationsViewModel(
      INotificationsUseCaseFacade facade, IAuthRepository auth) {
    _state = NotificationsState();
    _commands = NotificationsCommands(
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
