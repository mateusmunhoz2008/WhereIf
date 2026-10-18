import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:autth_injustice_app/core/network/network_status.dart';
import 'package:autth_injustice_app/authentication/domain/services/login_attempt.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';
import 'package:autth_injustice_app/account/data/services/i_account_remote_storage.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/account/domain/models/account_name.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'i_auth_service.dart';

class FirebaseAuthService with WidgetsBindingObserver implements IAuthService {
  /// Opcional: ID do cliente web (OAuth tipo 3) para o Google Sign-In.
  /// Use --dart-define=GOOGLE_SERVER_CLIENT_ID=... se o Android não o achar.
  static const _googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final IAccountRemoteStorage _accountStorage;
  Future<void>? _googleInitialization;
  Future<void>? _sessionInitialization;
  String? _restoringUid;
  Future<void> _loginQueue = Future.value();
  int _sessionGeneration = 0;
  int _authOperations = 0;
  String? _recoveringUid;
  Timer? _recoveryTimer;
  Duration _retryDelay = const Duration(seconds: 15);
  late final StreamSubscription<fb.User?> _authSubscription;
  late final StreamSubscription<void> _connectionSubscription;
  bool _foreground = true;
  bool _disposed = false;
  LoginAttempt? _ownedAttempt;

  /// Conta com senha cujo e-mail ainda não foi confirmado. Contas Google
  /// já chegam verificadas.
  bool _needsEmailVerification(fb.User user) {
    return !user.emailVerified &&
        user.providerData.any((info) => info.providerId == 'password');
  }

  Future<AuthSessionResult> _runLogin(
    Future<AuthSession> Function() work, {
    Duration deadline = const Duration(seconds: 20),
    bool publishSession = true,
  }) {
    if (_disposed) {
      return Future.value(Error(DefaultFailure('authGoogleCanceled')));
    }
    final attempt = LoginAttempt.current ?? LoginAttempt.begin();
    _ownedAttempt = attempt;
    final operation = _loginQueue.then<AuthSessionResult>((_) async {
      if (_disposed || attempt.cancelled) {
        return Error(DefaultFailure('authGoogleCanceled'));
      }
      _authOperations++;
      final generation = ++_sessionGeneration;
      _cancelRecovery();
      try {
        final session = await work();
        final nativeUid = _firebaseAuth.currentUser?.uid;
        if (nativeUid != session.account.uid) {
          if (!_disposed &&
              _currentSessionSignal.value?.account.uid != nativeUid) {
            _currentSessionSignal.value = null;
          }
          return Error(DefaultFailure('authGoogleCanceled'));
        }
        if (_disposed ||
            attempt.cancelled ||
            generation != _sessionGeneration) {
          await _clearFailedAuthentication();
          return Error(DefaultFailure('authGoogleCanceled'));
        }
        if (publishSession) _setSession(session);
        return Success(session);
      } catch (error) {
        debugPrint('[Auth] Login failed: $error');
        await _clearFailedAuthentication();
        return Error(_mapAuthFailure(error));
      } finally {
        _authOperations--;
      }
    });
    _loginQueue = operation.then<void>((_) {});
    return Future.any<AuthSessionResult>([
      operation,
      attempt.cancellation
          .then((_) => Error(DefaultFailure('authGoogleCanceled'))),
    ]).timeout(deadline, onTimeout: () {
      attempt.timedOut = true;
      attempt.cancel();
      return Error(DefaultFailure('connectionRequired'));
    });
  }

  final Signal<AuthSession?> _currentSessionSignal = Signal<AuthSession?>(null);

  FirebaseAuthService({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    required IAccountRemoteStorage accountStorage,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _accountStorage = accountStorage {
    _authSubscription =
        _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
    _connectionSubscription =
        NetworkStatus.instance.restored.stream.listen((_) {
      _retryRecovery();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  Future<Account> _loadOrCreateAccount(fb.User fbUser) async {
    final result = await _accountStorage.getAccount(fbUser.uid);
    if (result case Success<Account, Failure>(:final value)) {
      return value;
    }

    final failure = result.failureValueOrNull;
    if (failure is! NotFoundFailure) {
      throw failure ?? RemoteFailure('accountLoadError');
    }

    final initial = Account.initial(
      uid: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName ?? '',
    );
    final saveResult = await _accountStorage
        .saveAccount(initial)
        .timeout(const Duration(seconds: 5));
    if (saveResult case Error<void, Failure>(:final value)) {
      throw value;
    }
    final persisted = await _accountStorage.getAccount(fbUser.uid);
    return persisted.fold(
      onSuccess: (account) => account,
      onFailure: (failure) => throw failure,
    );
  }

  Future<AuthSession> _buildSession(
    fb.User fbUser, {
    bool refreshToken = false,
  }) async {
    final account = await _loadOrCreateAccount(fbUser);
    try {
      fb.IdTokenResult tokenResult;
      if (refreshToken) {
        try {
          tokenResult = await fbUser
              .getIdTokenResult(true)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          tokenResult = await fbUser
              .getIdTokenResult()
              .timeout(const Duration(seconds: 5));
        }
      } else {
        tokenResult =
            await fbUser.getIdTokenResult().timeout(const Duration(seconds: 5));
      }

      final tokenExp = tokenResult.expirationTime ??
          DateTime.now().add(const Duration(minutes: 50));
      return AuthSession(
        account: account,
        token: Token(expiresAt: tokenExp),
      );
    } catch (error) {
      if (error is! TimeoutException &&
          !(error is fb.FirebaseAuthException &&
              error.code == 'network-request-failed')) {
        rethrow;
      }
      // Display cached account data offline without fabricating a valid token.
      // Firebase still authenticates and authorizes every server operation.
      return AuthSession(
          account: account,
          token: Token(expiresAt: DateTime.fromMillisecondsSinceEpoch(0)));
    }
  }

  void _setSession(AuthSession session) {
    if (_disposed) return;
    _cancelRecovery();
    _currentSessionSignal.value = session;
  }

  void _cancelRecovery() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveringUid = null;
    _retryDelay = const Duration(seconds: 15);
  }

  void _scheduleRecovery(String uid) {
    _recoveringUid = uid;
    if (_disposed || !_foreground || _recoveryTimer != null) return;
    _recoveryTimer = Timer(_retryDelay, () {
      _recoveryTimer = null;
      _retryRecovery();
    });
    _retryDelay = Duration(seconds: (_retryDelay.inSeconds * 2).clamp(15, 60));
  }

  void _retryRecovery() {
    if (_disposed ||
        !_foreground ||
        _authOperations > 0 ||
        _sessionInitialization != null ||
        _recoveringUid == null ||
        _firebaseAuth.currentUser?.uid != _recoveringUid) {
      return;
    }
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    unawaited(initSession());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _retryRecovery();
    } else {
      _recoveryTimer?.cancel();
      _recoveryTimer = null;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ownedAttempt?.cancel();
    _sessionGeneration++;
    _cancelRecovery();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription.cancel());
    unawaited(_connectionSubscription.cancel());
  }

  void _onAuthStateChanged(fb.User? user) {
    if (_disposed) return;
    if (user == null) {
      if (_authOperations == 0) {
        _sessionGeneration++;
      }
      _cancelRecovery();
      _currentSessionSignal.value = null;
    } else if (_needsEmailVerification(user)) {
      // Conta com e-mail não confirmado nunca vira sessão do app.
      _cancelRecovery();
      _currentSessionSignal.value = null;
    } else if (_authOperations > 0) {
      if (_currentSessionSignal.value?.account.uid != user.uid) {
        _currentSessionSignal.value = null;
      }
    } else if (_authOperations == 0 &&
        _restoringUid != user.uid &&
        _currentSessionSignal.value?.account.uid != user.uid) {
      // A restored/switching Firebase identity must not leave the previous
      // account visible while its profile is loaded.
      _sessionGeneration++;
      _cancelRecovery();
      _currentSessionSignal.value = null;
      unawaited(_restoreLatestIdentity());
    }
  }

  Future<void> _restoreLatestIdentity() async {
    await initSession();
    // An old UID's in-flight initialization may have been shared above.
    if (!_disposed &&
        _authOperations == 0 &&
        _firebaseAuth.currentUser != null &&
        _currentSessionSignal.value?.account.uid !=
            _firebaseAuth.currentUser?.uid) {
      await initSession();
    }
  }

  Failure _mapAuthFailure(Object error) {
    if (error is TimeoutException) return DefaultFailure('connectionRequired');
    if (error is Failure) return error;

    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return DefaultFailure('authGoogleCanceled');
      }
      return DefaultFailure('authUnexpectedError');
    }

    if (error is fb.FirebaseAuthException) {
      return switch (error.code) {
        'popup-closed-by-user' ||
        'cancelled-popup-request' =>
          DefaultFailure('authGoogleCanceled'),
        'invalid-credential' ||
        'invalid-email' ||
        'user-not-found' ||
        'wrong-password' =>
          DefaultFailure('invalidFields'),
        'email-already-in-use' => DefaultFailure('authEmailAlreadyInUse'),
        'weak-password' => DefaultFailure('authWeakPassword'),
        'network-request-failed' => DefaultFailure('authNetworkError'),
        'too-many-requests' => DefaultFailure('authTooManyRequests'),
        'user-disabled' => DefaultFailure('authAccountDisabled'),
        _ => DefaultFailure('authUnexpectedError'),
      };
    }

    return DefaultFailure('authUnexpectedError');
  }

  Future<void> _initializeGoogleSignIn() async {
    final pending = _googleInitialization ??= _googleSignIn.initialize(
      clientId: kIsWeb && _googleServerClientId.isNotEmpty
          ? _googleServerClientId
          : null,
      serverClientId: !kIsWeb && _googleServerClientId.isNotEmpty
          ? _googleServerClientId
          : null,
    );
    try {
      await pending;
    } catch (_) {
      // Não guarda uma inicialização que falhou, senão nunca tenta de novo.
      _googleInitialization = null;
      rethrow;
    }
  }

  Future<void> _rollbackCreatedUser(fb.User user) async {
    try {
      await user.delete();
    } catch (_) {
      try {
        if (_firebaseAuth.currentUser?.uid == user.uid) {
          await _firebaseAuth.signOut();
        }
      } catch (_) {
        // Best effort: the next auth-state event remains the authority.
      }
    } finally {
      if (!_disposed && _currentSessionSignal.value?.account.uid == user.uid) {
        _currentSessionSignal.value = null;
      }
    }
  }

  /// Cria o usuário. Se o e-mail já existe mas o cadastro anterior nunca foi
  /// verificado (app fechado no meio) e a senha confere, retoma esse cadastro
  /// em vez de travar em "e-mail já em uso".
  Future<({fb.User user, bool created})> _createOrResumeRegistration({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw DefaultFailure('authUnexpectedError');
      return (user: user, created: true);
    } on fb.FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;

      fb.User? existing;
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        existing = credential.user;
      } on fb.FirebaseAuthException catch (_) {
        throw error; // senha diferente: o e-mail está mesmo em uso
      }

      if (existing == null || !_needsEmailVerification(existing)) {
        await _clearFailedAuthentication();
        rethrow;
      }
      return (user: existing, created: false);
    }
  }

  Future<void> _clearFailedAuthentication() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // The operation already failed; session cleanup is best-effort.
    } finally {
      if (!_disposed) _currentSessionSignal.value = null;
    }
  }

  @override
  Signal<AuthSession?> get currentSessionSignal => _currentSessionSignal;

  @override
  AuthSession? get currentSession => _currentSessionSignal.value;

  @override
  Future<void> initSession() {
    if (_disposed || _authOperations > 0) return Future.value();
    final currentInitialization = _sessionInitialization;
    if (currentInitialization != null) return currentInitialization;

    _restoringUid = _firebaseAuth.currentUser?.uid;
    late final Future<void> initialization;
    initialization = _restoreSession().whenComplete(() {
      if (identical(_sessionInitialization, initialization)) {
        _sessionInitialization = null;
        _restoringUid = null;
      }
    });
    _sessionInitialization = initialization;
    return initialization;
  }

  Future<void> _restoreSession() async {
    final generation = _sessionGeneration;
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      _cancelRecovery();
      _currentSessionSignal.value = null;
      return;
    }
    if (_needsEmailVerification(user)) {
      _cancelRecovery();
      _currentSessionSignal.value = null;
      return;
    }

    bool stillCurrent() =>
        !_disposed &&
        generation == _sessionGeneration &&
        _firebaseAuth.currentUser?.uid == user.uid;

    try {
      // Firebase refreshes expired tokens itself; do not force a network trip
      // for every splash when a usable token is already cached.
      final session = await _buildSession(user);
      if (!stillCurrent()) return;
      _setSession(session);
    } catch (error) {
      if (!stillCurrent()) return;
      final invalidIdentity = error is fb.FirebaseAuthException &&
          [
            'user-disabled',
            'user-not-found',
            'user-token-expired',
            'invalid-user-token'
          ].contains(error.code);
      debugPrint('[Auth] Session restoration failed: ${error.runtimeType}'
          '${error is fb.FirebaseAuthException ? ' (${error.code})' : ''}');
      if (invalidIdentity) {
        _cancelRecovery();
        _currentSessionSignal.value = null;
        return;
      }

      // Firebase identity remains authenticated; an unavailable profile is
      // not a logout. Reuse only this UID's profile, or a least-privilege
      // identity from Firebase. Never create a Firestore document here.
      final previous = _currentSessionSignal.value;
      final account =
          error is! ForbiddenFailure && previous?.account.uid == user.uid
              ? previous!.account
              : Account.initial(
                  uid: user.uid,
                  email: user.email ?? '',
                  displayName: user.displayName ?? '');
      _currentSessionSignal.value = AuthSession(
          account: account,
          token: Token(expiresAt: DateTime.fromMillisecondsSinceEpoch(0)));
      _scheduleRecovery(user.uid);
    }
  }

  @override
  Future<AuthSessionResult> signIn(String email, String password) {
    return _runLogin(() async {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw NotFoundFailure('authUserNotFound');
      if (_needsEmailVerification(user)) {
        throw DefaultFailure('authEmailNotVerified');
      }
      return _buildSession(user);
    });
  }

  @override
  Future<AuthSessionResult> signInWithGoogle() {
    return _runLogin(() async {
      if (kIsWeb) {
        // Na web, authenticate() não é suportado. O popup do Firebase Auth
        // faz o mesmo papel e não precisa de serverClientId.
        final userCredential =
            await _firebaseAuth.signInWithPopup(fb.GoogleAuthProvider());
        final user = userCredential.user;
        if (user == null) throw DefaultFailure('authUnexpectedError');
        return _buildSession(user);
      }

      await _initializeGoogleSignIn();
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw DefaultFailure('authUnexpectedError');
      }

      return _buildSession(user);
    }, deadline: const Duration(minutes: 2));
  }

  @override
  Future<AuthSessionResult> signUp({
    required AccountName name,
    required String email,
    required String password,
  }) {
    if (_disposed) {
      return Future.value(Error(DefaultFailure('authGoogleCanceled')));
    }
    LoginAttempt.begin();
    return _runLogin(() async {
      fb.User? createdUser;
      try {
        final registration = await _createOrResumeRegistration(
          email: email,
          password: password,
        );
        if (registration.created) createdUser = registration.user;

        await registration.user.updateDisplayName(name.displayName);
        await registration.user.reload();
        final user = _firebaseAuth.currentUser ?? registration.user;

        // Sessão apenas informativa para o fluxo de cadastro: NÃO é
        // publicada e nenhum documento /accounts é criado até o e-mail
        // ser verificado (ver initSession).
        return AuthSession(
          account: Account.initial(
            uid: user.uid,
            email: user.email ?? email,
            displayName: name.displayName,
          ),
          token: Token(
            expiresAt: DateTime.now().add(const Duration(minutes: 50)),
          ),
        );
      } catch (_) {
        if (createdUser != null) await _rollbackCreatedUser(createdUser);
        rethrow;
      }
    }, deadline: const Duration(seconds: 30), publishSession: false);
  }

  @override
  Future<VoidResult> signOut() async {
    _authOperations++;
    _sessionGeneration++;
    _cancelRecovery();
    LoginAttempt.current?.cancel();
    try {
      await _firebaseAuth.signOut();
      try {
        final initialization = _googleInitialization;
        if (initialization != null) {
          await initialization;
          await _googleSignIn.signOut();
        }
      } catch (_) {
        // Firebase is already signed out; Google cleanup is best-effort.
      }
      if (!_disposed) _currentSessionSignal.value = null;
      return const Success(null);
    } catch (error) {
      return Error(_mapAuthFailure(error));
    } finally {
      _authOperations--;
    }
  }
}
