import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';
import 'package:autth_injustice_app/account/data/services/i_account_remote_storage.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/account/domain/models/account_name.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'i_auth_service.dart';

/// Serviço de autenticação com Firebase.
///
/// Responsabilidades:
/// - Autenticar o usuário via email/senha ou Google.
/// - Ao logar/registrar, garantir que o documento Account exista no Firestore.
/// - Manter o [AuthSession] reativo via Signal.
/// - Restaurar a sessão mantida pelo Firebase Auth.
class FirebaseAuthService implements IAuthService {
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final IAccountRemoteStorage _accountStorage;
  Future<void>? _googleInitialization;
  Future<void>? _sessionInitialization;

  final Signal<AuthSession?> _currentSessionSignal = Signal<AuthSession?>(null);

  FirebaseAuthService({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    required IAccountRemoteStorage accountStorage,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _accountStorage = accountStorage {
    // Escuta mudanças de estado do Firebase Auth (ex: token revogado externamente)
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  // ──────────────────────────────────────────────
  // Helpers internos
  // ──────────────────────────────────────────────

  /// Busca o Account no Firestore; se não existir, cria com dados iniciais.
  /// Isso garante que todo usuário autenticado tenha um documento `/accounts/{uid}`.
  Future<Account> _loadOrCreateAccount(fb.User fbUser) async {
    final result = await _accountStorage.getAccount(fbUser.uid);
    if (result case Success<Account, Failure>(:final value)) {
      return value;
    }

    final failure = result.failureValueOrNull;
    if (failure is! NotFoundFailure) {
      throw failure ?? RemoteFailure('accountLoadError');
    }

    // Documento não existe ainda: cria com valores padrão
    final initial = Account.initial(
      uid: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName ?? '',
    );
    final saveResult = await _accountStorage.saveAccount(initial);
    if (saveResult case Error<void, Failure>(:final value)) {
      throw value;
    }
    return initial;
  }

  Future<AuthSession> _buildSession(
    fb.User fbUser, {
    bool refreshToken = false,
  }) async {
    fb.IdTokenResult tokenResult;
    if (refreshToken) {
      try {
        tokenResult = await fbUser.getIdTokenResult(true);
      } catch (_) {
        tokenResult = await fbUser.getIdTokenResult();
      }
    } else {
      tokenResult = await fbUser.getIdTokenResult();
    }

    final account = await _loadOrCreateAccount(fbUser);
    final tokenExp = tokenResult.expirationTime ??
        DateTime.now().add(const Duration(minutes: 50));
    return AuthSession(
      account: account,
      token: Token(expiresAt: tokenExp),
    );
  }

  void _setSession(AuthSession session) {
    _currentSessionSignal.value = session;
  }

  // ──────────────────────────────────────────────
  // Listener do Firebase Auth
  // ──────────────────────────────────────────────

  void _onAuthStateChanged(fb.User? user) {
    if (user == null) {
      _currentSessionSignal.value = null;
    }
  }

  Failure _mapAuthFailure(Object error) {
    if (error is Failure) return error;

    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return DefaultFailure('authGoogleCanceled');
      }
      return DefaultFailure('authUnexpectedError');
    }

    if (error is fb.FirebaseAuthException) {
      return switch (error.code) {
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

  Future<void> _initializeGoogleSignIn() {
    return _googleInitialization ??= _googleSignIn.initialize();
  }

  Future<void> _rollbackCreatedUser(fb.User user) async {
    try {
      await user.delete();
    } catch (_) {
      try {
        await _firebaseAuth.signOut();
      } catch (_) {
        // Best effort: the next auth-state event remains the authority.
      }
    } finally {
      _currentSessionSignal.value = null;
    }
  }

  Future<void> _clearFailedAuthentication() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // The operation already failed; session cleanup is best-effort.
    } finally {
      _currentSessionSignal.value = null;
    }
  }

  // ──────────────────────────────────────────────
  // Interface pública
  // ──────────────────────────────────────────────

  @override
  Signal<AuthSession?> get currentSessionSignal => _currentSessionSignal;

  @override
  AuthSession? get currentSession => _currentSessionSignal.value;

  @override
  Future<void> initSession() {
    final currentInitialization = _sessionInitialization;
    if (currentInitialization != null) return currentInitialization;

    final initialization = _restoreSession();
    _sessionInitialization = initialization;
    return initialization.whenComplete(() {
      if (identical(_sessionInitialization, initialization)) {
        _sessionInitialization = null;
      }
    });
  }

  Future<void> _restoreSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      _currentSessionSignal.value = null;
      return;
    }

    try {
      final session = await _buildSession(user, refreshToken: true);
      if (_firebaseAuth.currentUser?.uid != user.uid) return;
      _setSession(session);
    } catch (_) {
      _currentSessionSignal.value = null;
    }
  }

  @override
  Future<AuthSessionResult> signIn(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) return Error(NotFoundFailure('authUserNotFound'));

      final session = await _buildSession(user);
      _setSession(session);
      return Success(session);
    } catch (error) {
      await _clearFailedAuthentication();
      return Error(_mapAuthFailure(error));
    }
  }

  @override
  Future<AuthSessionResult> signInWithGoogle() async {
    try {
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
        return Error(DefaultFailure('authUnexpectedError'));
      }

      final session = await _buildSession(user);
      _setSession(session);
      return Success(session);
    } catch (error) {
      await _clearFailedAuthentication();
      return Error(_mapAuthFailure(error));
    }
  }

  @override
  Future<AuthSessionResult> signUp({
    required AccountName name,
    required String email,
    required String password,
  }) async {
    fb.User? createdUser;

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) return Error(DefaultFailure('authUnexpectedError'));
      createdUser = user;

      await user.updateDisplayName(name.displayName);
      await user.reload();

      final session = await _buildSession(
        _firebaseAuth.currentUser ?? user,
      );
      _setSession(session);
      return Success(session);
    } catch (error) {
      if (createdUser != null) {
        await _rollbackCreatedUser(createdUser);
      }
      return Error(_mapAuthFailure(error));
    }
  }

  @override
  Future<VoidResult> signOut() async {
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
      _currentSessionSignal.value = null;
      return const Success(null);
    } catch (error) {
      return Error(_mapAuthFailure(error));
    }
  }
}
