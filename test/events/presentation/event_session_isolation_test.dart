import 'dart:async';

import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/complementary_hours/domain/services/complementary_hours_change_notifier.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/events/domain/events_types.dart';
import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';
import 'package:autth_injustice_app/events/domain/models/event_details.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/events/domain/models/events_catalog.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_details/event_details_commands_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_details/event_details_state_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_details/event_details_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_editor/event_editor_commands_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_editor/event_editor_state_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_management/event_management_commands_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_management/event_management_state_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../support/test_event_categories.dart';

EventDetails _details(String id) => EventDetails(
      event: EventPreview(
        id: id,
        title: 'Event $id',
        category: TestEventCategories.academic,
        startsAt: DateTime(2100, 1, 1),
        location: '',
        description: '',
        imageUrl: '',
        endMode: EventEndMode.manual,
      ),
      addedToPersonalHistory: false,
      complementaryMinutes: 60,
    );

EventsCatalog _catalog(String id) => EventsCatalog(
      featuredEvents: const [],
      futureEvents: [_details(id).event],
    );

class _Facade extends Fake implements IEventsUseCaseFacade {
  bool fail = false;
  final details = <String, Completer<EventDetailsResult>>{};
  final records = <Completer<EventPersonalRecordResult>>[];
  final creations = <Completer<EventCreationResult>>[];
  final updates = <Completer<EventUpdateResult>>[];
  final catalogs = <Completer<EventsCatalogResult>>[];
  final deletions = <Completer<EventDeletionResult>>[];

  void _checkFailure() {
    if (fail) throw StateError('Unexpected facade exception');
  }

  @override
  Future<EventDetailsResult> getEventDetails(EventIdParams params) {
    _checkFailure();
    final request = Completer<EventDetailsResult>();
    details[params.eventId] = request;
    return request.future;
  }

  @override
  Future<EventPersonalRecordResult> setEventPersonalRecord(
      EventPersonalRecordParams params) {
    _checkFailure();
    final request = Completer<EventPersonalRecordResult>();
    records.add(request);
    return request.future;
  }

  @override
  Future<EventCreationResult> createEvent(CreateEventParams params) {
    _checkFailure();
    final request = Completer<EventCreationResult>();
    creations.add(request);
    return request.future;
  }

  @override
  Future<EventUpdateResult> updateEvent(UpdateEventParams params) {
    _checkFailure();
    final request = Completer<EventUpdateResult>();
    updates.add(request);
    return request.future;
  }

  @override
  Future<EventsCatalogResult> getManagementCatalog(EventsNoParams params) {
    _checkFailure();
    final request = Completer<EventsCatalogResult>();
    catalogs.add(request);
    return request.future;
  }

  @override
  Future<EventDeletionResult> deleteEvent(DeleteEventParams params) {
    _checkFailure();
    final request = Completer<EventDeletionResult>();
    deletions.add(request);
    return request.future;
  }

  @override
  Future<EventCancellationResult> cancelEvent(CancelEventParams params) {
    _checkFailure();
    return Future.value(const Success(false));
  }

  @override
  Future<EventEndResult> endEvent(EndEventParams params) {
    _checkFailure();
    return Future.value(const Success(false));
  }
}

class _Auth extends Fake implements IAuthRepository {
  @override
  final Signal<AuthSession?> sessionSignal = signal<AuthSession?>(null);
  @override
  AuthSession? get currentSession => sessionSignal.value;
}

AuthSession _session(String uid,
        {AccountRole role = AccountRole.student, int expires = 2100}) =>
    AuthSession(
      account: Account.initial(
              uid: uid, email: '$uid@example.com', displayName: 'Student')
          .copyWith(role: role),
      token: Token(expiresAt: DateTime(expires)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final oldCompletesFirst in [false, true]) {
    test('details A never replace B; old completes first=$oldCompletesFirst',
        () async {
      final facade = _Facade();
      final state = EventDetailsState();
      final commands = EventDetailsCommands(
          state: state,
          facade: facade,
          hoursChangeNotifier: ComplementaryHoursChangeNotifier());
      addTearDown(commands.dispose);
      final old = commands.loadEvent('A');
      final current = commands.loadEvent('B');
      expect(facade.details.keys, ['A', 'B']);
      if (oldCompletesFirst) {
        facade.details['A']!.complete(Success(_details('A')));
        await old;
        expect(state.event.value, isNull);
        expect(state.loading.value, isTrue);
      }
      facade.details['B']!.complete(Success(_details('B')));
      await current;
      if (!oldCompletesFirst) {
        facade.details['A']!.complete(Success(_details('A')));
        await old;
      }
      expect(state.event.value?.id, 'B');
      expect(state.loading.value, isFalse);
      expect(state.errorMessage.value, isNull);
    });
  }

  test(
      'personal record from the previous account cannot affect the new account or notify hours',
      () async {
    final facade = _Facade();
    final state = EventDetailsState()..setDetails(_details('account-A'));
    final notifier = ComplementaryHoursChangeNotifier();
    var notifications = 0;
    final subscription = notifier.changes.listen((_) => notifications++);
    addTearDown(subscription.cancel);
    final commands = EventDetailsCommands(
        state: state, facade: facade, hoursChangeNotifier: notifier);
    addTearDown(commands.dispose);
    final old = commands.togglePersonalRecord();
    commands.resetForSession();
    state.setDetails(_details('account-B'));
    final current = commands.togglePersonalRecord();

    facade.records[0].complete(const Success(true));
    await old;
    expect(state.event.value?.id, 'account-B');
    expect(state.addedToPersonalHistory.value, isFalse);
    expect(state.updatingPersonalRecord.value, isTrue);
    expect(notifications, 0);

    facade.records[1].complete(const Success(true));
    await current;
    expect(state.addedToPersonalHistory.value, isTrue);
    expect(state.updatingPersonalRecord.value, isFalse);
    expect(notifications, 1);
  });

  test(
      'disposing details ignores a pending personal record and its notification',
      () async {
    final facade = _Facade();
    final state = EventDetailsState()..setDetails(_details('A'));
    final notifier = ComplementaryHoursChangeNotifier();
    var notifications = 0;
    final subscription = notifier.changes.listen((_) => notifications++);
    addTearDown(subscription.cancel);
    final commands = EventDetailsCommands(
        state: state, facade: facade, hoursChangeNotifier: notifier);
    final pending = commands.togglePersonalRecord();
    commands.dispose();
    facade.records.single.complete(const Success(true));
    await pending;
    expect(state.event.value, isNull);
    expect(state.updatingPersonalRecord.value, isFalse);
    expect(state.addedToPersonalHistory.value, isFalse);
    expect(notifications, 0);
    await commands.loadEvent('after-dispose');
    expect(facade.details, isEmpty);
  });

  for (final creating in [false, true]) {
    test(
        'editor reset ignores old ${creating ? 'create' : 'update'} without unlocking a new save',
        () async {
      final facade = _Facade();
      final state = EventEditorState()
        ..initializeForEdit(eventId: 'A', details: _details('A'));
      final commands = EventEditorCommands(state: state, facade: facade);
      addTearDown(commands.dispose);
      final old = creating ? commands.createEvent() : commands.updateEvent();
      commands.resetForSession();
      state.initializeForEdit(eventId: 'B', details: _details('B'));
      final current = commands.updateEvent();
      (creating ? facade.creations.single : facade.updates.first)
          .complete(Success(_details('A')));
      expect(await old, isFalse);
      expect(state.savedEvent.value, isNull);
      expect(state.editingEventId.value, 'B');
      expect(state.loading.value, isTrue);
      facade.updates.last.complete(Success(_details('B')));
      expect(await current, isTrue);
      expect(state.savedEvent.value?.event.id, 'B');
      expect(state.loading.value, isFalse);
    });
  }

  test(
      'management reset ignores an old administrative catalog without unlocking the new load',
      () async {
    final facade = _Facade();
    final state = EventManagementState();
    final commands = EventManagementCommands(state: state, facade: facade);
    addTearDown(commands.dispose);
    final old = commands.loadEvents();
    commands.resetForSession();
    final current = commands.loadEvents();
    facade.catalogs[0].complete(Success(_catalog('private-A')));
    await old;
    expect(state.events.value, isEmpty);
    expect(state.loading.value, isTrue);
    expect(state.hasLoaded, isFalse);
    facade.catalogs[1].complete(Success(_catalog('private-B')));
    await current;
    expect(state.events.value.map((event) => event.id), ['private-B']);
    expect(state.loading.value, isFalse);
    expect(state.hasLoaded, isTrue);
  });

  test('a stale management mutation cannot remove a new account event',
      () async {
    final facade = _Facade();
    final state = EventManagementState()..setCatalog(_catalog('shared-id'));
    final commands = EventManagementCommands(state: state, facade: facade);
    addTearDown(commands.dispose);
    final pending = commands.deleteEvent('shared-id');
    commands.resetForSession();
    state.setCatalog(_catalog('shared-id'));
    facade.deletions.single.complete(const Success(true));
    expect(await pending, isFalse);
    expect(state.events.value.single.id, 'shared-id');
    expect(state.deletingEventId.value, isNull);
    expect(state.endingEventId.value, isNull);
  });

  test(
      'unexpected details and history failures release their flags without escaping',
      () async {
    final facade = _Facade()..fail = true;
    final state = EventDetailsState();
    final commands = EventDetailsCommands(
        state: state,
        facade: facade,
        hoursChangeNotifier: ComplementaryHoursChangeNotifier());
    addTearDown(commands.dispose);
    await commands.loadEvent('A');
    expect(state.loading.value, isFalse);
    expect(state.errorMessage.value, 'eventDetailsUnavailable');
    state.setDetails(_details('A'));
    await commands.togglePersonalRecord();
    expect(state.updatingPersonalRecord.value, isFalse);
    expect(state.addedToPersonalHistory.value, isFalse);
    expect(state.errorMessage.value, 'eventDetailsUnavailable');
  });

  test('unexpected editor failures release loading and return false', () async {
    final facade = _Facade()..fail = true;
    final state = EventEditorState();
    final commands = EventEditorCommands(state: state, facade: facade);
    addTearDown(commands.dispose);
    expect(await commands.loadEventForEditing('A'), isFalse);
    expect(state.loading.value, isFalse);
    expect(state.errorMessage.value, 'eventEditorLoadError');
    expect(await commands.createEvent(), isFalse);
    expect(state.loading.value, isFalse);
    expect(state.errorMessage.value, 'eventManagementSaveError');
    state.initializeForEdit(eventId: 'A', details: _details('A'));
    expect(await commands.updateEvent(), isFalse);
    expect(state.loading.value, isFalse);
    expect(state.savedEvent.value, isNull);
    expect(state.errorMessage.value, 'eventManagementSaveError');
  });

  test('unexpected management failures release loading and mutation flags',
      () async {
    final facade = _Facade()..fail = true;
    final state = EventManagementState();
    final commands = EventManagementCommands(state: state, facade: facade);
    addTearDown(commands.dispose);
    await commands.loadEvents();
    expect(state.loading.value, isFalse);
    expect(state.errorMessage.value, 'eventManagementLoadError');
    expect(await commands.deleteEvent('A'), isFalse);
    expect(state.deletingEventId.value, isNull);
    expect(state.errorMessage.value, 'eventManagementDeleteError');
    expect(await commands.endEvent('A'), isFalse);
    expect(state.endingEventId.value, isNull);
    expect(state.errorMessage.value, 'eventManagementEndError');
    expect(
        await commands.cancelEvent(eventId: 'A', reason: 'Cancelled'), isFalse);
    expect(state.deletingEventId.value, isNull);
    expect(state.errorMessage.value, 'eventManagementCancelError');
  });

  test('details VM resets on UID or role changes but not a token refresh',
      () async {
    final facade = _Facade();
    final auth = _Auth()..sessionSignal.value = _session('A');
    final model =
        EventDetailsViewModel(facade, ComplementaryHoursChangeNotifier(), auth);
    addTearDown(auth.sessionSignal.dispose);
    addTearDown(model.dispose);
    final first = model.commands.loadEvent('loaded');
    facade.details['loaded']!.complete(Success(_details('loaded')));
    await first;
    auth.sessionSignal.value = _session('A', expires: 2101);
    await Future<void>.delayed(Duration.zero);
    expect(model.state.event.value?.id, 'loaded');

    auth.sessionSignal.value = _session('A', role: AccountRole.eventManager);
    await Future<void>.delayed(Duration.zero);
    expect(model.state.event.value, isNull);

    final old = model.commands.loadEvent('old-account');
    auth.sessionSignal.value = _session('B');
    await Future<void>.delayed(Duration.zero);
    facade.details['old-account']!.complete(Success(_details('old-account')));
    await old;
    expect(model.state.event.value, isNull);
    expect(model.state.loading.value, isFalse);
    expect(model.state.errorMessage.value, isNull);
  });
}
