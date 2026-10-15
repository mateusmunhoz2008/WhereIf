import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:autth_injustice_app/account/data/services/i_account_remote_storage.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/account/domain/models/account_name.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/firebase_auth_service.dart';
import 'package:autth_injustice_app/authentication/domain/services/login_attempt.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';

class _AccountStorage extends Fake implements IAccountRemoteStorage {
  @override
  Future<Result<Account, Failure>> getAccount(String uid) async => Success(
      Account.initial(uid: uid, email: '$uid@example.com', displayName: uid));
}

class _PendingAccountStorage extends Fake implements IAccountRemoteStorage {
  final account = Completer<Result<Account, Failure>>();

  @override
  Future<Result<Account, Failure>> getAccount(String uid) => account.future;
}

class _User extends Fake implements fb.User {
  _User(this.uid);
  @override
  final String uid;
  @override
  Future<void> updateDisplayName(String? displayName) async {}
  @override
  Future<void> reload() async {}
  @override
  Future<fb.IdTokenResult> getIdTokenResult(
          [bool forceRefresh = false]) async =>
      _Token();
}

class _Token extends Fake implements fb.IdTokenResult {
  @override
  DateTime get expirationTime => DateTime.now().add(const Duration(hours: 1));
}

class _Credential extends Fake implements fb.UserCredential {
  _Credential(this.user);
  @override
  final fb.User user;
}

class _Auth extends Fake implements fb.FirebaseAuth {
  final first = Completer<fb.UserCredential>();
  final registration = Completer<fb.UserCredential>();
  int calls = 0;
  int signOuts = 0;
  final changes = StreamController<fb.User?>.broadcast(sync: true);
  @override
  fb.User? currentUser;
  @override
  Stream<fb.User?> authStateChanges() => changes.stream;
  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    final credential = await registration.future;
    currentUser = credential.user;
    changes.add(currentUser);
    return credential;
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    calls++;
    final credential = await (calls == 1
        ? first.future
        : Future.value(_Credential(_User('second'))));
    currentUser = credential.user;
    changes.add(currentUser);
    return credential;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    currentUser = null;
    changes.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'leaving login ignores late credentials without signing out the next login',
      () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final service = FirebaseAuthService(
        firebaseAuth: auth, accountStorage: _AccountStorage());
    addTearDown(service.dispose);
    final firstAttempt = LoginAttempt.begin();
    final first = service.signIn('first@example.com', 'password');
    await Future<void>.delayed(Duration.zero);
    firstAttempt.cancel();
    await first;
    expect(service.currentSession, isNull);
    LoginAttempt.begin();
    final second = service.signIn('second@example.com', 'password');
    auth.first.complete(_Credential(_User('first')));
    await second;
    expect(auth.signOuts, 1);
    expect(service.currentSession?.account.uid, 'second');
  });

  test('disposed service cannot accept a late native login', () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final service = FirebaseAuthService(
        firebaseAuth: auth, accountStorage: _AccountStorage());
    LoginAttempt.begin();
    final pending = service.signIn('first@example.com', 'password');
    await Future<void>.delayed(Duration.zero);
    service.dispose();
    expect((await pending).isFailure, isTrue);
    auth.first.complete(_Credential(_User('first')));
    await Future<void>.delayed(Duration.zero);
    expect(service.currentSession, isNull);
    expect(auth.signOuts, 1);
  });

  test('signup completion after logout cannot resurrect the account', () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final service = FirebaseAuthService(
        firebaseAuth: auth, accountStorage: _AccountStorage());
    addTearDown(service.dispose);
    final pending = service.signUp(
      name: AccountName.fromDisplayName('Test Student'),
      email: 'student@example.com',
      password: 'password',
    );
    await Future<void>.delayed(Duration.zero);
    await service.signOut();
    expect((await pending).isFailure, isTrue);
    auth.registration.complete(_Credential(_User('student')));
    await Future<void>.delayed(Duration.zero);
    expect(service.currentSession, isNull);
    expect(auth.signOuts, 2);
  });

  test('initial null auth event cannot cancel a pending native login',
      () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final service = FirebaseAuthService(
        firebaseAuth: auth, accountStorage: _AccountStorage());
    addTearDown(service.dispose);
    LoginAttempt.begin();
    final pending = service.signIn('first@example.com', 'password');
    await Future<void>.delayed(Duration.zero);
    auth.changes.add(null);
    auth.first.complete(_Credential(_User('first')));
    expect((await pending).isSuccess, isTrue);
    expect(service.currentSession!.account.uid, 'first');
    expect(auth.signOuts, 0);
  });

  test('delayed null event cannot cancel a login whose native UID is current',
      () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final storage = _PendingAccountStorage();
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    LoginAttempt.begin();
    final pending = service.signIn('first@example.com', 'password');
    auth.first.complete(_Credential(_User('first')));
    await Future<void>.delayed(Duration.zero);
    expect(auth.currentUser!.uid, 'first');
    auth.changes.add(null);
    storage.account.complete(Success(Account.initial(
        uid: 'first', email: 'first@example.com', displayName: 'First')));
    expect((await pending).isSuccess, isTrue);
    expect(service.currentSession!.account.uid, 'first');
    expect(auth.signOuts, 0);
  });

  test('real native logout during profile load rejects the late login',
      () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final storage = _PendingAccountStorage();
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    LoginAttempt.begin();
    final pending = service.signIn('first@example.com', 'password');
    auth.first.complete(_Credential(_User('first')));
    await Future<void>.delayed(Duration.zero);
    await auth.signOut();
    storage.account.complete(Success(Account.initial(
        uid: 'first', email: 'first@example.com', displayName: 'First')));
    expect((await pending).isFailure, isTrue);
    expect(service.currentSession, isNull);
    expect(auth.currentUser, isNull);
    expect(auth.signOuts, 1);
  });

  test(
      'native identity change rejects old profile without signing out the replacement',
      () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final storage = _PendingAccountStorage();
    final service =
        FirebaseAuthService(firebaseAuth: auth, accountStorage: storage);
    addTearDown(service.dispose);
    LoginAttempt.begin();
    final pending = service.signIn('first@example.com', 'password');
    auth.first.complete(_Credential(_User('first')));
    await Future<void>.delayed(Duration.zero);
    auth.currentUser = _User('replacement');
    auth.changes.add(auth.currentUser);
    storage.account.complete(Success(Account.initial(
        uid: 'first', email: 'first@example.com', displayName: 'First')));
    expect((await pending).isFailure, isTrue);
    expect(service.currentSession, isNull);
    expect(auth.currentUser!.uid, 'replacement');
    expect(auth.signOuts, 0);
  });
}
