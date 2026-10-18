import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/core/network/firestore_access.dart';
import 'package:autth_injustice_app/core/network/network_status.dart';
import 'package:autth_injustice_app/core/network/queued_write.dart';
import 'package:autth_injustice_app/complementary_hours/data/mappers/complementary_hours_firestore_mapper.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_record.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/events/data/mappers/event_firestore_mapper.dart';
import 'package:autth_injustice_app/events/data/services/i_events_service.dart';
import 'package:autth_injustice_app/events/domain/events_types.dart';
import 'package:autth_injustice_app/events/domain/models/event_creation_input.dart';
import 'package:autth_injustice_app/events/domain/models/event_details.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_update_input.dart';
import 'package:autth_injustice_app/events/domain/models/events_catalog.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/notifications/data/mappers/notification_firestore_mapper.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';

class EventsFirestoreService implements IEventsService {
  final FirebaseFirestore _firestore;
  final InstitutionPackage _institutionPackage;

  EventsFirestoreService({
    FirebaseFirestore? firestore,
    required InstitutionPackage institutionPackage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _institutionPackage = institutionPackage;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  DocumentReference<Map<String, dynamic>> _personalRecord(
    String uid,
    String eventId,
  ) {
    return _firestore
        .collection('accounts')
        .doc(uid)
        .collection('personalActivityRecords')
        .doc(eventId);
  }

  void _writeEventNotification(
    void Function(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)
        write, {
    required String eventId,
    required String titleL10nKey,
    required List<String> titleL10nArgs,
    required String fallbackTitle,
    String message = '',
    String? messageL10nKey,
  }) {
    write(
      _firestore.collection('notifications').doc(),
      NotificationFirestoreMapper.toMap(
        type: AppNotificationType.event,
        title: fallbackTitle,
        message: message,
        createdAt: DateTime.now(),
        eventId: eventId,
        titleL10nKey: titleL10nKey,
        titleL10nArgs: titleL10nArgs,
        messageL10nKey: messageL10nKey,
      ),
    );
  }

  @override
  Future<EventsCatalogResult> getCatalog() async {
    try {
      final now = DateTime.now();
      final snapshot = await _publicCatalogQuery(_events.where(Filter.or(
        Filter('publishAt', isNull: true),
        Filter('publishAt', isLessThanOrEqualTo: Timestamp.fromDate(now)),
      )));

      final previews = snapshot.docs
          .map((doc) => EventFirestoreMapper.previewFromSnapshot(
                doc,
                _institutionPackage,
              ))
          .toList();

      return Success(_bucket(previews, now));
    } on FirebaseException {
      return Error(RemoteFailure('eventsLoadError'));
    } catch (_) {
      return Error(RemoteFailure('eventsLoadError'));
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _publicCatalogQuery(
      Query<Map<String, dynamic>> query) async {
    try {
      return await query.get().timeout(FirestoreAccess.deadline);
    } on TimeoutException {
      NetworkStatus.instance.report(false);
      return query
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 1));
    }
  }

  @override
  Future<EventsCatalogResult> getManagementCatalog({
    required String actorUid,
  }) async {
    try {
      final snapshot = await FirestoreAccess.query(_events);
      final previews = snapshot.docs
          .map((doc) => EventFirestoreMapper.previewFromSnapshot(
                doc,
                _institutionPackage,
              ))
          .toList();

      return Success(_bucket(previews, DateTime.now()));
    } on FirebaseException catch (error) {
      return Error(_mapFailure(error, fallbackKey: 'eventManagementLoadError'));
    } catch (_) {
      return Error(RemoteFailure('eventManagementLoadError'));
    }
  }

  @override
  Future<EventDetailsResult> getEventDetails({
    String? uid,
    required String eventId,
  }) async {
    try {
      final snapshot = await FirestoreAccess.document(_events.doc(eventId),
          cacheFirst: true);
      if (!snapshot.exists) return Error(NotFoundFailure('eventNotFound'));

      final preview = EventFirestoreMapper.previewFromSnapshot(
          snapshot, _institutionPackage);
      final complementaryMinutes =
          EventFirestoreMapper.complementaryMinutesFromSnapshot(snapshot);

      var addedToPersonalHistory = false;
      if (uid != null) {
        try {
          final recordSnapshot = await FirestoreAccess.document(
              _personalRecord(uid, eventId),
              cacheFirst: true);
          addedToPersonalHistory = recordSnapshot.exists;
        } catch (_) {
          // Missing personal metadata must not hide an already cached event.
        }
      }

      return Success(EventDetails(
        event: preview,
        addedToPersonalHistory: addedToPersonalHistory,
        complementaryMinutes: complementaryMinutes,
      ));
    } on FirebaseException {
      return Error(NotFoundFailure('eventNotFound'));
    } catch (_) {
      return Error(RemoteFailure('eventDetailsUnavailable'));
    }
  }

  @override
  Future<EventPersonalRecordResult> setPersonalRecord({
    required String uid,
    required String eventId,
    required bool addedToPersonalHistory,
  }) async {
    try {
      final accountRef = _firestore.collection('accounts').doc(uid);
      final recordsRef = accountRef.collection('personalActivityRecords');
      final recordRef = recordsRef.doc(eventId);

      // Soma de todos os outros registros (corrige contas antigas também).
      final othersTotal = ComplementaryHoursFirestoreMapper.sumMinutes(
        (await recordsRef.get()).docs,
        excludingId: eventId,
      );

      if (!addedToPersonalHistory) {
        final batch = _firestore.batch()
          ..delete(recordRef)
          ..update(accountRef, {'totalComplementaryMinutes': othersTotal});
        await batch.commit();
        return const Success(false);
      }

      final eventSnapshot = await _events.doc(eventId).get();
      if (!eventSnapshot.exists) return Error(NotFoundFailure('eventNotFound'));

      final preview = EventFirestoreMapper.previewFromSnapshot(
        eventSnapshot,
        _institutionPackage,
      );
      final complementaryMinutes =
          EventFirestoreMapper.complementaryMinutesFromSnapshot(eventSnapshot);

      final batch = _firestore.batch()
        ..set(
          recordRef,
          ComplementaryHoursFirestoreMapper.toMap(
            ComplementaryHoursRecord(
              id: eventId,
              eventName: preview.title,
              eventDate: preview.startsAt,
              durationMinutes: complementaryMinutes,
            ),
          ),
        )
        ..update(accountRef, {
          'totalComplementaryMinutes':
              othersTotal + (complementaryMinutes ?? 0),
        });
      await batch.commit();

      return const Success(true);
    } on FirebaseException {
      return Error(RemoteFailure('eventDetailsUnavailable'));
    } catch (_) {
      return Error(RemoteFailure('eventDetailsUnavailable'));
    }
  }

  @override
  Future<EventCreationResult> createEvent({
    required String actorUid,
    required EventCreationInput input,
  }) async {
    if (_isLocalDeviceImage(input.imageSource)) {
      return Error(InvalidInputFailure('eventEditorImageUploadUnavailable'));
    }

    try {
      final docRef = _events.doc();
      final preview = input.toPreview(id: docRef.id);
      final now = DateTime.now();
      final isPublishedImmediately =
          preview.publishAt == null || !preview.publishAt!.isAfter(now);

      final batch = _firestore.batch();
      batch.set(
          docRef,
          EventFirestoreMapper.toMap(
            preview,
            complementaryMinutes: input.complementaryMinutes,
          ));

      if (isPublishedImmediately) {
        _writeEventNotification(
          (reference, data) => batch.set(reference, data),
          eventId: docRef.id,
          titleL10nKey: 'notificationEventCreatedTitle',
          titleL10nArgs: [preview.title],
          fallbackTitle: 'Novo evento: ${preview.title}',
          message: preview.description,
        );
      }

      await QueuedWrite.wait(batch.commit(), docRef);

      return Success(EventDetails(
        event: preview,
        addedToPersonalHistory: false,
        complementaryMinutes: input.complementaryMinutes,
      ));
    } on FirebaseException catch (error) {
      return Error(_mapFailure(error, fallbackKey: 'eventManagementSaveError'));
    } on Failure catch (failure) {
      return Error(failure);
    } catch (_) {
      return Error(RemoteFailure('eventManagementSaveError'));
    }
  }

  @override
  Future<EventUpdateResult> updateEvent({
    required String actorUid,
    required String eventId,
    required EventUpdateInput input,
  }) async {
    if (input.replacementImageSource != null &&
        _isLocalDeviceImage(input.replacementImageSource!)) {
      return Error(InvalidInputFailure('eventEditorImageUploadUnavailable'));
    }

    try {
      final docRef = _events.doc(eventId);
      final snapshot = await FirestoreAccess.document(docRef, cacheFirst: true);
      if (!snapshot.exists) return Error(NotFoundFailure('eventNotFound'));

      final current = EventFirestoreMapper.previewFromSnapshot(
        snapshot,
        _institutionPackage,
      );
      final updated = input.applyTo(current);

      await QueuedWrite.wait(
          docRef.set(
            EventFirestoreMapper.toMap(
              updated,
              complementaryMinutes: input.complementaryMinutes,
            ),
          ),
          docRef);

      return Success(EventDetails(
        event: updated,
        addedToPersonalHistory: false,
        complementaryMinutes: input.complementaryMinutes,
      ));
    } on FirebaseException catch (error) {
      return Error(_mapFailure(error, fallbackKey: 'eventManagementSaveError'));
    } on Failure catch (failure) {
      return Error(failure);
    } catch (_) {
      return Error(RemoteFailure('eventManagementSaveError'));
    }
  }

  @override
  Future<EventDeletionResult> deleteEvent({
    required String actorUid,
    required String eventId,
  }) async {
    try {
      final docRef = _events.doc(eventId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw NotFoundFailure('eventNotFound');
        final preview = EventFirestoreMapper.previewFromSnapshot(
            snapshot, _institutionPackage);
        if (preview.publishAt == null ||
            !preview.publishAt!.isAfter(DateTime.now())) {
          throw InvalidInputFailure('eventNotFound');
        }
        transaction.delete(docRef);
      }, timeout: const Duration(seconds: 8), maxAttempts: 1);
      return const Success(true);
    } on FirebaseException catch (error) {
      return Error(
          _mapFailure(error, fallbackKey: 'eventManagementDeleteError'));
    } catch (_) {
      return Error(RemoteFailure('eventManagementDeleteError'));
    }
  }

  @override
  Future<EventCancellationResult> cancelEvent({
    required String actorUid,
    required String eventId,
    required String reason,
  }) async {
    try {
      final docRef = _events.doc(eventId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw InvalidInputFailure('eventManagementCancelError');
        }

        final preview = EventFirestoreMapper.previewFromSnapshot(
          snapshot,
          _institutionPackage,
        );
        final now = DateTime.now();
        final isPublished =
            preview.publishAt == null || !preview.publishAt!.isAfter(now);

        if (preview.isCancelled || !isPublished) {
          throw InvalidInputFailure('eventManagementCancelError');
        }

        transaction.update(docRef, {
          'cancelledAt': Timestamp.fromDate(now),
          'cancellationReason': reason,
          'cancelledByUid': actorUid,
        });
        _writeEventNotification(
          (reference, data) => transaction.set(reference, data),
          eventId: eventId,
          titleL10nKey: 'notificationEventCancelledTitle',
          titleL10nArgs: [preview.title],
          fallbackTitle: 'Evento cancelado: ${preview.title}',
          message: reason,
        );
      }, timeout: const Duration(seconds: 8), maxAttempts: 1);

      return const Success(true);
    } on FirebaseException catch (error) {
      return Error(
          _mapFailure(error, fallbackKey: 'eventManagementCancelError'));
    } catch (_) {
      return Error(RemoteFailure('eventManagementCancelError'));
    }
  }

  @override
  Future<EventEndResult> endEvent({
    required String actorUid,
    required String eventId,
  }) async {
    try {
      final docRef = _events.doc(eventId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw InvalidInputFailure('eventManagementEndError');
        }

        final preview = EventFirestoreMapper.previewFromSnapshot(
          snapshot,
          _institutionPackage,
        );
        final now = DateTime.now();
        if (!preview.isOngoingAt(now)) {
          throw InvalidInputFailure('eventManagementEndError');
        }

        transaction.update(docRef, {'endedAt': Timestamp.fromDate(now)});
        _writeEventNotification(
          (reference, data) => transaction.set(reference, data),
          eventId: eventId,
          titleL10nKey: 'notificationEventEndedTitle',
          titleL10nArgs: [preview.title],
          fallbackTitle: 'Evento encerrado: ${preview.title}',
          messageL10nKey: 'notificationEventEndedMessage',
        );
      }, timeout: const Duration(seconds: 8), maxAttempts: 1);
      return const Success(true);
    } on FirebaseException catch (error) {
      return Error(_mapFailure(error, fallbackKey: 'eventManagementEndError'));
    } catch (_) {
      return Error(RemoteFailure('eventManagementEndError'));
    }
  }

  EventsCatalog _bucket(List<EventPreview> previews, DateTime now) {
    return EventsCatalog(
      featuredEvents:
          List.unmodifiable(previews.where((event) => event.isOngoingAt(now))),
      futureEvents:
          List.unmodifiable(previews.where((event) => event.isUpcomingAt(now))),
    );
  }

  bool _isLocalDeviceImage(String source) {
    if (source.startsWith('assets/')) return false;
    final uri = Uri.tryParse(source);
    final isRemote = uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    return !isRemote;
  }

  Failure _mapFailure(FirebaseException error, {required String fallbackKey}) {
    if (error.code == 'permission-denied') {
      return ForbiddenFailure('eventManagementUnauthorized');
    }
    return RemoteFailure(fallbackKey);
  }
}
