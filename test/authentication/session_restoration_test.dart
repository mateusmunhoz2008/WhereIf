import 'dart:async';

import 'package:autth_injustice_app/account/data/services/i_account_remote_storage.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/firebase_auth_service.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/network/network_status.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/account/domain/services/i_current_account_provider.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

class _User extends Fake implements fb.User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String get email => '$uid@example.com';
  @override
  String get displayName => 'Test Account';
  Object? tokenError;
  @override
  Future<fb.IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    if (tokenError != null) throw tokenError!;
    return _Token();
  }
}

class _Token extends Fake implements fb.IdTokenResult {
  @override
  DateTime get expirationTime => DateTime.now().add(const Duration(hours: 1));
}

class _Auth extends Fake implements fb.FirebaseAuth {
  _Auth(this.currentUser);
  @override
  fb.User? currentUser;
  final changes = StreamController<fb.User?>.broadcast(sync: true);
  @override
  Stream<fb.User?> authStateChanges() => changes.stream;
  @override
  Future<void> signOut() async {
    currentUser = null;
    changes.add(null);
  }
}

class _Storage extends Fake implements IAccountRemoteStorage {
  bool fail = true;
  int saves = 0;
  int reads = 0;
  Future<Result<Account, Failure>> Function(String)? read;
  @override
  Future<Result<Account, Failure>> getAccount(String uid) async {
    reads++;
    if (read != null) return read!(uid);
    if (fail) return Error(RemoteFailure('accountLoadError'));
    return Success(Account.initial(
        uid: uid, email: '$uid@example.com', displayName: 'Loaded Account'));
  }

  @override
  Future<Result<void, Failure>> saveAccount(Account account) async {
    saves++;
    return const Success(null);
  }
}

class _Provider implements ICurrentAccountProvider {
  _Provider(this.service);
  final FirebaseAuthService service;
  @override
  Account? get currentAccount => service.currentSession?.account;
  @override
  String? get currentUid => currentAccount?.uid;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'failed account read must not turn a persisted Firebase user into a guest',
      () async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage();
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    expect(auth.currentUser?.uid, 'owner');
    expect(service.currentSession?.account.uid, 'owner');
    expect(service.currentSession!.isExpired, isTrue);
    expect(service.currentSession!.account.role, AccountRole.student);
    final authorization =
        AuthorizationService(currentAccountProvider: _Provider(service));
    expect(authorization.isAuthenticated, isTrue);
    expect(authorization.isGuest, isFalse);
    expect(authorization.canManageEvents, isFalse);
    expect(authorization.canManageAccounts, isFalse);
    expect(authorization.canPublishAnnouncements, isFalse);
    expect(storage.saves, 0,
        reason: 'Failure must never create or overwrite an account');
    await auth.changes.close();
  });

  testWidgets('reconnection recovers full profile without reopening the app',
      (tester) async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage();
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    storage.fail = false;
    NetworkStatus.instance.report(false);
    NetworkStatus.instance.report(true);
    await tester.pump();
    expect(service.currentSession?.account.displayName, 'Loaded Account');
    expect(service.currentSession?.isExpired, isFalse);
    service.dispose();
    await auth.changes.close();
  });

  testWidgets('recovery backs off, pauses in background, retries on resume',
      (tester) async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage();
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    await tester.pump(const Duration(seconds: 15));
    expect(storage.reads, 2);
    await tester.pump(const Duration(seconds: 29));
    expect(storage.reads, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(storage.reads, 3);
    expect(service.currentSession?.account.uid, 'owner');
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    storage.fail = false;
    await tester.pump(const Duration(minutes: 2));
    expect(storage.reads, 3);
    expect(service.currentSession?.isExpired, isTrue);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.currentSession?.isExpired, isFalse);
    expect(storage.reads, 4);
    service.dispose();
    await auth.changes.close();
  });

  test('failed refresh preserves only the same UID previous profile', () async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage()..fail = false;
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    storage.fail = true;
    await service.initSession();
    expect(service.currentSession?.account.displayName, 'Loaded Account');
    auth.currentUser = _User('other');
    await service.initSession();
    expect(service.currentSession?.account.uid, 'other');
    expect(service.currentSession?.account.displayName, 'Test Account');
    await auth.changes.close();
  });

  test('permission denial cannot retain a previously privileged cached role',
      () async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage()
      ..read = (uid) async => Success(Account.initial(
            uid: uid,
            email: '$uid@example.com',
            displayName: 'Administrator',
          ).copyWith(role: AccountRole.administrator));
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    expect(service.currentSession!.account.role, AccountRole.administrator);
    storage.read = (_) async => Error(ForbiddenFailure('accountLoadError'));
    await service.initSession();
    expect(service.currentSession!.account.uid, 'owner');
    expect(service.currentSession!.account.role, AccountRole.student);
    expect(service.currentSession!.isExpired, isTrue);
    service.dispose();
    await auth.changes.close();
  });

  test('creation race loads the persisted profile instead of initial defaults',
      () async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage();
    final existing = Account.initial(
      uid: 'owner',
      email: 'owner@example.com',
      displayName: 'Existing Administrator',
    ).copyWith(role: AccountRole.administrator);
    storage.read = (_) async => storage.reads == 1
        ? Error(NotFoundFailure('accountNotFound'))
        : Success(existing);
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    expect(storage.saves, 1);
    expect(storage.reads, 2);
    expect(service.currentSession!.account, existing);
    expect(service.currentSession!.account.role, AccountRole.administrator);
    expect(service.currentSession!.isExpired, isFalse);
    await auth.changes.close();
  });

  test('failed read after creation cannot authenticate a fabricated profile',
      () async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage();
    storage.read = (_) async => storage.reads == 1
        ? Error(NotFoundFailure('accountNotFound'))
        : Error(RemoteFailure('accountLoadError'));
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    expect(storage.saves, 1);
    expect(storage.reads, 2);
    expect(service.currentSession!.isExpired, isTrue);
    expect(service.currentSession!.account.role, AccountRole.student);
    service.dispose();
    await auth.changes.close();
  });

  test('late restore cannot resurrect an explicitly signed-out session',
      () async {
    final auth = _Auth(_User('owner'));
    final pending = Completer<Result<Account, Failure>>();
    final storage = _Storage()..read = (_) => pending.future;
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    final restore = service.initSession();
    await service.signOut();
    pending.complete(
        Success(Account.initial(uid: 'owner', email: '', displayName: '')));
    await restore;
    expect(service.currentSession, isNull);
    expect(auth.currentUser, isNull);
    await auth.changes.close();
  });

  testWidgets(
      'account switch during restore cannot expose the previous account',
      (tester) async {
    final auth = _Auth(_User('owner'));
    final pending = Completer<Result<Account, Failure>>();
    final storage = _Storage()
      ..read = (uid) => uid == 'owner'
          ? pending.future
          : Future.value(Error(RemoteFailure('accountLoadError')));
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    final restore = service.initSession();
    auth.currentUser = _User('other');
    auth.changes.add(auth.currentUser);
    pending.complete(
        Success(Account.initial(uid: 'owner', email: '', displayName: '')));
    await restore;
    await tester.pump();
    expect(service.currentSession?.account.uid, 'other');
    expect(service.currentSession?.account.role, AccountRole.student);
    service.dispose();
    await auth.changes.close();
  });

  test('no Firebase identity stays guest; invalid token never gets a fallback',
      () async {
    final auth = _Auth(null);
    final storage = _Storage()..fail = false;
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    expect(service.currentSession, isNull);
    auth.currentUser = _User('owner')
      ..tokenError = fb.FirebaseAuthException(code: 'user-token-expired');
    await service.initSession();
    expect(service.currentSession, isNull);
    await auth.changes.close();
  });

  testWidgets('late Firebase identity restores after initial guest state',
      (tester) async {
    final auth = _Auth(null);
    final storage = _Storage()..fail = false;
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    expect(service.currentSession, isNull);
    auth.currentUser = _User('owner');
    auth.changes.add(auth.currentUser);
    await tester.pump();
    expect(service.currentSession?.account.uid, 'owner');
    expect(storage.reads, 1);
    service.dispose();
    await auth.changes.close();
  });

  test('initial auth event joins the same restore without restarting it',
      () async {
    final auth = _Auth(_User('owner'));
    final pending = Completer<Result<Account, Failure>>();
    final storage = _Storage()..read = (_) => pending.future;
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    final restore = service.initSession();
    auth.changes.add(auth.currentUser);
    pending.complete(
        Success(Account.initial(uid: 'owner', email: '', displayName: '')));
    await restore;
    expect(service.currentSession?.account.uid, 'owner');
    expect(service.currentSession?.isExpired, isFalse);
    expect(storage.reads, 1);
    await auth.changes.close();
  });

  testWidgets(
      'logout cancels retries and reconnection cannot restore old identity',
      (tester) async {
    final auth = _Auth(_User('owner'));
    final storage = _Storage();
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    await service.initSession();
    await service.signOut();
    NetworkStatus.instance.report(false);
    NetworkStatus.instance.report(true);
    await tester.pump(const Duration(minutes: 2));
    expect(service.currentSession, isNull);
    expect(storage.reads, 1);
    service.dispose();
    await auth.changes.close();
  });
}
