import 'package:autth_injustice_app/complementary_hours/domain/services/complementary_hours_change_notifier.dart';
import 'package:autth_injustice_app/events/presentation/commands/events_commands.dart';
import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/operation_scope.dart';

import 'event_details_state_viewmodel.dart';

class EventDetailsCommands with OperationScope {
  final EventDetailsState state;
  final IEventsUseCaseFacade _facade;
  final ComplementaryHoursChangeNotifier _hoursChangeNotifier;

  EventDetailsCommands({
    required this.state,
    required IEventsUseCaseFacade facade,
    required ComplementaryHoursChangeNotifier hoursChangeNotifier,
  })  : _facade = facade,
        _hoursChangeNotifier = hoursChangeNotifier;

  void resetForSession() {
    invalidateOperations();
    state.reset();
  }

  void dispose() {
    disposeOperations();
    state.reset();
  }

  Future<void> loadEvent(String eventId) async {
    if (operationsDisposed) return;
    resetForSession();
    state.setLoading(true);
    final generation = operationGeneration;

    try {
      final result = await LoadEventDetailsCommand(_facade)
          .executeWith((eventId: eventId,));
      if (!acceptsOperation(generation)) return;

      result.fold(
        onSuccess: state.setDetails,
        onFailure: (failure) => state.showError(failure.msg),
      );
    } catch (_) {
      if (acceptsOperation(generation)) {
        state.showError('eventDetailsUnavailable');
      }
    } finally {
      if (acceptsOperation(generation)) state.setLoading(false);
    }
  }

  Future<void> togglePersonalRecord() async {
    final event = state.event.value;
    if (operationsDisposed ||
        event == null ||
        state.updatingPersonalRecord.value) {
      return;
    }

    state.setUpdatingPersonalRecord(true);
    state.clearError();
    final generation = operationGeneration;

    try {
      final result = await SetEventPersonalRecordCommand(_facade).executeWith((
        eventId: event.id,
        addedToPersonalHistory: !state.addedToPersonalHistory.value,
      ));
      if (!acceptsOperation(generation)) return;

      result.fold(
        onSuccess: (added) {
          state.setAddedToPersonalHistory(added);
          _hoursChangeNotifier.notifyChanged();
        },
        onFailure: (failure) {
          if (failure is UnauthenticatedFailure ||
              failure is ForbiddenFailure) {
            state.setAddedToPersonalHistory(false);
          }
          state.showError(failure.msg);
        },
      );
    } catch (_) {
      if (acceptsOperation(generation)) {
        state.showError('eventDetailsUnavailable');
      }
    } finally {
      if (acceptsOperation(generation)) state.setUpdatingPersonalRecord(false);
    }
  }
}
