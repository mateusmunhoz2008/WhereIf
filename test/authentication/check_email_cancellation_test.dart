import 'dart:async';

import 'package:autth_injustice_app/authentication/domain/email_verification_types.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_email_verification_facade.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/check_email/check_email_commands_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/check_email/check_email_state_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/register/register_state_viewmodel.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _Facade extends Fake implements IEmailVerificationFacade {
  final status = Completer<EmailVerificationStatusResult>();
  final resendResult = Completer<EmailVerificationActionResult>();

  @override
  Future<EmailVerificationStatusResult> getStatus(
          EmailVerificationParams params) =>
      status.future;

  @override
  Future<EmailVerificationActionResult> resend(
          EmailVerificationParams params) =>
      resendResult.future;
}

void main() {
  test('cancelled confirmation polling does not surface a late exception',
      () async {
    final facade = _Facade();
    final state = CheckEmailState();
    final commands =
        CheckEmailCommands(state: state, emailVerificationFacade: facade);
    final pending = commands.waitForConfirmation(
      email: 'student@example.com',
      flow: EmailVerificationFlow.register,
    );
    commands.cancelMonitoring();
    facade.status.completeError(StateError('Transport closed'));
    await pending;
    expect(state.loading.value, isFalse);
    expect(state.errorMessage.value, isNull);
    expect(state.confirmed.value, isFalse);
  });

  test('cancelled resend does not update a subsequent screen', () async {
    final facade = _Facade();
    final state = CheckEmailState();
    final commands =
        CheckEmailCommands(state: state, emailVerificationFacade: facade);
    final pending = commands.resend(
      email: 'student@example.com',
      flow: EmailVerificationFlow.register,
    );
    commands.cancelMonitoring();
    facade.resendResult.complete(const Success(null));
    expect(await pending, isFalse);
    expect(state.resending.value, isFalse);
    expect(state.errorMessage.value, isNull);
  });

  testWidgets('old registration error timer cannot dismiss a newer error',
      (tester) async {
    final state = RegisterState();
    final pending = state.showTemporaryError('first');
    state.showError('second');
    await tester.pump(const Duration(seconds: 3));
    await pending;
    expect(state.errorMessage.value, 'second');
  });
}
