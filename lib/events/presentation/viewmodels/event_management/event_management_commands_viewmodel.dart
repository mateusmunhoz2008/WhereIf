import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/operation_scope.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';
import 'package:autth_injustice_app/events/presentation/commands/events_commands.dart';

import 'event_management_state_viewmodel.dart';

class EventManagementCommands with OperationScope {
  final EventManagementState state;
  final IEventsUseCaseFacade _facade;
  bool _refreshAfterLoading = false;

  EventManagementCommands({
    required this.state,
    required IEventsUseCaseFacade facade,
  }) : _facade = facade;

  void resetForSession() {
    invalidateOperations();
    _refreshAfterLoading = false;
    state.reset();
  }

  void dispose() {
    disposeOperations();
    state.reset();
  }

  Future<void> loadEvents({bool forceRefresh = false}) async {
    if (operationsDisposed) return;
    if (state.loading.value) {
      _refreshAfterLoading |= forceRefresh;
      return;
    }
    if (!forceRefresh && state.hasLoaded) return;
    final generation = operationGeneration;
    state.setLoading(true);
    state.clearError();
    try {
      final result =
          await LoadManagementEventsCatalogCommand(_facade).executeWith(());
      if (!acceptsOperation(generation)) return;
      result.fold(onSuccess: state.setCatalog, onFailure: _showFailure);
    } catch (_) {
      if (acceptsOperation(generation)) {
        state.showError('eventManagementLoadError');
      }
    } finally {
      if (acceptsOperation(generation)) {
        state.setLoading(false);
        if (_refreshAfterLoading) {
          _refreshAfterLoading = false;
          await loadEvents(forceRefresh: true);
        }
      }
    }
  }

  Future<bool> deleteEvent(String eventId) => _mutate(
        eventId,
        execute: () =>
            DeleteEventCommand(_facade).executeWith((eventId: eventId)),
        errorKey: 'eventManagementDeleteError',
      );

  Future<bool> endEvent(String eventId) => _mutate(
        eventId,
        execute: () => EndEventCommand(_facade).executeWith((eventId: eventId)),
        errorKey: 'eventManagementEndError',
        ending: true,
      );

  Future<bool> cancelEvent({required String eventId, required String reason}) =>
      _mutate(
        eventId,
        execute: () => CancelEventCommand(_facade)
            .executeWith((eventId: eventId, reason: reason)),
        errorKey: 'eventManagementCancelError',
      );

  Future<bool> _mutate(
    String eventId, {
    required Future<Result<bool, Failure>> Function() execute,
    required String errorKey,
    bool ending = false,
  }) async {
    if (operationsDisposed ||
        state.deletingEventId.value != null ||
        state.endingEventId.value != null) {
      return false;
    }
    final generation = operationGeneration;
    if (ending) {
      state.setEndingEvent(eventId);
    } else {
      state.setDeletingEvent(eventId);
    }
    try {
      final result = await execute();
      if (!acceptsOperation(generation)) return false;
      final changed = result.fold(
          onSuccess: (value) => value,
          onFailure: (failure) {
            _showFailure(failure);
            return false;
          });
      if (!changed) return false;
      await Future<void>.delayed(const Duration(milliseconds: 210));
      if (!acceptsOperation(generation)) return false;
      state.removeEvent(eventId);
      return true;
    } catch (_) {
      if (acceptsOperation(generation)) state.showError(errorKey);
      return false;
    } finally {
      if (acceptsOperation(generation)) {
        if (ending) {
          state.setEndingEvent(null);
        } else {
          state.setDeletingEvent(null);
        }
      }
    }
  }

  void _showFailure(Failure failure) {
    if (failure is ForbiddenFailure || failure is UnauthenticatedFailure) {
      resetForSession();
    }
    state.showError(failure.msg);
  }
}
