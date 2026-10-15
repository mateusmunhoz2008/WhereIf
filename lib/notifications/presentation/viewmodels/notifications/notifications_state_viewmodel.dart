import 'package:autth_injustice_app/core/patterns/async_load_state.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:signals_flutter/signals_flutter.dart';

class NotificationsState with AsyncLoadState {
  final notifications = signal<List<AppNotification>>(const []);
  final selectedType = signal<AppNotificationType?>(null);
  final expandedNotificationId = signal<String?>(null);
  final markingAsReadIds = signal<Set<String>>(const {});

  void reset() {
    notifications.value = const [];
    selectedType.value = null;
    expandedNotificationId.value = null;
    markingAsReadIds.value = const {};
    loading.value = false;
    loaded.value = false;
    clearError();
  }

  bool get hasNotifications => notifications.value.isNotEmpty;

  List<AppNotification> get visibleNotifications {
    final type = selectedType.value;
    if (type == null) return notifications.value;

    return notifications.value.where((item) => item.type == type).toList();
  }

  int get unreadCount =>
      notifications.value.where((item) => !item.isRead).length;

  void setNotifications(List<AppNotification> value) {
    notifications.value = List.unmodifiable(value);
    markLoaded();
  }

  void selectType(AppNotificationType? type) {
    selectedType.value = type;
  }

  AppNotification? notificationById(String notificationId) {
    for (final notification in notifications.value) {
      if (notification.id == notificationId) return notification;
    }
    return null;
  }

  void markAsReadLocally(String notificationId) {
    notifications.value = [
      for (final item in notifications.value)
        item.id == notificationId ? item.copyWith(isRead: true) : item,
    ];
  }

  bool startMarkingAsRead(String notificationId) {
    if (markingAsReadIds.value.contains(notificationId)) return false;

    markingAsReadIds.value = {...markingAsReadIds.value, notificationId};
    return true;
  }

  void finishMarkingAsRead(String notificationId) {
    markingAsReadIds.value = {
      for (final id in markingAsReadIds.value)
        if (id != notificationId) id,
    };
  }

  bool toggleExpanded(String notificationId) {
    final willExpand = expandedNotificationId.value != notificationId;
    expandedNotificationId.value = willExpand ? notificationId : null;
    return willExpand;
  }

  void markAllAsReadLocally() {
    notifications.value = [
      for (final item in notifications.value) item.copyWith(isRead: true),
    ];
  }
}
