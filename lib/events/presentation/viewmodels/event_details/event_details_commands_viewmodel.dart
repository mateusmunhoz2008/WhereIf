import 'package:autth_injustice_app/complementary_hours/domain/services/complementary_hours_change_notifier.dart';
import 'package:autth_injustice_app/events/presentation/commands/events_commands.dart';

import 'event_details_state_viewmodel.dart';

class EventDetailsCommands {
  final EventDetailsState state;
  final LoadEventDetailsCommand _loadEventDetailsCommand;
  final SetEventPersonalRecordCommand _setEventPersonalRecordCommand;
  final ComplementaryHoursChangeNotifier _hoursChangeNotifier;

  EventDetailsCommands({
    required this.state,
    required LoadEventDetailsCommand loadEventDetailsCommand,
    required SetEventPersonalRecordCommand setEventPersonalRecordCommand,
    required ComplementaryHoursChangeNotifier hoursChangeNotifier,
  })  : _loadEventDetailsCommand = loadEventDetailsCommand,
        _setEventPersonalRecordCommand = setEventPersonalRecordCommand,
        _hoursChangeNotifier = hoursChangeNotifier;

  Future<void> loadEvent(String eventId) async {
    if (state.loading.value) return;

    state.reset();
    state.setLoading(true);

    try {
      final result =
          await _loadEventDetailsCommand.executeWith((eventId: eventId,));

      result.fold(
        onSuccess: state.setDetails,
        onFailure: (failure) => state.showError(failure.msg),
      );
    } finally {
      state.setLoading(false);
    }
  }

  Future<void> togglePersonalRecord() async {
    final event = state.event.value;
    if (event == null || state.updatingPersonalRecord.value) return;

    state.setUpdatingPersonalRecord(true);
    state.clearError();

    try {
      final result = await _setEventPersonalRecordCommand.executeWith((
        eventId: event.id,
        addedToPersonalHistory: !state.addedToPersonalHistory.value,
      ));

      result.fold(
        onSuccess: (added) {
          state.setAddedToPersonalHistory(added);
          _hoursChangeNotifier.notifyChanged();
        },
        onFailure: (failure) => state.showError(failure.msg),
      );
    } finally {
      state.setUpdatingPersonalRecord(false);
    }
  }
}
