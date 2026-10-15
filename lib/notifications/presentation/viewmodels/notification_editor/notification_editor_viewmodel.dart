import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/notifications/domain/facades/i_notifications_use_case_facade.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'notification_editor_commands_viewmodel.dart';
import 'notification_editor_state_viewmodel.dart';

class NotificationEditorViewModel {
  late final NotificationEditorState _state;
  late final NotificationEditorCommands _commands;
  late final void Function() _disposeSessionEffect;

  NotificationEditorState get state => _state;
  NotificationEditorCommands get commands => _commands;

  NotificationEditorViewModel(
      INotificationsUseCaseFacade facade, IAuthRepository auth) {
    _state = NotificationEditorState();
    _commands = NotificationEditorCommands(
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
