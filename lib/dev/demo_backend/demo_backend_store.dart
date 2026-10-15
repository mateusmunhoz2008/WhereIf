import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_record.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_summary.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/dev/demo_backend/demo_backend_seed.dart';
import 'package:autth_injustice_app/dev/demo_backend/models/demo_event.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/events/domain/models/event_creation_input.dart';
import 'package:autth_injustice_app/events/domain/models/event_details.dart';
import 'package:autth_injustice_app/events/domain/models/event_update_input.dart';
import 'package:autth_injustice_app/events/domain/models/events_catalog.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:autth_injustice_app/notifications/domain/models/notification_announcement_input.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/user_management/domain/models/user_directory_entry.dart';
import 'package:autth_injustice_app/user_management/domain/models/managed_user_details.dart';

class DemoBackendStore {
  final InstitutionPackage _institutionPackage;

  DemoBackendStore({
    required InstitutionPackage institutionPackage,
  }) : _institutionPackage = institutionPackage;

  final Account currentUser = DemoBackendSeed.studentAccount;
  late final List<DemoEvent> _featuredEvents =
      DemoBackendSeed.buildFeaturedEvents(_institutionPackage);

  late final List<DemoEvent> _futureEvents =
      DemoBackendSeed.buildFutureEvents(_institutionPackage);
  final Set<String> _eventsInPersonalHistory = {};

  List<ComplementaryHoursRecord> _records =
      DemoBackendSeed.buildComplementaryHoursRecords();
  List<AppNotification> _notifications = DemoBackendSeed.buildNotifications();
  late final List<UserDirectoryEntry> _managedUsers =
      List.of(DemoBackendSeed.buildManagedUsers());

  List<UserDirectoryEntry> usersForManagement(String actorUid) {
    _ensureDemoUser(actorUid);
    return List.unmodifiable(_managedUsers);
  }

  ManagedUserDetails? managedUserDetails(
    String actorUid,
    String userId,
  ) {
    _ensureDemoUser(actorUid);
    final user = _managedUserById(userId);
    if (user == null) return null;

    return ManagedUserDetails(
      user: user,
      hoursSummary: ComplementaryHoursSummary(
        completedMinutes: user.totalComplementaryMinutes,
        targetMinutes: _institutionPackage.complementaryHours.targetMinutes,
        milestoneMinutes:
            _institutionPackage.complementaryHours.milestoneMinutes,
      ),
      records: _managedUserRecords(user),
    );
  }

  UserDirectoryEntry? updateManagedUserRole(
    String actorUid,
    String userId,
    AccountRole role,
  ) {
    _ensureDemoUser(actorUid);
    if (actorUid == userId || role == AccountRole.administrator) return null;

    final index = _managedUsers.indexWhere((user) => user.id == userId);
    if (index < 0 ||
        _managedUsers[index].account.role == AccountRole.administrator) {
      return null;
    }

    final current = _managedUsers[index];
    final updated = current.copyWith(
      account: current.account.copyWith(
        role: role,
        updatedAt: DateTime.now(),
      ),
    );
    _managedUsers[index] = updated;
    return updated;
  }

  EventsCatalog get eventsCatalog {
    final now = DateTime.now();
    bool isPublished(DemoEvent event) =>
        event.preview.publishAt == null ||
        !event.preview.publishAt!.isAfter(now);

    return _buildActiveCatalog(
      events: _allEvents.where(isPublished),
      now: now,
    );
  }

  EventsCatalog get managementEventsCatalog => _buildActiveCatalog(
        events: _allEvents,
        now: DateTime.now(),
      );

  EventDetails? eventDetails(String? uid, String eventId) {
    if (uid != null) _ensureDemoUser(uid);
    final event = _findEvent(eventId);
    if (event == null) return null;

    return EventDetails(
      event: event.preview,
      addedToPersonalHistory:
          uid != null && _eventsInPersonalHistory.contains(eventId),
      complementaryMinutes: event.complementaryMinutes,
    );
  }

  EventDetails createEvent(String actorUid, EventCreationInput input) {
    _ensureDemoUser(actorUid);
    final id = 'demo-event-${DateTime.now().microsecondsSinceEpoch}';
    final event = DemoEvent(
      preview: input.toPreview(id: id),
      complementaryMinutes: input.complementaryMinutes,
    );
    _futureEvents.add(event);

    return EventDetails(
      event: event.preview,
      addedToPersonalHistory: false,
      complementaryMinutes: event.complementaryMinutes,
    );
  }

  EventDetails? updateEvent(
    String actorUid,
    String eventId,
    EventUpdateInput input,
  ) {
    _ensureDemoUser(actorUid);

    EventDetails? updateIn(List<DemoEvent> events) {
      final index = events.indexWhere((item) => item.preview.id == eventId);
      if (index < 0) return null;

      final current = events[index];
      final updated = DemoEvent(
        preview: input.applyTo(current.preview),
        complementaryMinutes: input.complementaryMinutes,
      );
      events[index] = updated;

      if (_eventsInPersonalHistory.contains(eventId)) {
        _upsertPersonalRecord(updated);
      }

      return EventDetails(
        event: updated.preview,
        addedToPersonalHistory: _eventsInPersonalHistory.contains(eventId),
        complementaryMinutes: updated.complementaryMinutes,
      );
    }

    return updateIn(_featuredEvents) ?? updateIn(_futureEvents);
  }

  bool setEventPersonalRecord({
    required String uid,
    required String eventId,
    required bool addedToPersonalHistory,
  }) {
    _ensureDemoUser(uid);
    final event = _findEvent(eventId);
    if (event == null) return false;

    if (addedToPersonalHistory) {
      _eventsInPersonalHistory.add(eventId);
      _upsertPersonalRecord(event);
    } else {
      _eventsInPersonalHistory.remove(eventId);
      _records = [
        for (final record in _records)
          if (record.id != eventId) record,
      ];
    }

    return true;
  }

  bool deleteEvent(String actorUid, String eventId) {
    _ensureDemoUser(actorUid);
    final event = _findEvent(eventId);
    if (event == null || _isPublished(event, DateTime.now())) return false;

    final eventCountBefore = _featuredEvents.length + _futureEvents.length;
    _featuredEvents.removeWhere(
      (event) => event.preview.id == eventId,
    );
    _futureEvents.removeWhere(
      (event) => event.preview.id == eventId,
    );
    final deleted =
        _featuredEvents.length + _futureEvents.length < eventCountBefore;
    if (!deleted) return false;

    _eventsInPersonalHistory.remove(eventId);
    _records = [
      for (final record in _records)
        if (record.id != eventId) record,
    ];
    return true;
  }

  bool cancelEvent(
    String actorUid,
    String eventId,
    String reason, {
    DateTime? cancelledAt,
  }) {
    _ensureDemoUser(actorUid);
    final effectiveCancellation = cancelledAt ?? DateTime.now();
    final normalizedReason = reason.trim();

    bool cancelIn(List<DemoEvent> events) {
      final index = events.indexWhere((item) => item.preview.id == eventId);
      if (index < 0) return false;

      final current = events[index];
      if (current.preview.isCancelled ||
          !_isPublished(current, effectiveCancellation)) {
        return false;
      }

      events[index] = DemoEvent(
        preview: current.preview.copyWith(
          cancelledAt: effectiveCancellation,
          cancellationReason: normalizedReason,
          cancelledByUid: actorUid,
        ),
        complementaryMinutes: current.complementaryMinutes,
      );
      _notifications = [
        AppNotification(
          id: 'event-cancelled-$eventId-'
              '${effectiveCancellation.microsecondsSinceEpoch}',
          type: AppNotificationType.event,
          title: 'Evento cancelado: ${current.preview.title}',
          message: normalizedReason,
          createdAt: effectiveCancellation,
          isRead: false,
          eventId: eventId,
          authorUid: actorUid,
        ),
        ..._notifications,
      ];
      return true;
    }

    return cancelIn(_featuredEvents) || cancelIn(_futureEvents);
  }

  bool endEvent(
    String actorUid,
    String eventId, {
    DateTime? endedAt,
  }) {
    _ensureDemoUser(actorUid);
    final effectiveEnd = endedAt ?? DateTime.now();

    bool updateIn(List<DemoEvent> events) {
      final index = events.indexWhere((item) => item.preview.id == eventId);
      if (index < 0 || !events[index].preview.isOngoingAt(effectiveEnd)) {
        return false;
      }

      final current = events[index];
      events[index] = DemoEvent(
        preview: current.preview.copyWith(endedAt: effectiveEnd),
        complementaryMinutes: current.complementaryMinutes,
      );
      return true;
    }

    return updateIn(_featuredEvents) || updateIn(_futureEvents);
  }

  ComplementaryHoursSummary complementaryHoursSummary(String uid) {
    _ensureDemoUser(uid);
    final completedMinutes = _records.fold<int>(
      0,
      (total, record) => total + (record.durationMinutes ?? 0),
    );

    return ComplementaryHoursSummary(
      completedMinutes: completedMinutes,
      targetMinutes: _institutionPackage.complementaryHours.targetMinutes,
      milestoneMinutes: _institutionPackage.complementaryHours.milestoneMinutes,
    );
  }

  List<ComplementaryHoursRecord> complementaryHoursRecords(String uid) {
    _ensureDemoUser(uid);
    final records = List<ComplementaryHoursRecord>.of(_records)
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return List.unmodifiable(records);
  }

  bool deleteComplementaryHoursRecord(String uid, String recordId) {
    _ensureDemoUser(uid);
    final exists = _records.any((record) => record.id == recordId);
    if (!exists) return false;

    _records = [
      for (final record in _records)
        if (record.id != recordId) record,
    ];
    _eventsInPersonalHistory.remove(recordId);
    return true;
  }

  List<AppNotification> notificationsFor(String uid) {
    _ensureDemoUser(uid);
    final notifications = List<AppNotification>.of(_notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(notifications);
  }

  bool markNotificationAsRead(String uid, String notificationId) {
    _ensureDemoUser(uid);
    final exists = _notifications.any((item) => item.id == notificationId);
    if (!exists) return false;

    _notifications = [
      for (final item in _notifications)
        item.id == notificationId ? item.copyWith(isRead: true) : item,
    ];
    return true;
  }

  void markAllNotificationsAsRead(String uid) {
    _ensureDemoUser(uid);
    _notifications = [
      for (final item in _notifications) item.copyWith(isRead: true),
    ];
  }

  AppNotification publishAnnouncement(
    String actorUid,
    NotificationAnnouncementInput input, {
    DateTime? createdAt,
  }) {
    _ensureDemoUser(actorUid);
    final effectiveCreation = createdAt ?? DateTime.now();
    final notification = AppNotification(
      id: 'announcement-${effectiveCreation.microsecondsSinceEpoch}',
      type: AppNotificationType.update,
      title: input.title,
      message: input.message,
      createdAt: effectiveCreation,
      isRead: false,
      authorUid: actorUid,
      externalUrl: input.externalUrl,
    );
    _notifications = [notification, ..._notifications];
    return notification;
  }

  Iterable<DemoEvent> get _allEvents sync* {
    yield* _featuredEvents;
    yield* _futureEvents;
  }

  EventsCatalog _buildActiveCatalog({
    required Iterable<DemoEvent> events,
    required DateTime now,
  }) {
    final previews = events.map((event) => event.preview);

    return EventsCatalog(
      featuredEvents: List.unmodifiable(
        previews.where((event) => event.isOngoingAt(now)),
      ),
      futureEvents: List.unmodifiable(
        previews.where((event) => event.isUpcomingAt(now)),
      ),
    );
  }

  DemoEvent? _findEvent(String eventId) {
    for (final event in _allEvents) {
      if (event.preview.id == eventId) return event;
    }
    return null;
  }

  bool _isPublished(DemoEvent event, DateTime now) {
    final publishAt = event.preview.publishAt;
    return publishAt == null || !publishAt.isAfter(now);
  }

  void _upsertPersonalRecord(DemoEvent event) {
    _records = [
      ComplementaryHoursRecord(
        id: event.preview.id,
        eventName: event.preview.title,
        eventDate: event.preview.startsAt,
        durationMinutes: event.complementaryMinutes,
      ),
      for (final record in _records)
        if (record.id != event.preview.id) record,
    ];
  }

  UserDirectoryEntry? _managedUserById(String userId) {
    for (final user in _managedUsers) {
      if (user.id == userId) return user;
    }
    return null;
  }

  List<ComplementaryHoursRecord> _managedUserRecords(
    UserDirectoryEntry user,
  ) {
    if (user.id == DemoBackendSeed.studentAccount.uid) {
      return DemoBackendSeed.buildComplementaryHoursRecords();
    }

    final total = user.totalComplementaryMinutes;
    if (total <= 0) return const [];

    final first = total ~/ 2;
    final second = (total - first) ~/ 2;
    final third = total - first - second;
    final durations = [first, second, third].where((value) => value > 0);
    final names = [
      'Semana acadêmica',
      'Projeto de extensão',
      'Mostra cultural',
    ];

    return [
      for (final indexed in durations.indexed)
        ComplementaryHoursRecord(
          id: '${user.id}-record-${indexed.$1}',
          eventName: names[indexed.$1],
          eventDate: DateTime(2026, 7 - indexed.$1, 12 + indexed.$1),
          durationMinutes: indexed.$2,
        ),
    ];
  }

  void _ensureDemoUser(String uid) {
    if (uid.trim().isEmpty) {
      throw StateError('Usuário demo inválido.');
    }
  }
}
