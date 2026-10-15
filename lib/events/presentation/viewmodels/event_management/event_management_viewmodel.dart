import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'event_management_commands_viewmodel.dart';
import 'event_management_state_viewmodel.dart';

class EventManagementViewModel {
  late final EventManagementState _state;
  late final EventManagementCommands _commands;
  late final void Function() _disposeSessionEffect;

  EventManagementState get state => _state;
  EventManagementCommands get commands => _commands;

  EventManagementViewModel(
      IEventsUseCaseFacade facade, IAuthRepository authRepository) {
    _state = EventManagementState();
    _commands = EventManagementCommands(
      state: _state,
      facade: facade,
    );
    Object? identity;
    _disposeSessionEffect = effect(() {
      final account = authRepository.sessionSignal.value?.account;
      final next = (account?.uid, account?.role);
      if (identity == next) return;
      identity = next;
      untracked(_commands.resetForSession);
    });
  }

  void dispose() {
    _disposeSessionEffect();
    _commands.dispose();
  }
}
