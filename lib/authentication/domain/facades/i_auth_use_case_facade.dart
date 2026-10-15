import 'package:autth_injustice_app/core/typedefs/types_defs.dart';

abstract interface class IAuthUseCaseFacade {
  Future<AuthSessionResult> signInUseCase(SignInParams params);
  Future<AuthSessionResult> signInWithGoogleUseCase(NoParams params);
  Future<VoidResult> signOutUseCase(NoParams params);
  Future<AuthSessionResult> signUpUseCase(SignUpParams params);
}
