import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autth_injustice_app/core/network/firestore_access.dart';
import 'package:autth_injustice_app/core/network/queued_write.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/notifications/data/mappers/notification_firestore_mapper.dart';
import 'package:autth_injustice_app/notifications/data/services/i_notifications_service.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:autth_injustice_app/notifications/domain/models/notification_announcement_input.dart';
import 'package:autth_injustice_app/notifications/domain/notifications_types.dart';

class NotificationsFirestoreService implements INotificationsService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  static const _feedLimit = 100;

  NotificationsFirestoreService(
      {FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

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
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }
      final results = await Future.wait([
        FirestoreAccess.query(_notifications
            .orderBy('createdAt', descending: true)
            .limit(_feedLimit)),
        FirestoreAccess.query(_readMarkers(uid)),
      ]);
      final feedSnapshot = results[0];
      final readSnapshot = results[1];
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }

      final readIds = readSnapshot.docs.map((doc) => doc.id).toSet();

      final notifications = feedSnapshot.docs.map(
        (doc) => NotificationFirestoreMapper.fromSnapshot(
          doc,
          isRead: readIds.contains(doc.id),
        ),
      );

      return Success(List.unmodifiable(notifications));
    } on FirebaseException catch (error) {
      return Error(_loadFailure(error));
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
      final exists = (await FirestoreAccess.document(
              _notifications.doc(notificationId),
              cacheFirst: true))
          .exists;
      if (!exists) return Error(NotFoundFailure('notificationNotFound'));
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }

      final marker = _readMarkers(uid).doc(notificationId);
      await QueuedWrite.wait(
          marker.set({
            'readAt': Timestamp.now(),
          }),
          marker,
          deadline: const Duration(milliseconds: 300));
      return const Success(null);
    } on PendingSyncFailure {
      return const Success(null);
    } on FirebaseException catch (error) {
      return Error(_loadFailure(error));
    } catch (_) {
      return Error(RemoteFailure('notificationsLoadErrorMessage'));
    }
  }

  @override
  Future<NotificationActionResult> markAllAsRead(String uid) async {
    try {
      final feedSnapshot = await FirestoreAccess.query(_notifications
          .orderBy('createdAt', descending: true)
          .limit(_feedLimit));
      if (_firebaseAuth.currentUser?.uid != uid) {
        return Error(UnauthenticatedFailure());
      }

      final batch = _firestore.batch();
      for (final doc in feedSnapshot.docs) {
        batch.set(_readMarkers(uid).doc(doc.id), {'readAt': Timestamp.now()});
      }
      if (feedSnapshot.docs.isNotEmpty) {
        await QueuedWrite.wait(
            batch.commit(), _readMarkers(uid).doc(feedSnapshot.docs.first.id));
      }

      return const Success(null);
    } on PendingSyncFailure {
      return const Success(null);
    } on FirebaseException catch (error) {
      return Error(_loadFailure(error));
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
      if (_firebaseAuth.currentUser?.uid != actorUid) {
        return Error(UnauthenticatedFailure());
      }
      final docRef = _notifications.doc();
      final createdAt = DateTime.now();

      await QueuedWrite.wait(
          docRef.set(NotificationFirestoreMapper.toMap(
            type: AppNotificationType.update,
            title: input.title,
            message: input.message,
            createdAt: createdAt,
            authorUid: actorUid,
            externalUrl: input.externalUrl,
          )),
          docRef);

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
    } on Failure catch (failure) {
      return Error(failure);
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

  Failure _loadFailure(FirebaseException error) =>
      error.code == 'permission-denied'
          ? ForbiddenFailure('notificationsLoadErrorMessage')
          : RemoteFailure('notificationsLoadErrorMessage');
}
