import 'dart:async';

import 'package:autth_injustice_app/complementary_hours/domain/facades/i_complementary_hours_use_case_facade.dart';
import 'package:autth_injustice_app/complementary_hours/domain/services/complementary_hours_change_notifier.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/commands/complementary_hours_commands.dart';

import 'complementary_hours_records_commands_viewmodel.dart';
import 'complementary_hours_records_state_viewmodel.dart';

class ComplementaryHoursRecordsViewModel {
  late final ComplementaryHoursRecordsState _state;
  late final ComplementaryHoursRecordsCommands _commands;

  ComplementaryHoursRecordsState get state => _state;
  ComplementaryHoursRecordsCommands get commands => _commands;

  ComplementaryHoursRecordsViewModel(
    IComplementaryHoursUseCaseFacade facade,
    ComplementaryHoursChangeNotifier changeNotifier,
  ) {
    _state = ComplementaryHoursRecordsState();
    _commands = ComplementaryHoursRecordsCommands(
      state: _state,
      loadRecordsCommand: LoadComplementaryHoursRecordsCommand(facade),
      deleteRecordCommand: DeleteComplementaryHoursRecordCommand(facade),
    );

    // This viewmodel is an application-lifetime singleton.
    changeNotifier.changes.listen((_) {
      unawaited(_commands.loadRecords(forceRefresh: true));
    });
  }
}
