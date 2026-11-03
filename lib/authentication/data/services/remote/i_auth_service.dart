import 'package:autth_injustice_app/account/domain/models/account_name.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';
import 'package:signals_flutter/signals_flutter.dart';

abstract interface class IAuthService {
  /// Reactive authenticated session, or null after sign-out.
  Signal<AuthSession?> get currentSessionSignal;

  AuthSession? get currentSession;

  /// Restores the session already maintained by Firebase Auth.
  Future<void> initSession();

  Future<AuthSessionResult> signIn(String email, String password);

  Future<AuthSessionResult> signInWithGoogle();

  Future<AuthSessionResult> signUp({
    required AccountName name,
    required String email,
    required String password,
  });

  Future<VoidResult> signOut();

  Future<VoidResult> reauthenticateWithGoogle();
}
