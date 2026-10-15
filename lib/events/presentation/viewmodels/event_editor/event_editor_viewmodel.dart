import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'event_editor_commands_viewmodel.dart';
import 'event_editor_state_viewmodel.dart';

class EventEditorViewModel {
  late final EventEditorState _state;
  late final EventEditorCommands _commands;
  late final void Function() _disposeSessionEffect;

  EventEditorState get state => _state;
  EventEditorCommands get commands => _commands;

  EventEditorViewModel(
      IEventsUseCaseFacade facade, IAuthRepository authRepository) {
    _state = EventEditorState();
    _commands = EventEditorCommands(
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
