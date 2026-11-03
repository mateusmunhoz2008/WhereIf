import 'package:autth_injustice_app/account/domain/models/account_name.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/i_auth_service.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Safe placeholder used while the authentication backend is not connected.
///
/// It never creates sessions or persists credentials. Replace this DI binding
/// with the production adapter when its complete flow is ready.
class UnconfiguredAuthService implements IAuthService {
  final Signal<AuthSession?> _session = signal(null);

  @override
  Signal<AuthSession?> get currentSessionSignal => _session;

  @override
  AuthSession? get currentSession => _session.value;

  @override
  Future<void> initSession() async {
    _session.value = null;
  }

  @override
  Future<AuthSessionResult> signIn(String email, String password) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }

  @override
  Future<AuthSessionResult> signInWithGoogle() async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }

  @override
  Future<AuthSessionResult> signUp({
    required AccountName name,
    required String email,
    required String password,
  }) async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }

  @override
  Future<VoidResult> signOut() async {
    _session.value = null;
    return const Success(null);
  }

  @override
  Future<VoidResult> reauthenticateWithGoogle() async {
    return Error(RemoteFailure('authBackendUnavailable'));
  }
}
