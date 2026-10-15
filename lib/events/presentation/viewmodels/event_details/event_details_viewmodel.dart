import 'package:autth_injustice_app/complementary_hours/domain/services/complementary_hours_change_notifier.dart';
import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'event_details_commands_viewmodel.dart';
import 'event_details_state_viewmodel.dart';

class EventDetailsViewModel {
  late final EventDetailsState _state;
  late final EventDetailsCommands _commands;
  late final void Function() _disposeSessionEffect;

  EventDetailsState get state => _state;
  EventDetailsCommands get commands => _commands;

  EventDetailsViewModel(
    IEventsUseCaseFacade facade,
    ComplementaryHoursChangeNotifier hoursChangeNotifier,
    IAuthRepository authRepository,
  ) {
    _state = EventDetailsState();
    _commands = EventDetailsCommands(
      state: _state,
      facade: facade,
      hoursChangeNotifier: hoursChangeNotifier,
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
