import 'package:autth_injustice_app/notifications/presentation/commands/notifications_commands.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/notifications/domain/facades/i_notifications_use_case_facade.dart';

import 'notification_editor_state_viewmodel.dart';

class NotificationEditorCommands {
  final NotificationEditorState state;
  final INotificationsUseCaseFacade _facade;
  int _generation = 0;
  bool _disposed = false;

  NotificationEditorCommands({
    required this.state,
    required INotificationsUseCaseFacade facade,
  }) : _facade = facade;

  void resetForSession() {
    _generation++;
    state.reset();
  }

  void dispose() {
    _disposed = true;
    resetForSession();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<bool> publishAnnouncement() async {
    if (_disposed || state.loading.value) return false;

    state.setLoading(true);
    state.clearError();
    final generation = _generation;

    try {
      final result = await PublishAnnouncementCommand(_facade).executeWith(
        (draft: state.draft.value),
      );
      if (!_isCurrent(generation)) return false;

      return result.fold(
        onSuccess: (notification) {
          state.setPublishedNotification(notification);
          return true;
        },
        onFailure: (failure) {
          state.showError(failure.msg);
          return failure is PendingSyncFailure;
        },
      );
    } catch (_) {
      if (_isCurrent(generation)) {
        state.showError('notificationEditorPublishError');
      }
      return false;
    } finally {
      if (_isCurrent(generation)) state.setLoading(false);
    }
  }
}
