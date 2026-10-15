import 'dart:async';

import 'package:autth_injustice_app/authentication/domain/facades/i_auth_use_case_facade.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/login/login_state_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/login/login_viewmodel.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('old error expiry cannot clear a newer error', (tester) async {
    final state = LoginState();
    final first = state.showTemporaryError('first');
    await tester.pump(const Duration(seconds: 1));
    state.clearError();
    final second = state.showTemporaryError('second');
    await tester.pump(const Duration(seconds: 2));
    await first;
    expect(state.errorMessage.value, 'second');
    await tester.pump(const Duration(seconds: 1));
    await second;
    expect(state.errorMessage.value, isNull);
  });

  test('repeated email and Google submissions issue only one request',
      () async {
    final facade = _DeferredFacade();
    final model = LoginViewModel(facade);
    final first = model.commands.signIn(email: 'a@b.com', password: 'password');
    expect(await model.commands.signIn(email: 'a@b.com', password: 'password'),
        isFalse);
    expect(await model.commands.signInWithGoogle(), isFalse);
    expect(facade.requests.length, 1);
    facade.requests.single
        .complete(Error(InvalidInputFailure('invalidFields')));
    expect(await first, isFalse);
    expect(model.state.loading.value, isFalse);
  });

  test('cancelled response cannot overwrite the next session loading or errors',
      () async {
    final facade = _DeferredFacade();
    final model = LoginViewModel(facade);
    final old = model.commands.signIn(email: 'a@b.com', password: 'password');
    model.commands.cancel();
    expect(model.state.loading.value, isFalse);
    expect(model.state.errorMessage.value, isNull);
    final current = model.commands.signInWithGoogle();
    facade.requests.first.complete(Error(InvalidInputFailure('old')));
    expect(await old, isFalse);
    expect(model.state.loading.value, isTrue);
    expect(model.state.errorMessage.value, isNull);
    facade.requests.last.complete(Error(InvalidInputFailure('current')));
    expect(await current, isFalse);
    expect(model.state.errorMessage.value, 'current');
    model.commands.cancel();
    expect(model.state.errorMessage.value, isNull);
  });
}

class _DeferredFacade extends Fake implements IAuthUseCaseFacade {
  final requests = <Completer<AuthSessionResult>>[];

  Future<AuthSessionResult> _request() {
    final request = Completer<AuthSessionResult>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<AuthSessionResult> signInUseCase(SignInParams params) => _request();

  @override
  Future<AuthSessionResult> signInWithGoogleUseCase(NoParams params) =>
      _request();
}
