import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/notifications/data/mappers/notification_firestore_mapper.dart';
import 'package:autth_injustice_app/notifications/data/services/i_notifications_service.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:autth_injustice_app/notifications/domain/models/notification_announcement_input.dart';
import 'package:autth_injustice_app/notifications/domain/notifications_types.dart';

class NotificationsFirestoreService implements INotificationsService {
  final FirebaseFirestore _firestore;

  /// Quantidade de notificações mais recentes retornadas por consulta.
  static const _feedLimit = 100;

  NotificationsFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> _readMarkers(String uid) {
    return _firestore
        .collection('accounts')
        .doc(uid)
        .collection('readNotifications');
  }

  @override
  Future<NotificationsResult> getNotifications(String uid) async {
    try {
      final results = await Future.wait([
        _notifications.orderBy('createdAt', descending: true).limit(_feedLimit).get(),
        _readMarkers(uid).get(),
      ]);
      final feedSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final readSnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;

      final readIds = readSnapshot.docs.map((doc) => doc.id).toSet();

      final notifications = feedSnapshot.docs.map(
        (doc) => NotificationFirestoreMapper.fromSnapshot(
          doc,
          isRead: readIds.contains(doc.id),
        ),
      );

      return Success(List.unmodifiable(notifications));
    } on FirebaseException {
      return Error(RemoteFailure('notificationsLoadErrorMessage'));
    } catch (_) {
      return Error(RemoteFailure('notificationsLoadErrorMessage'));
    }
  }

  @override
  Future<NotificationActionResult> markAsRead(
    String uid,
    String notificationId,
  ) async {
    try {
      final exists = (await _notifications.doc(notificationId).get()).exists;
      if (!exists) return Error(NotFoundFailure('notificationNotFound'));

      await _readMarkers(uid).doc(notificationId).set({
        'readAt': Timestamp.now(),
      });
      return const Success(null);
    } on FirebaseException {
      return Error(RemoteFailure('notificationsLoadErrorMessage'));
    } catch (_) {
      return Error(RemoteFailure('notificationsLoadErrorMessage'));
    }
  }

  @override
  Future<NotificationActionResult> markAllAsRead(String uid) async {
    try {
      final feedSnapshot = await _notifications
          .orderBy('createdAt', descending: true)
          .limit(_feedLimit)
          .get();

      final batch = _firestore.batch();
      for (final doc in feedSnapshot.docs) {
        batch.set(_readMarkers(uid).doc(doc.id), {'readAt': Timestamp.now()});
      }
      await batch.commit();

      return const Success(null);
    } on FirebaseException {
      return Error(RemoteFailure('notificationsLoadErrorMessage'));
    } catch (_) {
      return Error(RemoteFailure('notificationsLoadErrorMessage'));
    }
  }

  @override
  Future<NotificationPublishResult> publishAnnouncement({
    required String actorUid,
    required NotificationAnnouncementInput input,
  }) async {
    try {
      final docRef = _notifications.doc();
      final createdAt = DateTime.now();

      await docRef.set(NotificationFirestoreMapper.toMap(
        type: AppNotificationType.update,
        title: input.title,
        message: input.message,
        createdAt: createdAt,
        authorUid: actorUid,
        externalUrl: input.externalUrl,
      ));

      return Success(AppNotification(
        id: docRef.id,
        type: AppNotificationType.update,
        title: input.title,
        message: input.message,
        createdAt: createdAt,
        isRead: false,
        authorUid: actorUid,
        externalUrl: input.externalUrl,
      ));
    } on FirebaseException catch (error) {
      return Error(_mapFailure(error));
    } catch (_) {
      return Error(RemoteFailure('notificationEditorPublishError'));
    }
  }

  Failure _mapFailure(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return ForbiddenFailure('notificationManagementUnauthorized');
    }
    return RemoteFailure('notificationEditorPublishError');
  }
}