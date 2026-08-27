import 'package:autth_injustice_app/account/domain/models/account_name.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/i_auth_service.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Implementação concreta do repositório de autenticação.
/// Delega tudo ao [IAuthService] e expõe o Signal reativo de sessão.
class AuthRepositoryImpl implements IAuthRepository {
  final IAuthService _authService;

  AuthRepositoryImpl(this._authService);

  @override
  Future<void> initSession() => _authService.initSession();

  @override
  AuthSession? get currentSession => _authService.currentSession;

  @override
  Signal<AuthSession?> get sessionSignal => _authService.currentSessionSignal;

  @override
  Future<AuthSessionResult> signIn(String email, String password) =>
      _authService.signIn(email, password);

  @override
  Future<AuthSessionResult> signInWithGoogle() =>
      _authService.signInWithGoogle();

  @override
  Future<AuthSessionResult> signUp({
    required AccountName name,
    required String email,
    required String password,
  }) =>
      _authService.signUp(name: name, email: email, password: password);

  @override
  Future<VoidResult> signOut() => _authService.signOut();
}
