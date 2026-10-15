import 'package:autth_injustice_app/events/presentation/commands/events_commands.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/operation_scope.dart';
import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';

import 'event_editor_state_viewmodel.dart';

class EventEditorCommands with OperationScope {
  final EventEditorState state;
  final IEventsUseCaseFacade _facade;

  EventEditorCommands({
    required this.state,
    required IEventsUseCaseFacade facade,
  }) : _facade = facade;

  void resetForSession() {
    invalidateOperations();
    state.reset();
  }

  void dispose() {
    disposeOperations();
    state.reset();
  }

  Future<bool> loadEventForEditing(String eventId) async {
    if (operationsDisposed || state.loading.value) return false;

    state.setLoading(true);
    state.clearError();
    final generation = operationGeneration;

    try {
      final result = await LoadEventDetailsCommand(_facade).executeWith(
        (eventId: eventId),
      );
      if (!acceptsOperation(generation)) return false;

      return result.fold(
        onSuccess: (details) {
          state.initializeForEdit(
            eventId: eventId,
            details: details,
          );
          return true;
        },
        onFailure: (failure) {
          state.showError(failure.msg);
          return false;
        },
      );
    } catch (_) {
      if (acceptsOperation(generation)) state.showError('eventEditorLoadError');
      return false;
    } finally {
      if (acceptsOperation(generation)) state.setLoading(false);
    }
  }

  Future<bool> createEvent() async {
    if (operationsDisposed || state.loading.value) return false;

    state.setLoading(true);
    state.clearError();
    final generation = operationGeneration;

    try {
      final result = await CreateEventCommand(_facade).executeWith(
        (draft: state.draft.value),
      );
      if (!acceptsOperation(generation)) return false;

      return result.fold(
        onSuccess: (event) {
          state.setSavedEvent(event);
          return true;
        },
        onFailure: (failure) {
          state.showError(failure.msg);
          return failure is PendingSyncFailure;
        },
      );
    } catch (_) {
      if (acceptsOperation(generation)) {
        state.showError('eventManagementSaveError');
      }
      return false;
    } finally {
      if (acceptsOperation(generation)) state.setLoading(false);
    }
  }

  Future<bool> updateEvent() async {
    if (operationsDisposed || state.loading.value) return false;

    final eventId = state.editingEventId.value;
    if (eventId == null) return false;

    state.setLoading(true);
    state.clearError();
    final generation = operationGeneration;

    try {
      final result = await UpdateEventCommand(_facade).executeWith(
        (
          eventId: eventId,
          draft: state.draft.value,
        ),
      );
      if (!acceptsOperation(generation)) return false;

      return result.fold(
        onSuccess: (event) {
          state.setSavedEvent(event);
          return true;
        },
        onFailure: (failure) {
          state.showError(failure.msg);
          return failure is PendingSyncFailure;
        },
      );
    } catch (_) {
      if (acceptsOperation(generation)) {
        state.showError('eventManagementSaveError');
      }
      return false;
    } finally {
      if (acceptsOperation(generation)) state.setLoading(false);
    }
  }
}
