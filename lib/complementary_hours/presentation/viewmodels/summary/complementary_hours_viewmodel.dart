import 'dart:async';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';

import 'package:autth_injustice_app/complementary_hours/domain/facades/i_complementary_hours_use_case_facade.dart';
import 'package:autth_injustice_app/complementary_hours/domain/services/complementary_hours_change_notifier.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/commands/complementary_hours_commands.dart';

import 'complementary_hours_commands_viewmodel.dart';
import 'complementary_hours_state_viewmodel.dart';

class ComplementaryHoursViewModel {
  late final ComplementaryHoursState _state;
  late final ComplementaryHoursCommands _commands;
  late final void Function() _disposeSessionEffect;
  late final StreamSubscription<void> _changesSubscription;

  ComplementaryHoursState get state => _state;
  ComplementaryHoursCommands get commands => _commands;

  ComplementaryHoursViewModel(
    IComplementaryHoursUseCaseFacade facade,
    ComplementaryHoursChangeNotifier changeNotifier,
    IAuthRepository auth,
  ) {
    _state = ComplementaryHoursState();
    _commands = ComplementaryHoursCommands(
      state: _state,
      loadSummaryCommand: LoadComplementaryHoursSummaryCommand(facade),
    );

    String? accountId;
    var initialized = false;
    _disposeSessionEffect = effect(() {
      final next = auth.sessionSignal.value?.account.uid;
      if (initialized && next == accountId) return;
      initialized = true;
      accountId = next;
      untracked(() => _commands.resetForAccount(active: next != null));
    });

    _changesSubscription = changeNotifier.changes.listen((_) {
      unawaited(_commands.loadSummary(forceRefresh: true));
    });
  }

  void dispose() {
    _disposeSessionEffect();
    unawaited(_changesSubscription.cancel());
    _commands.dispose();
  }
}
