import 'dart:async';

import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_summary.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/notifications/domain/facades/i_notifications_use_case_facade.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:autth_injustice_app/notifications/domain/models/notification_announcement_draft.dart';
import 'package:autth_injustice_app/notifications/domain/notifications_types.dart';
import 'package:autth_injustice_app/notifications/presentation/viewmodels/notification_editor/notification_editor_viewmodel.dart';
import 'package:autth_injustice_app/notifications/presentation/viewmodels/notifications/notifications_viewmodel.dart';
import 'package:autth_injustice_app/user_management/domain/facades/i_user_management_use_case_facade.dart';
import 'package:autth_injustice_app/user_management/domain/models/managed_user_details.dart';
import 'package:autth_injustice_app/user_management/domain/models/user_directory_entry.dart';
import 'package:autth_injustice_app/user_management/domain/user_management_types.dart';
import 'package:autth_injustice_app/user_management/presentation/viewmodels/user_details/user_details_viewmodel.dart';
import 'package:autth_injustice_app/user_management/presentation/viewmodels/user_management_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

class _Auth extends Fake implements IAuthRepository {
  _Auth(String uid) : sessionSignal = signal<AuthSession?>(_session(uid));

  @override
  final Signal<AuthSession?> sessionSignal;

  @override
  AuthSession? get currentSession => sessionSignal.value;

  void switchTo(String? uid, {AccountRole role = AccountRole.administrator}) {
    sessionSignal.value = uid == null ? null : _session(uid, role: role);
  }
}

AuthSession _session(String uid,
        {AccountRole role = AccountRole.administrator}) =>
    AuthSession(
      account: _user(uid).account.copyWith(role: role),
      token: Token(expiresAt: DateTime(2100)),
    );

UserDirectoryEntry _user(String uid) => UserDirectoryEntry(
      account: Account.initial(
        uid: uid,
        email: '$uid@example.com',
        displayName: uid,
      ),
      totalComplementaryMinutes: 30,
    );

AppNotification _notification(String id) => AppNotification(
      id: id,
      type: AppNotificationType.event,
      title: id,
      message: 'Message',
      createdAt: DateTime(2026),
      isRead: false,
    );

ManagedUserDetails _details(String uid) => ManagedUserDetails(
      user: _user(uid),
      hoursSummary: const ComplementaryHoursSummary(
        completedMinutes: 30,
        targetMinutes: 100,
        milestoneMinutes: [],
      ),
      records: [],
    );

class _Notifications extends Fake implements INotificationsUseCaseFacade {
  final loads = <Completer<NotificationsResult>>[];
  final marks = <String, Completer<NotificationActionResult>>{};
  final publication = Completer<NotificationPublishResult>();

  @override
  Future<NotificationsResult> getNotifications(NotificationsNoParams params) {
    final load = Completer<NotificationsResult>();
    loads.add(load);
    return load.future;
  }

  @override
  Future<NotificationActionResult> markAsRead(NotificationIdParams params) {
    final mark = Completer<NotificationActionResult>();
    marks[params.notificationId] = mark;
    return mark.future;
  }

  @override
  Future<NotificationPublishResult> publishAnnouncement(
    PublishAnnouncementParams params,
  ) =>
      publication.future;
}

class _Users extends Fake implements IUserManagementUseCaseFacade {
  final loads = <Completer<UserDirectoryResult>>[];
  final details = <String, Completer<ManagedUserDetailsResult>>{};
  final roleChange = Completer<ManagedUserRoleResult>();

  @override
  Future<UserDirectoryResult> getUsers(UserManagementNoParams params) {
    final load = Completer<UserDirectoryResult>();
    loads.add(load);
    return load.future;
  }

  @override
  Future<ManagedUserDetailsResult> getUserDetails(ManagedUserIdParams params) {
    final load = Completer<ManagedUserDetailsResult>();
    details[params.userId] = load;
    return load.future;
  }

  @override
  Future<ManagedUserRoleResult> updateUserRole(
          UpdateManagedUserRoleParams params) =>
      roleChange.future;
}

void main() {
  test('notification loads do not share commands or responses across accounts',
      () async {
    final auth = _Auth('first');
    final facade = _Notifications();
    final vm = NotificationsViewModel(facade, auth);
    addTearDown(vm.dispose);
    final oldLoad = vm.commands.loadNotifications();
    auth.switchTo('second');
    expect(vm.state.notifications.value, isEmpty);
    final newLoad = vm.commands.loadNotifications();
    expect(facade.loads, hasLength(2));
    facade.loads[0].complete(Success([_notification('private-first')]));
    await oldLoad;
    expect(vm.state.notifications.value, isEmpty);
    expect(vm.state.loading.value, isTrue);
    facade.loads[1].complete(Success([_notification('second')]));
    await newLoad;
    expect(vm.state.notifications.value.single.id, 'second');
  });

  test('different notification read operations remain independent', () async {
    final facade = _Notifications();
    final vm = NotificationsViewModel(facade, _Auth('owner'));
    addTearDown(vm.dispose);
    vm.state
        .setNotifications([_notification('first'), _notification('second')]);
    final first = vm.commands.markAsRead('first');
    final second = vm.commands.markAsRead('second');
    expect(facade.marks.keys, containsAll(['first', 'second']));
    facade.marks['first']!.complete(const Success(null));
    facade.marks['second']!.complete(Error(RemoteFailure('readFailed')));
    await Future.wait([first, second]);
    expect(vm.state.notificationById('first')!.isRead, isTrue);
    expect(vm.state.notificationById('second')!.isRead, isFalse);
    expect(vm.state.markingAsReadIds.value, isEmpty);
  });

  test('late read acknowledgement cannot mark another account notification',
      () async {
    final auth = _Auth('first');
    final facade = _Notifications();
    final vm = NotificationsViewModel(facade, auth);
    addTearDown(vm.dispose);
    vm.state.setNotifications([_notification('same-id')]);
    final pending = vm.commands.markAsRead('same-id');
    auth.switchTo('second');
    vm.state.setNotifications([_notification('same-id')]);
    facade.marks['same-id']!.complete(const Success(null));
    await pending;
    expect(vm.state.notifications.value.single.isRead, isFalse);
  });

  test('directory is cleared when role is revoked and late load is discarded',
      () async {
    final auth = _Auth('admin');
    final facade = _Users();
    final vm = UserManagementViewModel(facade, auth);
    addTearDown(vm.dispose);
    vm.state.setUsers([_user('private')]);
    final pending = vm.commands.loadUsers(forceRefresh: true);
    auth.switchTo('admin', role: AccountRole.student);
    expect(vm.state.users.value, isEmpty);
    expect(vm.state.hasLoaded, isFalse);
    facade.loads.single.complete(Success([_user('private')]));
    await pending;
    expect(vm.state.users.value, isEmpty);
  });

  test('new directory session never receives an older in-flight result',
      () async {
    final auth = _Auth('first');
    final facade = _Users();
    final vm = UserManagementViewModel(facade, auth);
    addTearDown(vm.dispose);
    final first = vm.commands.loadUsers();
    auth.switchTo('second');
    final second = vm.commands.loadUsers();
    expect(facade.loads, hasLength(2));
    facade.loads[1].complete(Success([_user('second')]));
    await second;
    facade.loads[0].complete(Success([_user('first')]));
    await first;
    expect(vm.state.users.value.single.id, 'second');
    expect(vm.state.loading.value, isFalse);
  });

  test('server permission denial removes previously loaded directory',
      () async {
    final facade = _Users();
    final vm = UserManagementViewModel(facade, _Auth('admin'));
    addTearDown(vm.dispose);
    vm.state.setUsers([_user('private')]);
    final pending = vm.commands.loadUsers(forceRefresh: true);
    facade.loads.single
        .complete(Error(ForbiddenFailure('userManagementUnauthorized')));
    await pending;
    expect(vm.state.users.value, isEmpty);
    expect(vm.state.errorMessage.value, 'userManagementUnauthorized');
    expect(vm.state.loading.value, isFalse);
  });

  test(
      'switching selected user discards previous details without command reuse',
      () async {
    final facade = _Users();
    final vm = UserDetailsViewModel(facade, _Auth('admin'));
    addTearDown(vm.dispose);
    final first = vm.commands.load('first');
    final second = vm.commands.load('second');
    expect(facade.details.keys, containsAll(['first', 'second']));
    facade.details['second']!.complete(Success(_details('second')));
    await second;
    facade.details['first']!.complete(Success(_details('first')));
    await first;
    expect(vm.state.details.value!.user.id, 'second');
  });

  test('logout discards pending role change and private details', () async {
    final auth = _Auth('admin');
    final facade = _Users();
    final vm = UserDetailsViewModel(facade, auth);
    addTearDown(vm.dispose);
    vm.state.setDetails(_details('student'));
    final pending = vm.commands.updateRole(AccountRole.eventManager);
    auth.switchTo(null);
    facade.roleChange.complete(Success(_user('student')));
    expect(await pending, isFalse);
    expect(vm.state.details.value, isNull);
    expect(vm.state.updatingRole.value, isFalse);
  });

  test('logout clears announcement draft and ignores late publish completion',
      () async {
    final auth = _Auth('admin');
    final facade = _Notifications();
    final vm = NotificationEditorViewModel(facade, auth);
    addTearDown(vm.dispose);
    vm.state.updateDraft(const NotificationAnnouncementDraft(
        title: 'Private', message: 'Draft'));
    final pending = vm.commands.publishAnnouncement();
    auth.switchTo(null);
    facade.publication.complete(Success(_notification('late')));
    expect(await pending, isFalse);
    expect(vm.state.draft.value.title, isEmpty);
    expect(vm.state.publishedNotification.value, isNull);
    expect(vm.state.loading.value, isFalse);
  });

  test('disposed notification view model ignores pending responses', () async {
    final facade = _Notifications();
    final vm = NotificationsViewModel(facade, _Auth('owner'));
    final pending = vm.commands.loadNotifications();
    vm.dispose();
    facade.loads.single.complete(Success([_notification('late')]));
    await pending;
    expect(vm.state.notifications.value, isEmpty);
    expect(vm.state.loading.value, isFalse);
  });

  test('unexpected directory errors release loading without unhandled failures',
      () async {
    final facade = _Users();
    final vm = UserManagementViewModel(facade, _Auth('admin'));
    addTearDown(vm.dispose);
    final pending = vm.commands.loadUsers();
    facade.loads.single.completeError(StateError('Unavailable storage'));
    await pending;
    expect(vm.state.loading.value, isFalse);
    expect(vm.state.errorMessage.value, 'userManagementLoadError');
  });
}
