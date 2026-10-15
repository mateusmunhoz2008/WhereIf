import 'dart:async';

import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/notifications/domain/facades/i_notifications_use_case_facade.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:autth_injustice_app/notifications/presentation/commands/notifications_commands.dart';

import 'notifications_state_viewmodel.dart';

class NotificationsCommands {
  final NotificationsState state;
  final INotificationsUseCaseFacade _facade;
  int _generation = 0;
  bool _disposed = false;

  NotificationsCommands({
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

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (_disposed ||
        state.loading.value ||
        (!forceRefresh && state.hasLoaded)) {
      return;
    }

    state.setLoading(true);
    state.clearError();
    final generation = _generation;

    try {
      final result = await LoadNotificationsCommand(_facade).executeWith(());
      if (!_isCurrent(generation)) return;
      result.fold(
        onSuccess: state.setNotifications,
        onFailure: _showFailure,
      );
    } catch (_) {
      if (_isCurrent(generation)) {
        state.showError('notificationsLoadErrorMessage');
      }
    } finally {
      if (_isCurrent(generation)) state.setLoading(false);
    }
  }

  void selectFilter(AppNotificationType? type) {
    state.selectType(type);
  }

  Future<void> markAsRead(String notificationId) async {
    if (_disposed) return;
    final notification = state.notificationById(notificationId);
    if (notification == null || notification.isRead) return;
    if (!state.startMarkingAsRead(notificationId)) return;
    final generation = _generation;

    try {
      final result = await MarkNotificationAsReadCommand(_facade)
          .executeWith((notificationId: notificationId,));
      if (!_isCurrent(generation)) return;
      result.fold(
        onSuccess: (_) => state.markAsReadLocally(notificationId),
        onFailure: _showFailure,
      );
    } catch (_) {
      if (_isCurrent(generation)) {
        state.showError('notificationsLoadErrorMessage');
      }
    } finally {
      if (_isCurrent(generation)) state.finishMarkingAsRead(notificationId);
    }
  }

  void toggleExpanded(String notificationId) {
    if (state.toggleExpanded(notificationId)) {
      unawaited(markAsRead(notificationId));
    }
  }

  Future<void> markAllAsRead() async {
    if (_disposed || state.loading.value || state.unreadCount == 0) return;

    state.setLoading(true);
    state.clearError();
    final generation = _generation;

    try {
      final result =
          await MarkAllNotificationsAsReadCommand(_facade).executeWith(());
      if (!_isCurrent(generation)) return;
      result.fold(
        onSuccess: (_) => state.markAllAsReadLocally(),
        onFailure: _showFailure,
      );
    } catch (_) {
      if (_isCurrent(generation)) {
        state.showError('notificationsLoadErrorMessage');
      }
    } finally {
      if (_isCurrent(generation)) state.setLoading(false);
    }
  }

  void _showFailure(Failure failure) {
    if (failure is ForbiddenFailure || failure is UnauthenticatedFailure) {
      resetForSession();
    }
    state.showError(failure.msg);
  }
}
